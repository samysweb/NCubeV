using TimerOutputs
struct SmtFilterMeta
	original_meta :: Any
	filtered_out :: Int64
	#formula :: Formula
end

function add_to_solver(solver, variables, star, smt_cache)
	input_vars = size(star.constraint_matrix)[2]
	additional = []
	for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
		smt_internal_add(solver, ast2smt(LinearConstraint(c,b,true), variables, additional, smt_cache))
	end
	for (i, b) in enumerate(star.bounds)
		smt_internal_add(solver, ast2smt(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)),variables, additional, smt_cache))
		smt_internal_add(solver, ast2smt(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])),variables, additional, smt_cache))
	end
	for a in additional
		smt_internal_add(solver, a)
	end
	for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
		smt_internal_add(solver, ast2smt(Atom(AST.Eq, Variable("x"*string(input_vars+i), nothing, input_vars+i), LinearTerm(c,b)), variables, additional, smt_cache))
	end
	@assert length(additional) == 0
end

function check_star(ctx,variables, disjunction_nonlinear, star :: Star, smt_cache)
	smt_solver(ctx;theory="qfnra",stars=true) do solver
		add_to_solver(solver, variables, star, smt_cache)
		disjunction = []
		smt_solver(ctx;theory="qflra",stars=true) do lin_solver
			add_to_solver(lin_solver, variables, star, smt_cache)
			for (linear, nonlinear) in disjunction_nonlinear
				smt_internal_push(lin_solver)
				additional = []
				smt_internal_add(lin_solver, ast2smt(linear, variables, additional, smt_cache))
				for a in additional
					smt_internal_add(lin_solver, a)
				end
				lin_solverres = smt_internal_check(lin_solver)
				if !smt_internal_is_unsat(lin_solverres)
					push!(disjunction,
						CompositeFormula(AST.And,[
							linear,
							nonlinear
						])
					)
				end
				smt_internal_pop(lin_solver)
			end
		end
		if length(disjunction) > 0
			additional = []
			smt_internal_add(
				solver,
				ast2smt(AST.or_construction(disjunction),
				variables, additional, smt_cache))
			for a in additional
				smt_internal_add(solver, a)
			end
			solverres = smt_internal_check(solver)
			if smt_internal_is_sat(solverres)
				try
					m = smt_internal_get_model(solver)
					# TODO: Generalize for other SMT solvers...
					num_input_vars = length(star.counter_example[1])
					for (var_index, var) in enumerate(variables)
						var_val =Z3.eval(m,var)
						num = parse(BigInt,convert(String,get_decimal_string(numerator(var_val),100)))
						den = parse(BigInt,convert(String,get_decimal_string(denominator(var_val),100)))
						var_val = convert(Float32,convert(BigFloat,num//den))
						if var_index <= num_input_vars
							star.counter_example[1][var_index] = var_val
						else
							star.counter_example[2][var_index-num_input_vars] = var_val
						end
					end
				catch
					print_msg("[SMT] Reusing original (linear) counter-example due to error in SMT model extraction")
				end
				return 1, star
			elseif !smt_internal_is_unsat(solverres)
				# SMT solver returned unknown
				return 2, star
			else
				return 0, star
			end
		else
			return 0, star
		end
	end
end

function get_star_filter(ctx, variables, disjunction_nonlinear, smt_timeout)
	return function(result :: OlnnvResult)
		smt_cache = Dict()
		@timeit TIMER "star_filter" begin
			if result.status == "safe"
				return result
			else
				filtered_stars = []
				for s in result.stars
					res, s = check_star(ctx,variables, disjunction_nonlinear, s, smt_cache)
					if res > 0
						push!(filtered_stars, Star(s,res==1))
					end
				end
				filtered_out = length(result.stars)-length(filtered_stars)
				num_timeout = count(s->!s.certain,filtered_stars)
				print_msg("[SMT] SMT filtered out ",filtered_out," stars (out of ",length(result.stars),"; TO: ",num_timeout,").")
				if length(filtered_stars) == 0
					return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
					#return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
				else
					return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
					#return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
				end
			end
		end
	end
end

# function get_star_filter(ctx, variables, formula, smt_timeout)
# 	return smt_solver(ctx;stars=true) do solver
# 		#set(solver,"ctrl_c",  true)
# 		set(solver,"unsat-core",false)
# 		additional = []
# 		smt_cache = Dict()
# 		translated = ast2smt(formula, variables, additional, smt_cache)
# 		smt_internal_add(solver, translated)
# 		for a in additional
# 			smt_internal_add(solver, a)
# 		end
# 		solverres = smt_internal_check(solver)
# 		if !smt_internal_is_sat(solverres)
# 			smt_internal_debug(solver, solverres)
# 			@assert !smt_internal_is_unsat(solverres) "Solver result was unsat but should be sat"
# 		end
# 		return function(result :: OlnnvResult)
# 			@timeit TIMER "star_filter" begin
# 				if result.status == "safe"
# 					return result
# 				else
# 					filtered_stars = filter(!=(nothing),map(star_concrete_filter(solver, variables, smt_timeout),result.stars))
# 					filtered_out = length(result.stars)-length(filtered_stars)
# 					print_msg("[SMT] SMT filtered out ",filtered_out," stars (out of ",length(result.stars),").")
# 					if length(filtered_stars) == 0
# 						return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
# 						#return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
# 					else
# 						return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
# 						#return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
# 					end
# 				end
# 			end
# 		end
# 	end
# end
# function star_concrete_filter(solver, variables, smt_timeout)
# 	return function(star :: Star)
# 		@timeit TIMER "star_filter_concrete" begin
# 			# @info "BEFORE:"
# 			# print(solver)
# 			smt_cache = Dict()
# 			smt_internal_push(solver)
# 			input_vars = size(star.constraint_matrix)[2]
# 			additional = []
# 			for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
# 				smt_internal_add(solver, ast2smt(LinearConstraint(c,b,true), variables, additional, smt_cache))
# 			end
# 			for (i, b) in enumerate(star.bounds)
# 				smt_internal_add(solver, ast2smt(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)),variables, additional, smt_cache))
# 				smt_internal_add(solver, ast2smt(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])),variables, additional, smt_cache))
# 			end
# 			for a in additional
# 				smt_internal_add(solver, a)
# 			end
# 			# Check if input even relevant
# 			additional = []
# 			result = nothing
# 			smt_time=0
# 			smt_time = @elapsed begin
# 				try
# 					result = smt_internal_check(solver)
# 				catch e
# 					print_msg("[SMT] solver threw error: ",e)
# 				end
# 			end
# 			#TODO(steuber): SMT time Statistics
# 			if !isnothing(result) && smt_internal_is_unsat(result)
# 				#print_msg("[SMT] Filter took ",smt_time," seconds (pre).")
# 				smt_internal_pop(solver)
# 				return nothing
# 			elseif smt_time > smt_timeout
# 				print_msg("[SMT] Filter took ",smt_time," seconds (pre TO).")
# 				smt_internal_debug(solver, result)
# 				smt_internal_pop(solver)
# 				return Star(star,false)
# 			end
# 			# If input is relevant, then we need to check if there exists a counter-example for the current output mapping...
# 			for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
# 				smt_internal_add(solver, ast2smt(Atom(AST.Eq, Variable("x"*string(input_vars+i), nothing, input_vars+i), LinearTerm(c,b)), variables, additional, smt_cache))
# 			end
# 			@assert length(additional) == 0
# 			result = nothing
# 			smt_time += @elapsed begin
# 				try
# 					result = smt_internal_check(solver)
# 				catch e
# 					print_msg("[SMT] solver threw error: ",e)
# 				end
# 			end
# 			not_known = isnothing(result) || (!smt_internal_is_unsat(result) && !smt_internal_is_sat(result))
# 			#print_msg("[SMT] Filter took ",smt_time," seconds (",((not_known) ? "post TO" : "full"),").")
# 			# @info "AFTER:"
# 			# print(solver)
# 			#@info "SMT Result: ", result
# 			if not_known
# 				print_msg("[SMT] Filter took ",smt_time," seconds (post TO).")
# 				smt_internal_debug(solver, result)
# 			end
# 			smt_internal_pop(solver)
# 			# @info "AFTER POP:"
# 			# print(solver)
# 			if !isnothing(result) && smt_internal_is_unsat(result)
# 				return nothing
# 			elseif !isnothing(result) && smt_internal_is_sat(result)
# 				return Star(star,true)
# 			else
# 				return Star(star,false)
# 			end
# 		end
# 	end
# end