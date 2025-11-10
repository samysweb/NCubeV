import Base.iterate

# function get_skeleton(formula :: Formula)
# 	@debug "Generating boolean skeleton for OLNNV"
# 	skeleton = BooleanSkeleton(formula)
# 	return skeleton
# end

"""
	get_atoms(skeleton::BooleanSkeleton, solution::Vector{Int64})

Recover variable bounds, selected atoms, and their polarities from a SAT
solution. Returns `(solution_vars, bounds, atoms)` where `bounds` is indexed by
dimension and `atoms` contains `(lit, atom)` pairs.
"""
function get_atoms(skeleton :: BooleanSkeleton, solution :: Vector{Int64})
	return @timeit Config.TIMER "atom_recovery" begin
		solution_vars = Vector{Int64}()
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
						push!(solution_vars, s)
						atom = c
						if atom isa LinearConstraint && !polarity
							atom = AST.negate(atom)
						elseif atom isa Atom && !polarity
							atom = CompositeFormula(AST.Not,Atom[atom])
						end
						push!(atoms, (s,atom))
					end
					ApproxCase(dim,case_id) => begin
						push!(solution_vars, s)
					end
					IsMaxCase(option_atoms) => begin
						push!(solution_vars, s)
						if s > 0
							for a in option_atoms
								push!(atoms, (s, a))
							end
						end
					end
					_ => begin end
				end
			end
		end
		return solution_vars, bounds, atoms
	end
end

"""
	split_by_linearity(atoms)

Partition atoms into linear constraints, nonlinear formulas, and approximation
nodes.
"""
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

"""
	has_output_variables(node, query) -> Bool

Check whether a node references output variables of the network.
"""
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

"""
	split_by_variables(atoms, query)

Split atoms into input-only and mixed (input/output) sets.
"""
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

"""
	iterate(iterquery::IterableQuery)

Initialize SAT skeleton and feasibility caches and return the first state for
iteration over normalized queries.
"""
function iterate(iterquery :: IterableQuery)
	skeleton = BooleanSkeleton(iterquery.query, iterquery.smt_state, iterquery.use_approx)
	max_var = next_var(skeleton.sat_instance)
	feasibility_cache = MultiFeasibilityCache(convert(Int64,max_var))
	state = (skeleton, feasibility_cache)
	return iterate(iterquery, state)
end

"""
	generate_linear_constraint(bounds, semi, approximations) -> LinearConstraint

Resolve a semi-linear constraint into a purely linear constraint by substituting
the current linear approximations for each `ApproxQuery`.
"""
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

"""
	iterate(iterquery::IterableQuery, state)

Main iteration loop. Produces for each SAT model a normalized query consisting
of input box bounds and a disjunction over mixed constraints, performing staged
feasibility checks (linear, approx, nonlinear) using LP and SMT backends.
"""
function iterate(iterquery :: IterableQuery, state :: Tuple{BooleanSkeleton,MultiFeasibilityCache})
	query = iterquery.query
	ctx, variables = iterquery.smt_state
	return @timeit Config.TIMER "next_query" begin
		skeleton = nothing
		feasibility_cache = nothing
		if isnothing(state)
			skeleton = BooleanSkeleton(query, iterquery.smt_state, iterquery.use_approx)
			max_var = next_var(skeleton.sat_instance)
			feasibility_cache = MultiFeasibilityCache(convert(Int64,max_var))
			state = (skeleton, feasibility_cache)
		else
			skeleton, feasibility_cache = state
		end
		infeasibility_cache = []
		solution = solve(skeleton.sat_instance)
		input = nothing
		input_nonlinear_disjunction = nothing
		disjunction = Vector{CompositeFormula}()
		disjunction_nonlinear = Vector{Tuple{Formula,Formula}}()
		nonlinearities_set = Set{ApproxQuery}()
		num_vars = query.num_input_vars+query.num_output_vars
		input_literals = []
		
		push(skeleton.sat_instance)
		while solution != :unsatisfiable
			solution_vars, bounds, conjunction = get_atoms(skeleton, solution)
			@timeit Config.TIMER "bound_atoms" begin
				bound_atoms = Vector{Tuple{Int64,LinearConstraint}}()
				for (dim,(s,(l,u))) in enumerate(bounds)
					coeffsl = zeros(num_vars)
					coeffsl[dim] = -1.0
					coeffsu = zeros(num_vars)
					coeffsu[dim] = 1.0
					push!(bound_atoms,(s,LinearConstraint(coeffsl, -l, true)))
					push!(bound_atoms,(s,LinearConstraint(coeffsu, u, true)))
				end
			end
			linear, nonlinear, approx_atoms = split_by_linearity(conjunction)
			infeasible_combination = []
			# TODO(steuber): How many checks here are the optimal choice?
			approx_resolved = Vector{Tuple{Int64,LinearConstraint}}()
			output_conjunction = nothing
			@timeit Config.TIMER "approx_resolution" begin
				approx_bounds = map(x->x[2],bounds)
				if skeleton.use_approx
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
				end
				output_conjunction = [bound_atoms;linear;approx_resolved]
			end
			@timeit Config.TIMER "check_infeasibility_prep" begin
				output_conjunction_smt = convert(Vector{LinearConstraint},map(x->x[2],output_conjunction))
			end
			@timeit Config.TIMER "check_infeasibility_prep" begin
				linear_smt = convert(Vector{LinearConstraint},map(x->x[2],linear))
				linear_vars = filter(x->x!=0,map(x->x[1],linear))
				bounds_smt = convert(Vector{LinearConstraint},map(x->x[2],bound_atoms))
				bounds_vars = filter(x->x!=0,map(x->x[1],bound_atoms))
				approx_resolved_smt = convert(Vector{LinearConstraint},map(x->x[2],approx_resolved))
				approx_resolved_vars = filter(x->x!=0,map(x->x[1],approx_resolved))
				nonlinear_smt = convert(Vector{Formula},map(x->x[2],nonlinear))
				nonlinear_vars = filter(x->x!=0,map(x->x[1],nonlinear))
			end
			# Here we do multiple feasibility checks, starting with the cheapest (linear)
			# and progressing to the most expensive (non-linear with approx).
			# Negations of infeasible combinations are added to the SAT instance to prune the search.
			# Nonlinear checks are only performed if nonlinear constraints are present and no linear constraints are infeasible.
			@timeit Config.TIMER "check_infeasibility" begin
			@timeit Config.TIMER "check_infeasibility_linear" begin
				not_yet_feasible = !check_feasible(feasibility_cache.bound_linear, [bounds_vars; linear_vars])
				conflicts = []
				if not_yet_feasible && !SMTInterface.lin_feasible([bounds_smt;linear_smt],ctx, variables, conflicts)
					push!(infeasible_combination, map(x -> -x[1], ([bound_atoms;linear])[conflicts]))
				elseif not_yet_feasible && LP.is_infeasible([bounds_smt;linear_smt])
					push!(infeasible_combination, map(x -> -x[1], [bound_atoms;linear]))
				elseif not_yet_feasible
					add_feasible(feasibility_cache.bound_linear, [bounds_vars; linear_vars])
				end
				not_yet_feasible = !check_feasible(feasibility_cache.approx, [bounds_vars;linear_vars;approx_resolved_vars])
				conflicts = []
				if not_yet_feasible && !SMTInterface.lin_feasible([bounds_smt;approx_resolved_smt],ctx, variables, conflicts)
					push!(infeasible_combination, map(x -> -x[1], filter(x->x[1]!=0,[bound_atoms;([bound_atoms;approx_resolved])[conflicts]])))
				elseif not_yet_feasible && LP.is_infeasible([bounds_smt;approx_resolved_smt])
					push!(infeasible_combination, map(x -> -x[1], [bound_atoms;approx_resolved]))
				elseif not_yet_feasible
					add_feasible(feasibility_cache.approx, [bounds_vars; approx_resolved_vars])
				end
			end
			@timeit Config.TIMER "check_infeasibility_nonlinear" begin
				if length(infeasible_combination) == 0
					not_yet_feasible = !check_feasible(feasibility_cache.no_approx, [bounds_vars; linear_vars; nonlinear_vars])
					conflicts = []
					if length(infeasible_combination)== 0 && not_yet_feasible && !SMTInterface.nl_feasible([bounds_smt;linear_smt;nonlinear_smt], ctx, variables, conflicts)
						push!(infeasible_combination, map(x -> -x[1], ([bound_atoms;linear;nonlinear])[conflicts]))
					elseif not_yet_feasible
						add_feasible(feasibility_cache.no_approx, [bounds_vars; linear_vars; nonlinear_vars])
					end
					not_yet_feasible = !check_feasible(feasibility_cache.all, [bounds_vars; linear_vars; approx_resolved_vars; nonlinear_vars])
					conflicts = []
					if length(infeasible_combination)== 0 && not_yet_feasible && !SMTInterface.nl_feasible([bounds_smt;linear_smt;approx_resolved_smt;nonlinear_smt], ctx, variables, conflicts)
						push!(infeasible_combination, map(x -> -x[1], [bound_atoms;([output_conjunction;nonlinear])[conflicts]]))
					elseif not_yet_feasible
						add_feasible(feasibility_cache.all, [bounds_vars; linear_vars; approx_resolved_vars; nonlinear_vars])
					end
				end
			end
			end
			if length(infeasible_combination)>0
				append!(infeasibility_cache, infeasible_combination)
				for c in infeasible_combination
					add_clause(
						skeleton.sat_instance,
						c
					)
				end
				solution = solve(skeleton.sat_instance)
				#print_msg(solution)
				continue
			end
			@timeit Config.TIMER "query_construction" begin
				# OK, our combination is feasible...
				input, mixed = split_by_variables(convert(Vector{Tuple{Int64,ParsedNode}},output_conjunction),query)
				input_nonlinear, mixed_nonlinear = split_by_variables(convert(Vector{Tuple{Int64,ParsedNode}},nonlinear),query)
				if !skeleton.input_configured
					input_literals = map(x -> x[1], input)
				end
				mixed_smt = AST.and_construction(map(x -> x[2], mixed))
				push!(disjunction, mixed_smt)
				# TODO(steuber): If we properly "cut out" the star sets when finding them (i.e. add all the linear constraints),
				# we can omit the linear part of the conjunction here - useful?

				# Fix input constraints for further search
				for (v,_) in input
					if v == 0
						continue
					end
					add_clause(skeleton.sat_instance, v)
				end
				secondary_infeasibility_cache = []
				if length(mixed_nonlinear) != 0
					nonlinear_options = Formula[
						AST.and_construction(map(x -> x[2], nonlinear))
					]
					push(skeleton.sat_instance)
					for (v,_) in mixed
						if v == 0
							continue
						end
						add_clause(skeleton.sat_instance, v)
					end
					add_clause(skeleton.sat_instance, map(x->-x, nonlinear_vars))
					# Find new model
					t = solve(skeleton.sat_instance)
					while t != :unsatisfiable
						_, _, conjunction = get_atoms(skeleton, t)
						_, nonlinear, _ = split_by_linearity(conjunction)
						nonlinear_smt = convert(Vector{Formula},map(x->x[2],nonlinear))
						nonlinear_vars = filter(x->x!=0,map(x->x[1],nonlinear))
						not_yet_feasible = !check_feasible(feasibility_cache.all, map(x -> x[1], [bounds;conjunction]))
						conflicts = []
						if !SMTInterface.nl_feasible([bounds_smt;linear_smt;approx_resolved_smt;nonlinear_smt], ctx, variables, conflicts)
							c = map(x->-x,[bounds_vars;([bounds_vars;linear_vars;approx_resolved_vars;nonlinear_vars])[conflicts]])
							push!(secondary_infeasibility_cache, c)
							add_clause(
								skeleton.sat_instance,
								c
							)
							t = solve(skeleton.sat_instance)
							print(".")
							continue
						elseif not_yet_feasible
							add_feasible(feasibility_cache.all, [bounds_vars; linear_vars; approx_resolved_vars; nonlinear_vars])
						end
						#print_msg("[QUERY] Found new nonlinear combination")
						# Add nonlinearities to set
						push!(nonlinear_options, AST.and_construction(nonlinear_smt))
						add_clause(skeleton.sat_instance, map(x -> -x, nonlinear_vars))
						t = solve(skeleton.sat_instance)
					end
					print_msg("[QUERY] Found all non-linear combinations. Count: ", length(nonlinear_options))
					pop(skeleton.sat_instance)
				else
					if isnothing(input_nonlinear_disjunction)
						@warn "Generating independent linear disjunctions"
						@warn "Make sure you are not using this option for non-mixed constraints!"
						input_nonlinear_disjunction = Formula[
							AST.and_construction(map(x -> x[2], input_nonlinear))
						]
						push(skeleton.sat_instance)
						add_clause(skeleton.sat_instance, map(x->-x, nonlinear_vars))
						# Find new model
						print_msg("[QUERY] Looking for nonlinear input combinations...")
						t = solve(skeleton.sat_instance)
						while t != :unsatisfiable
							_, _, conjunction = get_atoms(skeleton, t)
							_, nonlinear, _ = split_by_linearity(conjunction)
							_, current_mixed = split_by_variables(convert(Vector{Tuple{Int64,ParsedNode}},nonlinear),query)
							@assert length(current_mixed)==0
							nonlinear_smt = convert(Vector{Formula},map(x->x[2],nonlinear))
							nonlinear_vars = filter(x->x!=0,map(x->x[1],nonlinear))
							not_yet_feasible = !check_feasible(feasibility_cache.all, map(x -> x[1], [bounds;input;nonlinear]))
							conflicts = []
							if !SMTInterface.nl_feasible([bounds_smt;map(x->x[2],input);nonlinear_smt], ctx, variables, conflicts)
								c = map(x->-x,[bounds_vars;([bounds_vars;map(x->x[1],input);nonlinear_vars])[conflicts]])
								push!(secondary_infeasibility_cache, c)
								add_clause(
									skeleton.sat_instance,
									c
								)
								t = solve(skeleton.sat_instance)
								print(".")
								continue
							elseif not_yet_feasible
								add_feasible(feasibility_cache.all, [bounds_vars; map(x->x[1],input); nonlinear_vars])
							end
							# Add nonlinearities to set
							push!(input_nonlinear_disjunction, AST.and_construction(nonlinear_smt))
							add_clause(skeleton.sat_instance, map(x -> -x, nonlinear_vars))
							t = solve(skeleton.sat_instance)
						end
						print_msg("[QUERY] Found all non-linear combinations. Count: ", length(input_nonlinear_disjunction))
						pop(skeleton.sat_instance)
					end
					nonlinear_options=input_nonlinear_disjunction
				end
				for c in secondary_infeasibility_cache
					add_clause(skeleton.sat_instance, c)
					push!(infeasibility_cache, c)
				end
				#print_msg(mixed_smt)
				push!(disjunction_nonlinear,
					(
						mixed_smt,
						AST.or_construction(nonlinear_options)
					)
				)


				# Disallow current mixed constraint for further search
				add_clause(skeleton.sat_instance, map(x -> -x[1], filter(x->x[1]!=0,mixed)))
			end
			# Find new model
			solution = solve(skeleton.sat_instance)
		end
		pop(skeleton.sat_instance)
		# Dump infeasibility_cache into clause database
		add_clauses(skeleton.sat_instance, infeasibility_cache)
		if !isnothing(input)
			# Disallow input
			add_clause(
					skeleton.sat_instance,
					map(x -> -x[1], filter(x->x[1]!=0,input))
				)
			print_msg("[QUERY] Returning nonlinear disjunction")
			return (disjunction_nonlinear,NormalizedQuery(map(x->x[2],input), map(x->x.args,collect(disjunction)), nonlinearities_set, query)), state
		else
			return nothing
		end
	end
end
