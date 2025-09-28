"""
    load_query(file, fixed_variables, mapping) -> Query

Parse a specification file and produce a `Query` with variables mapped and optional
variables fixed to constants. Performs translation to NCubeV AST linear/nonlinear atoms.

Arguments
- `file::String`: Path to the problem file (currently only supports custom format) understood by `Parsing`.
- `fixed_variables::Dict{String,Union{String,Number}}`: Variable assignments to inline.
- `mapping::Dict{String,Tuple{AST.VariableType,Int64}}`: Variable roles and positions.

Returns
- `Query`: A query with `formula::Formula` and `variables::Set{Variable}`.

Example
```julia
julia> using NCubeV.Control
julia> q = load_query("test/parsing/examples/acc.smt2", Dict(), Dict());
```

Notes
- This prepares the problem for subsequent normalization and approximation.
See also: [`prepare_for_olnnv`](@ref), [`run_query`](@ref).
"""
function load_query(file::String,
						fixed_variables::Dict{String, Union{String, Number}},
						mapping::Dict{String, Tuple{AST.VariableType, Int64}})
	# Load the problem
	constraints :: Formula  = Parsing.parse_constraint(file)
	# Fix the variables
	constraints_fixed_vars :: Formula  = fix_variables(constraints, fixed_variables)
	# Get the variables
	variable_set :: Set{Variable}, constraints_updated_vars :: Formula = map_variables(constraints_fixed_vars,mapping)

	# Translate the constraints to linear (LinearConstraint)/nonlinear (remains Atom)
	constraints_translated_constraints :: Formula = translate_constraints(constraints_updated_vars, variable_set)
	
	return Query(AST.simplify(constraints_translated_constraints), variable_set)
end

"""
    prepare_for_olnnv(query::Query) -> Query

Transform the query into the open-loop NNV view by taking an under-approximation
and negating the property to search for counterexamples.

Implements the standard reduction to reachability used by open-loop tools.
"""
function prepare_for_olnnv(query :: Query)
	formula = query.formula
	variable_set = query.variables
	underapprox_formula :: Formula = get_underapprox(formula)
	# We are looking for counter-examples so we use the negation...
	olnnv_formula = AST.simplify(CompositeFormula(Not,[underapprox_formula]))
	return Query(olnnv_formula, variable_set)
end

"""
    run_query(f, query, ctx, smt_timeout, variables; backup=nothing, backup_meta=nothing)
        -> (results, cex_count)

Run the full NCubeV pipeline on `query`, invoking a callback `f` for each linear
open-loop query.
Typically, `f` is used to:
- Search for counterexamples to the concrete open-loop query;
- Check counterexamples via SMT solving (via the `star_filter` generated here);
- Return the an OlnnvResult containing all (non-spurious) counterexamples.

Arguments
- `f`: Callback of type `(linear_query, star_filter) -> OlnnvResult`.
  `star_filter` is of type `OlnnvResult -> OlnnvResult`
- `query::Query`: Input query (will be approximated via `Approx`).
- `ctx`: SMT context handle; see `SMTInterface.smt_context`.
- `smt_timeout`: Timeout bound for SMT filtering per region.
- `variables`: Variable vector consistent with the query.
- `backup`: Optional destination for periodic state dump.
- `backup_meta`: Optional metadata to be saved along with the periodic state dump.

Returns
- `results::Vector{OlnnvResult}`: Collected backend results (potentially filtered).
- `cex_count::Int`: Number of counterexample regions discovered (post-filter).

References
- Mosaic iteration over conjunctions: Appendix B.2
- Counterexample generalization and filtering: Appendix B.3 (Definition 11, Lemma 12)
  Note this method does not perform the start filtering itself!
  It only provides the appropriate filter primitive to be passed to `f`.

Example
```julia
julia> using NCubeV
julia> res, n = NCubeV.Control.run_query(backend_callback, q, ctx, 5.0, vars);
```

!!! note
    Counterexample enumeration can be exponential in the number of piece-wise linear
    nodes.
"""
function run_query(f, query :: Query, ctx, smt_timeout, variables; backup=nothing,backup_meta=nothing)
	approx_cache :: ApproxCache = ApproxCache()
	print_msg("[CTRL] Iterating over conjunctions...")
	results = []
	cex_count = 0
	num_invocations = 1
	original_query = query
	query = get_approx_query(query)
	#print_msg("[CTRL] Query formula: ",query.formula)
	last_save_time = time_ns()
	@timeit Config.TIMER "query_iteration" begin
		# TODO(steuber): Make SMT timeout for normalization configurable
		smt_context(query.num_input_vars+query.num_output_vars;timeout=10000) do smt_ctx
			iterable_query = IterableQuery(query, smt_ctx, Config.INCLUDE_APPROXIMATIONS)
			for (disjunction_nonlinear,current_conjunction) in iterable_query
				print_msg("[CTRL] Considering conjunction with ",
					length(current_conjunction.input_constraints.linear_constraints)+length(current_conjunction.input_constraints.semilinear_constraints),
					" input constraints and a disjunction of size ",length(current_conjunction.mixed_constraints))
				#@info "Input Constraints:",current_conjunction.input_constraints
				#@info "Mixed:"
				#for mixed in current_conjunction.mixed_constraints
				#	@info mixed
				#end
				#if Config.INCLUDE_APPROXIMATIONS
				#	SMTFilter = SMTInterface.get_star_filter(ctx, variables, nonlinear_conjunction, smt_timeout)
				#else
				@timeit Config.TIMER "smt_filter_creation" begin
					SMTFilter = SMTInterface.get_star_filter(ctx, variables, disjunction_nonlinear, smt_timeout)
					#SMTFilter = SMTInterface.get_star_filter(ctx, variables, original_query.formula, smt_timeout)
				end
				#end
				# TODO(steuber): These days we are resolving the approximation **before**
				# running Mosaic. Therefore, we no longer need to generate/decompose
				# approximations here. We should probably remove this some time
				# (as well as the for loop around what is below)
				@timeit Config.TIMER "legacy_approx" begin
					approx_normalized :: ApproxNormalizedQueryPrototype{Approximation} = get_approx_normalized_query(current_conjunction, approx_cache)
				end
				print_msg("[CTRL] Initiating iterator over current linear queries")
				for linear_query in approx_normalized
					@timeit Config.TIMER "olnnv_query_processing" begin
						num_invocations += 1
						print_msg("[CTRL] Processing linear query no. ",num_invocations)
						push!(results,f((linear_query, SMTFilter)))
						# Save at most every 200s
						if !isnothing(backup) && (time_ns() - last_save_time) > 200e9
							last_save_time = time_ns()
							@timeit Config.TIMER "status_backup" begin
								print_msg("[CTRL] Saving current state of verification...")
								save(backup*"-"*string(num_invocations)*".jld","result",results,"backup_meta",backup_meta)
								cex_count += sum(x->length(x.stars),results,init=0)
								results = []
								GC.gc()
							end
							show(Config.TIMER)
						end
					end
				end
			end
		end
	end
	cex_count += sum(x->length(x.stars),results,init=0)
	return results, cex_count
end