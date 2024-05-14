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

function prepare_for_olnnv(query :: Query)
	formula = query.formula
	variable_set = query.variables
	underapprox_formula :: Formula = get_underapprox(formula)
	# We are looking for counter-examples so we use the negation...
	olnnv_formula = AST.simplify(CompositeFormula(Not,[underapprox_formula]))
	return Query(olnnv_formula, variable_set)
end

function run_query(f, query :: Query, ctx, smt_timeout, variables; backup=nothing,backup_meta=nothing)
	approx_cache :: ApproxCache = ApproxCache()
	print_msg("[CTRL] Iterating over conjunctions...")
	# TODO(steuber):
	#  - Reintroduce Over/Under formula wrappers
	#  - Compute variable bounds
	#  - Compute approximations
	#  - Substiute Over/Under with approximations AND (bounds -> approx)
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
			iterable_query = IterableQuery(query, smt_ctx,Config.INCLUDE_APPROXIMATIONS)
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
								cex_count += sum(x->length(x.stars),results)
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
	cex_count += sum(x->length(x.stars),results)
	return results, cex_count
end