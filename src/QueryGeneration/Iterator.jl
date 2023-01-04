import Base.iterate

# function get_skeleton(formula :: Formula)
# 	@debug "Generating boolean skeleton for OLNNV"
# 	skeleton = BooleanSkeleton(formula)
# 	return skeleton
# end

function get_atoms(skeleton :: BooleanSkeleton, solution :: Vector{Int64})
	atoms = Tuple{Int64,Union{LinearConstraint, Atom, ApproxNode}}[]
	num_vars = skeleton.query.num_input_vars+skeleton.query.num_output_vars
	bounds = Vector{Tuple{Int64,Tuple{Float64,Float64}}}(undef,num_vars)
	for s in solution
		if !in(abs(s), keys(skeleton.variable_mapping)) || s < 0
			continue
		end
		var_type = skeleton.variable_mapping[abs(s)]
		@match var_type begin
			ApproxCase(dim,i) => begin
				l, u = skeleton.query.bounds[dim][i], skeleton.query.bounds[dim][i+1]
				bounds[dim] = (s,(l,u))
			end
			_ => begin end
		end
	end

	for s in solution
		if !in(abs(s), keys(skeleton.variable_mapping))
			continue
		end
		polarity = s > 0
		if abs(s)>length(skeleton.variable_mapping)
			continue
		end
		var_type = skeleton.variable_mapping[abs(s)]
		@match var_type begin
			ConstraintVariable(c) => begin
				atom = c
				# if c isa ApproxNode
				# 	term = c.formula.left
				# 	bound_type = (c isa UnderApprox) ? AST.Upper : AST.Lower
				# 	approx = skeleton.query.approximations[ApproxQuery(bound_type, term)]
				# 	i = get_linear_term_position(approx, bounds)
				# 	term = approx.linear_constraints[i]
				# 	atom = LinearConstraint(term.coefficients, -term.bias, c.formula.comparator==AST.LessEq)
				# 	#push!(atoms, (s,c))
				# #elseif c isa Atom
				# #	# TODO(steuber): Use information on relation of under/over-approximation and atom?
				# #	continue
				# end
				if !(atom isa ApproxNode) && !polarity
					atom = AST.negate(atom)
				end
				push!(atoms, (s,atom))
			end
			_ => begin end
		end
	end
	return bounds, atoms
end

function split_by_linearity(atoms :: Vector{Tuple{Int64,Union{LinearConstraint,Atom,ApproxNode}}})
	linear_atoms = Tuple{Int64,LinearConstraint}[]
	nonlinear_atoms = Tuple{Int64,Atom}[]
	approx_atoms = Tuple{Int64, ApproxNode}[]
	for (s,a) in atoms
		if isa(a,LinearConstraint)
			push!(linear_atoms, (s,a))
		elseif a isa Atom
			push!(nonlinear_atoms, (s,a))
		elseif a isa ApproxNode
			push!(approx_atoms, (s,a))
		end
	end
	return linear_atoms, nonlinear_atoms, approx_atoms
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

function split_by_variables(atoms :: Vector{Tuple{Int64,ParsedNode}}, query :: Query)
	input_atoms = Tuple{Int64,ParsedNode}[]
	mixed_atoms = Tuple{Int64,ParsedNode}[]
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
	state = BooleanSkeleton(query)
	return iterate(query, state)
end

function iterate(query :: Query, state :: BooleanSkeleton)
	if isnothing(state)
		state = BooleanSkeleton(query)
	end
	
	infeasibility_cache = []
	solution = solve(state.sat_instance)
	input = nothing
	fixed_input = nothing
	disjunction = Vector{Vector{Formula}}()
	nonlinearities_set = Set{ApproxQuery}()
	num_vars = query.num_input_vars+query.num_output_vars
	smt_context(query.num_input_vars+query.num_output_vars;timeout=100000) do (ctx, variables)
		@assert (SMTInterface.nl_feasible(Formula[query.formula], ctx, variables))
		push(state.sat_instance)
		while solution != :unsatisfiable
			bounds, conjunction = get_atoms(state, solution)
			bound_atoms = Vector{Tuple{Int64,LinearConstraint}}()
			for (dim,(s,(l,u))) in enumerate(bounds)
			 	coeffsl = zeros(num_vars)
			 	coeffsl[dim] = -1.0
			 	coeffsu = zeros(num_vars)
			 	coeffsu[dim] = 1.0
			 	push!(bound_atoms,(s,LinearConstraint(coeffsl, -l, true)))
			 	push!(bound_atoms,(s,LinearConstraint(coeffsu, u, true)))
			end
			linear, nonlinear, approx_atoms = split_by_linearity(conjunction)
			# Complete Conjunction:
			# linear AND nonlinear AND (OR_bounds approx_atoms)
			#@assert length(nonlinear) == 0
			infeasible_combination = nothing
			#if LP.is_infeasible(map(x->x[2],linear))
			#	infeasible_combination = map(x -> -x[1], linear)
			#end
			# Flag combination of linear constraints as infeasible and continue...
			#	infeasible_combination = map(x -> -x[1], linear)
			# TODO(steuber): How many checks here are the optimal choice?
			if !SMTInterface.nl_feasible(convert(Vector{Formula},map(x->x[2],linear)),ctx, variables)
				# Linear part of conjunction infeasible => skip
				infeasible_combination = map(x -> -x[1], linear)
				#print_msg("Linear part of conjunction infeasible: ", infeasible_combination)
			elseif !SMTInterface.nl_feasible(convert(Vector{Formula},map(x->x[2],nonlinear)),ctx, variables)
				# Nonlinear part of conjunction infeasible => skip
				infeasible_combination = map(x -> -x[1], nonlinear)
				#print_msg("Nonlinear part of conjunction infeasible: ", infeasible_combination)
			end
			if isnothing(infeasible_combination)
				approx_resolved = Vector{Tuple{Int64,LinearConstraint}}()
				for (s,c) in approx_atoms
					term = c.formula.left
					bound_type = (c isa UnderApprox) ? AST.Upper : AST.Lower
					approx = query.approximations[ApproxQuery(bound_type, term)]
					i = get_linear_term_position(approx, map(x->x[2],bounds))
					term = approx.linear_constraints[i]
					atom = LinearConstraint(term.coefficients, -term.bias, c.formula.comparator==AST.LessEq)
					if s < 0
						atom = AST.negate(atom)
					end
					push!(approx_resolved,(s,atom))
				end
				output_conjunction = [bound_atoms;linear;approx_resolved]
				if !SMTInterface.nl_feasible(convert(Vector{Formula},map(x->x[2],output_conjunction)),ctx, variables)
					# Linear + Approximate part of conjunction infeasible => skip
					infeasible_combination = map(x -> -x[1], output_conjunction)
					#print_msg("Approx of conjunction infeasible: ", infeasible_combination)
				end
			end
			if !isnothing(infeasible_combination)
				sort!(infeasible_combination)
				infeasible_combination = unique!(x->x,infeasible_combination)
				#print("_")
				push!(infeasibility_cache, infeasible_combination)
				add_clause(
					state.sat_instance,
					infeasible_combination
				)
				solution = solve(state.sat_instance)
				#print_msg(solution)
				continue
			end
			# OK, our combination is feasible...
			input, mixed = split_by_variables(convert(Vector{Tuple{Int64,ParsedNode}},output_conjunction),query)
			# Store non-linearities of current combination in set
			# for a in nonlinear
			# 	@assert a[2].formula.right isa TermNumber
			# 	approx_direction = (a[2] isa OverApprox) ? Lower : Upper
			# 	nonlinearities_set=union(nonlinearities_set, collect_nonlinearities(approx_direction, a[2].formula.left))
			# end
			# Add in-out constraints to disjunction
			#@debug "Adding in-out constraints: ", mixed
			push!(disjunction, map(x -> x[2], mixed))

			#fixed_input, _ = split_by_variables(convert(Vector{Tuple{Int64,ParsedNode}},[bound_atoms;conjunction]),query)
		
			# Fix input constraints for further search
			for (v,_) in input
				add_clause(state.sat_instance, v)
			end
			# Disallow current mixed constraint for further search
			add_clause(state.sat_instance, map(x -> -x[1], mixed))
			# Find new model
			solution = solve(state.sat_instance)
		end
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
		print_msg("Input: ", map(x -> AST.term_to_string(x[2]), input))
		print_msg("Disjunction: ", disjunction)
		#print_msg("#Mixed: ", length(disjunction))
		# print_msg("#Nonlinear",length(nonlinearities_set))
		# print_msg("---------------------")
		# for x in nonlinearities_set
		# 	print_msg(x.bound," -> ",AST.term_to_string(x.term))
		# end
		# print_msg("---------------------")
		@debug "Input:", map(x->x[2],input)
		@debug "Disjunction: ", disjunction
		return NormalizedQuery(map(x->x[2],input), disjunction, nonlinearities_set, query), state
	else
		return nothing
	end
end

# 		add_clause(skeleton.sat_instance, map(x->-x, solution))
# 		solution = solve(skeleton.sat_instance)
# 		print_msg("--------------------------------------------------------------")
# 	end
# 	print_msg("Found ", i, " solutions")
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

