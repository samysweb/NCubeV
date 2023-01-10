import Base.iterate

# function get_skeleton(formula :: Formula)
# 	@debug "Generating boolean skeleton for OLNNV"
# 	skeleton = BooleanSkeleton(formula)
# 	return skeleton
# end

function get_atoms(skeleton :: BooleanSkeleton, solution :: Vector{Int64})
	return @timeit Config.TIMER "atom_recovery" begin
		atoms = Tuple{Int64,Union{LinearConstraint, Atom, ApproxNode, CompositeFormula}}[]
		num_vars = skeleton.query.num_input_vars+skeleton.query.num_output_vars
		variable_mapping_keys = keys(skeleton.variable_mapping)
		@timeit Config.TIMER "bound_computation" begin
			bounds = Vector{Tuple{Int64,Tuple{Float64,Float64}}}(undef,num_vars)
			for s in solution
				if !in(abs(s), variable_mapping_keys) || s < 0
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
		end

		@timeit Config.TIMER "atom_computation" begin
			num_vars = length(skeleton.variable_mapping)
			for s in solution
				if !in(abs(s), variable_mapping_keys)
					continue
				end
				polarity = s > 0
				if abs(s)>num_vars
					continue
				end
				var_type = skeleton.variable_mapping[abs(s)]
				@match var_type begin
					ConstraintVariable(c) => begin
						atom = c
						if atom isa LinearConstraint && !polarity
							atom = AST.negate(atom)
						elseif atom isa Atom && !polarity
							atom = CompositeFormula(AST.Not,Atom[atom])
						end
						push!(atoms, (s,atom))
					end
					_ => begin end
				end
			end
		end
		return bounds, atoms
	end
end

function split_by_linearity(atoms :: Vector{Tuple{Int64,Union{LinearConstraint,Atom,ApproxNode,CompositeFormula}}})
	linear_atoms = Tuple{Int64,LinearConstraint}[]
	nonlinear_atoms = Tuple{Int64,Union{Atom,CompositeFormula}}[]
	approx_atoms = Tuple{Int64, ApproxNode}[]
	for (s,a) in atoms
		if isa(a,LinearConstraint)
			push!(linear_atoms, (s,a))
		elseif a isa Atom || a isa CompositeFormula
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

function iterate(iterquery :: IterableQuery)
	state = BooleanSkeleton(iterquery.query, iterquery.smt_state)
	return iterate(iterquery, state)
end

function generate_linear_constraint(bounds :: Vector{Tuple{Float64, Float64}}, semi :: SemiLinearConstraint, approximations :: Dict{ApproxQuery,Approximation})
	coefficients = Vector{Rational{BigInt}}(undef, length(bounds))
	bias = zero(Rational{BigInt})
	coefficients .= semi.coefficients
	bias = semi.bias
	for (query, coeff) in semi.semilinears
		linear_term = get_linear_term(bounds, approximations[query])
		coefficients .+= coeff .* linear_term.coefficients
		bias -= coeff * linear_term.bias
	end
	return LinearConstraint(coefficients, bias, semi.equality)
end

function iterate(iterquery :: IterableQuery, state :: BooleanSkeleton)
	query = iterquery.query
	ctx, variables = iterquery.smt_state
	return @timeit Config.TIMER "next_query" begin
		if isnothing(state)
			state = BooleanSkeleton(query, iterquery.smt_state)
		end
		infeasibility_cache = []
		solution = solve(state.sat_instance)
		input = nothing
		disjunction = Vector{Vector{Formula}}()
		disjunction_nonlinear = Vector{Formula}()
		nonlinearities_set = Set{ApproxQuery}()
		num_vars = query.num_input_vars+query.num_output_vars
		
		#@assert (SMTInterface.nl_feasible(Formula[query.formula], ctx, variables))
		push(state.sat_instance)
		while solution != :unsatisfiable
			bounds, conjunction = get_atoms(state, solution)
			@timeit Config.TIMER "bound_atoms" begin
				bound_atoms = Vector{Tuple{Int64,LinearConstraint}}()
				for (dim,(s,(l,u))) in enumerate(bounds)
					coeffsl = zeros(num_vars)
					coeffsl[dim] = -1.0
					coeffsu = zeros(num_vars)
					coeffsu[dim] = 1.0
					push!(bound_atoms,(s,LinearConstraint(coeffsl, -l, true)))
					push!(bound_atoms,(0,LinearConstraint(coeffsu, u, true)))
				end
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
			@timeit Config.TIMER "check_infeasibility" begin
				if @timeit Config.TIMER "linear" !SMTInterface.nl_feasible(linear,state.smt_feasibility)
					# Linear part of conjunction infeasible => skip
					infeasible_combination = map(x -> -x[1], linear)
					#print_msg("Linear part of conjunction infeasible: ", infeasible_combination)
				elseif @timeit Config.TIMER "linear_bound" !SMTInterface.nl_feasible(chain(bound_atoms,linear),state.smt_feasibility)
					# Linear part of conjunction infeasible => skip
					infeasible_combination = map(x -> -x[1], [bound_atoms;linear])
					#print_msg("Linear part of conjunction infeasible: ", infeasible_combination)
				elseif @timeit Config.TIMER "nonlinear" !SMTInterface.nl_feasible(nonlinear,state.smt_feasibility)
					# Nonlinear part of conjunction infeasible => skip
					infeasible_combination = map(x -> -x[1], nonlinear)
					#print_msg("Nonlinear part of conjunction infeasible: ", infeasible_combination)
				elseif @timeit Config.TIMER "nonlinear_bound" !SMTInterface.nl_feasible(chain(bound_atoms,nonlinear),state.smt_feasibility)
					# Nonlinear part of conjunction infeasible => skip
					infeasible_combination = map(x -> -x[1], [bound_atoms;nonlinear])
					#print_msg("Nonlinear part of conjunction infeasible: ", infeasible_combination)
				elseif @timeit Config.TIMER "all" !SMTInterface.nl_feasible(chain(bound_atoms,linear,nonlinear),state.smt_feasibility)
					infeasible_combination = map(x -> -x[1], [bound_atoms;linear;nonlinear])
				end
			end
			if isnothing(infeasible_combination)
				approx_resolved = Vector{Tuple{Int64,LinearConstraint}}()
				output_conjunction = nothing
				@timeit Config.TIMER "approx_resolution" begin
					approx_bounds = map(x->x[2],bounds)
					for (s,c) in approx_atoms
						atom = nothing
						if c isa UnderApprox
							atom = generate_linear_constraint(approx_bounds, c.under_approx, query.approximations)
						elseif c isa OverApprox
							atom = generate_linear_constraint(approx_bounds, c.over_approx, query.approximations)
						else
							@assert false "Neither under nor overapproximation"
						end
						if s < 0
							atom = AST.negate(atom)
						end
						push!(approx_resolved,(s,atom))
					end
					output_conjunction = [bound_atoms;linear;approx_resolved]
				end
				@timeit Config.TIMER "check_infeasibility_prep" begin
					output_conjunction_smt = convert(Vector{Tuple{Int64, Formula}},map(x->(0,x[2]),approx_resolved))
				end
				@timeit Config.TIMER "check_infeasibility" begin
					if @timeit Config.TIMER "approx" !SMTInterface.nl_feasible(chain(bound_atoms, linear, output_conjunction_smt),state.smt_feasibility)
						# Linear + Approximate part of conjunction infeasible => skip
						infeasible_combination = map(x -> -x[1], output_conjunction)
						#print_msg("Approx of conjunction infeasible: ", infeasible_combination)
					elseif @timeit Config.TIMER "approx_nonlinear" !SMTInterface.nl_feasible(chain(bound_atoms, linear, output_conjunction_smt,nonlinear),state.smt_feasibility)
						infeasible_combination = map(x -> -x[1], [output_conjunction;nonlinear])
					end
				end
			end
			if !isnothing(infeasible_combination)
				#sort!(infeasible_combination)
				#infeasible_combination = unique!(x->x,infeasible_combination)
				#print("_")
				infeasible_combination = filter(x->x!=0,infeasible_combination)
				push!(infeasibility_cache, infeasible_combination)
				add_clause(
					state.sat_instance,
					infeasible_combination
				)
				solution = solve(state.sat_instance)
				#print_msg(solution)
				continue
			end
			@timeit Config.TIMER "query_construction" begin
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
				# TODO(steuber): If we properly "cut out" the star sets when finding them (i.e. add all the linear constraints),
				# we can omit the linear part of the conjunction here - useful?
				nonlinear_conjunction = [bound_atoms;linear;nonlinear]
				#print_msg("[QUERY] Nonlinear variant of conjunction: ", nonlinear_conjunction)
				#input_nonlinear, mixed_nonlinear = split_by_variables(convert(Vector{Tuple{Int64,ParsedNode}},nonlinear_conjunction),query)
			
				push!(disjunction_nonlinear, AST.and_construction(map(x -> x[2], nonlinear_conjunction)))
				#[
				#	map(x -> x[2], input_nonlinear);
				#	not(AST.and_construction(map(x -> x[2], mixed_nonlinear)))
				#]))

				# Fix input constraints for further search
				for (v,_) in input
					if v == 0
						continue
					end
					add_clause(state.sat_instance, v)
				end
				# Disallow current mixed constraint for further search
				add_clause(state.sat_instance, map(x -> -x[1], filter(x->x[1]!=0,mixed)))
			end
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
					map(x -> -x[1], filter(x->x[1]!=0,input))
				)
			#print_msg("Input: ", map(x -> AST.term_to_string(x[2]), input))
			#print_msg("Disjunction: ", disjunction)
			#print_msg("#Mixed: ", length(disjunction))
			# print_msg("#Nonlinear",length(nonlinearities_set))
			# print_msg("---------------------")
			# for x in nonlinearities_set
			# 	print_msg(x.bound," -> ",AST.term_to_string(x.term))
			# end
			# print_msg("---------------------")
			#@debug "Input:", map(x->x[2],input)
			#@debug "Disjunction: ", disjunction
			nonlinear_fml = AST.or_construction(disjunction_nonlinear)
			#print_msg("[QUERY] Nonlinear variant of conjunction: ", nonlinear_fml)
			return (nonlinear_fml,NormalizedQuery(map(x->x[2],input), disjunction, nonlinearities_set, query)), state
		else
			return nothing
		end
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

