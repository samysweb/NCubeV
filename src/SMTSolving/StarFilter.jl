struct SmtFilterMeta
	original_meta :: Any
	filtered_out :: Int64
	#formula :: Formula
end

function check_star(ctx, disjunction_nonlinear, solver, star)
    actx = solver.get_ast_context(ctx)
    input_vars = size(star.constraint_matrix)[2]
    full_substitution = Dict{Variable,Term}()
    for (i,val) in enumerate(star.counter_example[1])
        full_substitution[Variable("x"*string(i), nothing, i)] = TermNumber(val)
    end
    for (i,val) in enumerate(star.counter_example[2])
        full_substitution[Variable("x"*string(input_vars+i), nothing, input_vars+i)] = TermNumber(val)
    end
    for (linear, nonlinear) in disjunction_nonlinear
        res = substitute(CompositeFormula(And, [linear, nonlinear]), full_substitution;fold=true)
        if res isa TrueAtom
            return 1, Star(star, true)
        end
    end
    substitution = Dict{Variable,Term}()
	for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
		# Variable("x"*string(input_vars+i), nothing, input_vars+i) = LinearTerm(c,b)
        substitution[Variable("x"*string(input_vars+i), nothing, input_vars+i)] = LinearTerm(c,b)
	end
    translated = []
    for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
        push!(translated, ast2smt(LinearConstraint(c,b,true), actx, solver))
    end
    for (i, b) in enumerate(star.bounds)
        push!(translated, ast2smt(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)), actx, solver))
        push!(translated, ast2smt(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])), actx, solver))
    end
    return solver.get_solver(ctx,"qfnra") do slv_nl
        return solver.get_solver(ctx, "qflra") do slv_lin
            for t in translated
                solver.solve.add_constraint(slv_nl, t)
                solver.solve.add_constraint(slv_lin, t)
            end
            solver.solve.process_ast_context(slv_nl, actx)
            solver.solve.process_ast_context(slv_lin, actx)

            for (linear, nonlinear) in disjunction_nonlinear
                solver.solve.push(slv_lin)
                try
                    linear = substitute(linear, substitution)
                    nonlinear = substitute(nonlinear, substitution)
                    actx = solver.get_ast_context(ctx)
                    solver.solve.add_constraint(slv_lin, ast2smt(linear, actx, solver))
                    solver.solve.process_ast_context(slv_lin, actx)
                    res = solver.solve.check_sat(slv_lin)
                    if !solver.solve.is_unsat(res)
                        solver.solve.push(slv_nl)
                        try
                            # Check nonlinear constraints
                            actx = solver.get_ast_context(ctx)
                            solver.solve.add_constraint(slv_lin, ast2smt(linear, actx, solver))
                            solver.solve.add_constraint(slv_lin, ast2smt(nonlinear, actx, solver))
                            solver.solve.process_ast_context(slv_lin, actx)
                            res = solver.solve.check_sat(slv_lin)
                            if solver.solve.is_unsat(res)
                                # Spurious counterexample
                                return 0, star
                            else
                                if solver.solve.is_sat(res)
                                    try
                                        # Concrete counterexample
                                        return solver.solve.get_model(slv_lin, res) do m
                                            input_substitution = Dict{Variable,Number}()
                                            for i in 1:input_vars
                                                cur_var = solver.get_variable(actx, i)
                                                var_val = solver.solve.evaluate_model(m, cur_var)
                                                input_substitution[Variable("x$i",nothing,i)] = var_val
                                                star.counter_example[1][i] = var_val
                                            end
                                            for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
                                                cur_val = substitute(LinearTerm(c,b), input_substitution)
                                                star.counter_example[2][i] = cur_val.value
                                            end
                                            return 1, star
                                        end
                                    catch e
                                        if Config.OUTPUT
                                            showerror(stdout, e, catch_backtrace())
                                            print_msg("[SMT] Reusing original (linear) counter-example due to error in SMT model extraction")
                                        end
                                        return 2, star
                                    end
                                else
                                    # Unknown
                                    return 2, star
                                end
                            end
                        finally
                            solver.solve.pop(slv_nl)
                        end
                    end
                finally
                    solver.solve.pop(slv_lin)
                end
            end
            return 0, nothing
        end
    end
end

function get_star_filter(ctx, disjunction_nonlinear)
    solver = Registry.SMT_SOLVERS[Config.SMT_SOLVER]
	return function(result :: OlnnvResult)
        found_first=false
        idx = 0
        @timeit Config.TIMER "star_filter" begin
            if result.status == "safe"
                return result
            else
                total_stars = length(result.stars)
                filtered_stars = []
                num_timeout = 0
                while length(result.stars)>0
                    s = pop!(result.stars)
                    idx+=1
                    if Config.OUTPUT && idx % 100 == 0
                        print_msg("[SMT] Processing star ",idx," of ",length(result.stars))
                    end
                    res, s = check_star(ctx, disjunction_nonlinear, solver, s)
                    if res > 0
						push!(filtered_stars, Star(s,res==1))
						if !found_first && res == 1
							found_first = true
							print_msg("[SMT] Found first counter-example")
							print_msg("[SMT] ", s.counter_example)
                        else
                            num_timeout+=1
						end
					end
                end
                filtered_out = total_stars-length(filtered_stars)
				print_msg("[SMT] SMT filtered out ",filtered_out," stars (out of ",total_stars,"; TO: ",num_timeout,").")
				if length(filtered_stars) == 0
					return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
				else
					return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
				end
            end
        end
    end
end