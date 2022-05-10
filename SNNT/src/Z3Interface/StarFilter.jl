function get_star_filter(ctx, variables, formula)
	return z3_solver(ctx) do solver
		translated = ast2z3(formula, variables)
		add(solver, translated)
		@assert check(solver)==Z3.sat
		return function(result :: OlnnvResult)
			if result.result_str == "safe"
				return result
			else
				filtered_stars = filter(star_concrete_filter(solver, variables),result.stars)
				@info "Z3 filtered out ",length(result.stars)-length(filtered_stars)," stars (out of ",length(result.stars),")."
				if length(filtered_stars) == 0
					return OlnnvResult("safe", result.metadata, filtered_stars)
				else
					return OlnnvResult(result.result_str, result.metadata, filtered_stars)
				end
			end
		end
	end
end
function star_concrete_filter(solver, variables)
	return function(star :: Star)
		# @info "BEFORE:"
		# print(solver)
		push(solver)
		input_vars = size(star.constraint_matrix)[2]
		for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
			add(solver, ast2z3(LinearConstraint(c,b,true), variables))
		end
		for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
			add(solver, ast2z3(Atom(AST.Eq, LinearTerm(c,b), Variable("x"*string(input_vars+i), nothing, input_vars+i)), variables))
		end
		for (i, b) in enumerate(star.bounds)
			add(solver, ast2z3(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)),variables))
			add(solver, ast2z3(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])),variables))
		end
		result = check(solver)
		# @info "AFTER:"
		# print(solver)
		# @info "Z3 Result: ", result
		pop(solver,1)
		# @info "AFTER POP:"
		# print(solver)
		return result != Z3.unsat
	end
end