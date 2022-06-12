struct SmtFilterMeta
	original_meta :: Any
	filtered_out :: Int64
	#formula :: Formula
end

function get_star_filter(ctx, variables, formula, smt_timeout)
	return smt_solver(ctx) do solver
		#set(solver,"ctrl_c",  true)
		additional = []
		translated = ast2smt(formula, variables, additional)
		smt_internal_add(solver, translated)
		for a in additional
			smt_internal_add(solver, a)
		end
		solverres = smt_internal_check(solver)
		if !smt_internal_is_sat(solverres)
			smt_internal_debug(solver, solverres)
			@assert false "Solver result was $solverres but should be sat"
		end
		return function(result :: OlnnvResult)
			if result.status == "safe"
				return result
			else
				filtered_stars = filter(!=(nothing),map(star_concrete_filter(solver, variables, smt_timeout),result.stars))
				filtered_out = length(result.stars)-length(filtered_stars)
				print_msg("[SMT] SMT filtered out ",filtered_out," stars (out of ",length(result.stars),").")
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
function star_concrete_filter(solver, variables, smt_timeout)
	return function(star :: Star)
		# @info "BEFORE:"
		# print(solver)
		smt_internal_push(solver)
		input_vars = size(star.constraint_matrix)[2]
		additional = []
		for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
			smt_internal_add(solver, ast2smt(LinearConstraint(c,b,true), variables, additional))
		end
		for (i, b) in enumerate(star.bounds)
			smt_internal_add(solver, ast2smt(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)),variables, additional))
			smt_internal_add(solver, ast2smt(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])),variables, additional))
		end
		for a in additional
			smt_internal_add(solver, a)
		end
		# Check if input even relevant
		additional = []
		result = nothing
		smt_time=0
		smt_time = @elapsed begin
			try
				result = smt_internal_check(solver)
			catch e
				print_msg("[SMT] solver threw error: ",e)
			end
		end
		if !isnothing(result) && smt_internal_is_unsat(result)
			print_msg("[SMT] Filter took ",smt_time," seconds (pre).")
			smt_internal_pop(solver)
		 	return nothing
		elseif smt_time > (smt_timeout/1000.0)
		 	print_msg("[SMT] Filter took ",smt_time," seconds (pre TO).")
			smt_internal_debug(solver, result)
			smt_internal_pop(solver)
		 	return Star(star,false)
		end
		# If input is relevant, then we need to check if there exists a counter-example for the current output mapping...
		for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
			smt_internal_add(solver, ast2smt(Atom(AST.Eq, LinearTerm(c,b), Variable("x"*string(input_vars+i), nothing, input_vars+i)), variables, additional))
		end
		@assert length(additional) == 0
		result = nothing
		smt_time += @elapsed begin
			try
				result = smt_internal_check(solver)
			catch e
				print_msg("[SMT] solver threw error: ",e)
			end
		end
		not_known = isnothing(result) || (!smt_internal_is_unsat(result) && !smt_internal_is_sat(result))
		print_msg("[SMT] Filter took ",smt_time," seconds (",((not_known) ? "post TO" : "full"),").")
		# @info "AFTER:"
		# print(solver)
		#@info "SMT Result: ", result
		if not_known
			smt_internal_debug(solver, result)
		end
		smt_internal_pop(solver)
		# @info "AFTER POP:"
		# print(solver)
		if !isnothing(result) && smt_internal_is_unsat(result)
			return nothing
		elseif !isnothing(result) && smt_internal_is_sat(result)
			return Star(star,true)
		else
			return Star(star,false)
		end
	end
end