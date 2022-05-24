struct SmtFilterMeta
	original_meta :: Any
	filtered_out :: Int64
end

function get_star_filter(ctx, variables, formula)
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
				filtered_stars = filter(!=(nothing),map(star_concrete_filter(solver, variables),result.stars))
				filtered_out = length(result.stars)-length(filtered_stars)
				println("[SMT] SMT filtered out ",filtered_out," stars (out of ",length(result.stars),").")
				if length(filtered_stars) == 0
					return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
				else
					return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
				end
			end
		end
	end
end
function star_concrete_filter(solver, variables)
	return function(star :: Star)
		# @info "BEFORE:"
		# print(solver)
		smt_internal_push(solver)
		input_vars = size(star.constraint_matrix)[2]
		additional = []
		for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
			smt_internal_add(solver, ast2smt(LinearConstraint(c,b,true), variables, additional))
		end
		for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
			smt_internal_add(solver, ast2smt(Atom(AST.Eq, LinearTerm(c,b), Variable("x"*string(input_vars+i), nothing, input_vars+i)), variables, additional))
		end
		for (i, b) in enumerate(star.bounds)
			smt_internal_add(solver, ast2smt(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)),variables, additional))
			smt_internal_add(solver, ast2smt(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])),variables, additional))
		end
		for a in additional
			smt_internal_add(solver, a)
		end
		result = nothing
		smt_time = @elapsed begin
			try
				result = smt_internal_check(solver)
			catch e
				throw(e)
			end
		end
		println("[SMT] Filter took ",smt_time," seconds.")
		# @info "AFTER:"
		# print(solver)
		#@info "SMT Result: ", result
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