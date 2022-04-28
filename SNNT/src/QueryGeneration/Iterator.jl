import Base.iterate

# function get_skeleton(formula :: Formula)
# 	@debug "Generating boolean skeleton for OLNNV"
# 	skeleton = BooleanSkeleton(formula)
# 	return skeleton
# end

function get_atoms(skeleton :: BooleanSkeleton, solution :: Vector{Int64})
	atoms = Tuple{Int64,Union{ApproxNode,LinearConstraint}}[]
	for s in solution
		polarity = s > 0
		if abs(s)>length(skeleton.variable_mapping)
			continue
		end
		var_type = skeleton.variable_mapping[abs(s)]
		@match var_type begin
			ConstraintVariable(c) => begin
				if !polarity
					c = AST.negate(c)
				end
				push!(atoms, (s,c))
			end
			IntermediateVariable => begin end
		end
	end
	return atoms
end

function split_by_linearity(atoms :: Vector{Tuple{Int64,Union{ApproxNode,LinearConstraint}}})
	linear_atoms = Tuple{Int64,LinearConstraint}[]
	nonlinear_atoms = Tuple{Int64,ApproxNode}[]
	for (s,a) in atoms
		if isa(a,LinearConstraint)
			push!(linear_atoms, (s,a))
		else
			push!(nonlinear_atoms, (s,a))
		end
	end
	return linear_atoms, nonlinear_atoms
end

function has_output_variables(f :: ParsedNode, query :: Query)
	if f isa Variable
		return f.mapping[1] == AST.Output
	elseif f isa LinearConstraint
		return !iszero(f.coefficients[query.num_input_vars+1:end])
	elseif f isa SemiLinearConstraint
		if !iszero(f.coefficients[query.num_input_vars+1:end])
			return true
		end
		for (k,_) in f.semilinears
			if has_output_variables(k.term, query)
				return true
			end
		end
		return false
	elseif istree(f)
		return any(map(x -> has_output_variables(x,query), arguments(f)))
	else
		return false
	end
end

function split_by_variables(atoms :: Vector{Tuple{Int64,Union{SemiLinearConstraint,LinearConstraint}}}, query :: Query)
	input_atoms = Tuple{Int64,Union{SemiLinearConstraint,LinearConstraint}}[]
	mixed_atoms = Tuple{Int64,Union{SemiLinearConstraint,LinearConstraint}}[]
	for (s,a) in atoms
		if has_output_variables(a, query)
			push!(mixed_atoms, (s,a))
		else
			push!(input_atoms, (s,a))
		end
	end
	return input_atoms, mixed_atoms
end

function iterate(query :: Query)
	state = BooleanSkeleton(query.formula)
	return iterate(query, state)
end

function iterate(query :: Query, state :: BooleanSkeleton)
	if isnothing(state)
		state = BooleanSkeleton(query.formula)
	end
	# TODO(steuber): Refactor z3 context creation (maybe same for LP)
	ctx, variables = z3_context(query.num_input_vars+query.num_output_vars)
	@assert (Z3Interface.nl_feasible(Formula[query.formula], ctx, variables))
	solution = solve(state.sat_instance)
	input = nothing
	disjunction = Vector{Vector{Formula}}()
	infeasibility_cache = []
	nonlinearities_set = Set{ApproxQuery}()
	push(state.sat_instance)
	while solution != :unsatisfiable
		conjunction = get_atoms(state, solution)
		linear, nonlinear = split_by_linearity(conjunction)
		infeasible_combination = nothing
		#if !LP.is_feasible(map(x->x[2],linear))
		# Flag combination of linear constraints as infeasible and continue...
		#	infeasible_combination = map(x -> -x[1], linear)
		# TODO(steuber): How many checks here are the optimal choice?
		if !Z3Interface.nl_feasible(convert(Vector{Formula},map(x->x[2],linear)),ctx, variables)
			#println("Z3 says it's infeasible")
			infeasible_combination = map(x -> -x[1], linear)
		elseif !Z3Interface.nl_feasible(convert(Vector{Formula},map(x->x[2],nonlinear)),ctx, variables)
			#println("Z3 says it's infeasible")
			infeasible_combination = map(x -> -x[1], nonlinear)
		elseif !Z3Interface.nl_feasible(convert(Vector{Formula},map(x->x[2],conjunction)),ctx, variables)
			#println("Z3 says it's infeasible")
			infeasible_combination = map(x -> -x[1], conjunction)
		end
		if !isnothing(infeasible_combination)
			#print("_")
			push!(infeasibility_cache, infeasible_combination)
			add_clause(
				state.sat_instance,
				infeasible_combination
			)
			solution = solve(state.sat_instance)
			continue
		end
		new_conjunction = Tuple{Int64,Union{SemiLinearConstraint,LinearConstraint}}[]
		# Resolve nonlinearities to semi-linear constraints
		varnum = query.num_input_vars+query.num_output_vars
		for cur_f  in conjunction
			if cur_f[2] isa ApproxNode
				@assert cur_f[2].formula.right isa TermNumber
				approx_direction = (cur_f[2] isa OverApprox) ? Lower : Upper
				approx_queries, semilinear = handle_nonlinearity(approx_direction, cur_f[2].formula.left)
				nonlinearities_set = union(nonlinearities_set, approx_queries)
				new_formula = make_linear(semilinear, cur_f[2].formula.right, cur_f[2].formula.comparator, varnum)
				#@debug "New semilinear constraint: ", new_formula
				push!(new_conjunction, (cur_f[1], new_formula ))
			else
				push!(new_conjunction, cur_f)
			end
		end
		#print("|")
		# OK, our combination is feasible...
		input, mixed = split_by_variables(new_conjunction,query)
		# Store non-linearities of current combination in set
		# for a in nonlinear
		# 	@assert a[2].formula.right isa TermNumber
		# 	approx_direction = (a[2] isa OverApprox) ? Lower : Upper
		# 	nonlinearities_set=union(nonlinearities_set, collect_nonlinearities(approx_direction, a[2].formula.left))
		# end
		# Add in-out constraints to disjunction
		@debug "Adding in-out constraints: ", mixed
		push!(disjunction, map(x -> x[2], mixed))
	
		# Fix input constraints for further search
		add_clause(state.sat_instance, map(x -> x[1], input))
		# Disallow current mixed constraint for further search
		add_clause(state.sat_instance, map(x -> -x[1], mixed))
		# Find new model
		solution = solve(state.sat_instance)
	end
	pop(state.sat_instance)
	# Dump infeasibility_cache into clause database
	add_clauses(state.sat_instance, infeasibility_cache)
	if !isnothing(input)
		# Disallow input
		add_clause(
				state.sat_instance,
				map(x -> -x[1], input)
			)
		# println("Input: ", map(x -> AST.term_to_string(x[2]), input))
		# println("#Mixed: ", length(disjunction))
		# println("#Nonlinear",length(nonlinearities_set))
		# println("---------------------")
		# for x in nonlinearities_set
		# 	println(x.bound," -> ",AST.term_to_string(x.term))
		# end
		# println("---------------------")
		@debug "Disjunction: ", disjunction
		return NormalizedQuery(map(x->x[2],input), disjunction, nonlinearities_set, query), state
	else
		return nothing
	end
end

# 		add_clause(skeleton.sat_instance, map(x->-x, solution))
# 		solution = solve(skeleton.sat_instance)
# 		println("--------------------------------------------------------------")
# 	end
# 	println("Found ", i, " solutions")
# end
# for each solution s
#   conjunction = get_atoms(s, skeleton) # tuples of variable number and atom
#   linear, nonlinear = split_by_linearity(atoms) # tuples of variable number and atom
#   if infeasible(linear)
#     add_clause(...,map(x->-x[1], linear))
#     continue
#   input, mixed = split_by_input_output(atoms) # tuples of variable number and atoms
#   push()
#   for v,_ in input
#     add_clause(..., [v])
#   disjunction = [mixed]
#   infeasibility_cache = []
#   for each solution s
#     linear, nonlinear = split_by_linearity(atoms) # tuples of variable number and atom
#     if infeasible(linear)
#       clause = map(x->-x[1], linear)
#       add_clause(...,clause)
#       push!(infeasibility_cache, clause)
#       continue
#     input, mixed = split_by_input_output(atoms) # tuples of variable number and atoms
#     for v,_ in input
#       add_clause(..., [v])
#	  disjunction.append(mixed)
#     add_clause(..., map(x->-x, s))
#   end
#   pop()
#   add_clause(..., map(x->-x[1], input))
#   add_clauses(..., infeasibility_cache)
#   yield (input, disjunction)
# 		-> deduplicate non-linearities?
#		-> put all the non-linear parts into the same term and have OVERT run once and for all maybe?
# end

