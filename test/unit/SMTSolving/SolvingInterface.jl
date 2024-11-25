using SNNT.SMTSolving
using SNNT.Config

function smt_eq_var_real(solver :: SMTSolver)
    solver.get_context(3) do (ctx)
        actx = solver.get_ast_context(ctx)
        solver.get_solver(ctx,"qfnra") do (slv)
            # x1 = 1.0
            solver.solve.add_constraint(
                slv,
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.opset.real_literal(actx, 1.0)
                )
            )
            # x2 = 2.0
            solver.solve.add_constraint(
                slv,
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.opset.real_literal(actx, 2.0)
                )
            )
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
            end

            solver.solve.push(slv)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)

            fml = solver.opset.eq(
                actx,
                solver.get_variable(actx, 1),
                solver.get_variable(actx, 2)
            )
            # x1 == x2
            solver.solve.add_constraint(
                slv,
                fml
            )

            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_unsat(res)

            solver.solve.pop(slv)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
            end
        end
    end
end

function smt_eq_leq_lt_var_real_pow(solver :: SMTSolver)
    solver.get_context(3) do (ctx)
        solver.get_solver(ctx,"qfnra") do (slv)
            actx = solver.get_ast_context(ctx)
            # x1 = 1.0
            fml = solver.opset.and(
                actx, [
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.opset.real_literal(actx, 1.0)
                ),
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.opset.power(actx,
                        solver.opset.real_literal(actx, 8.0),
                        solver.opset.real_literal(actx, 2//3)
                    )
                )
            ])
            solver.solve.add_constraint(slv, fml)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 4.0)
            end
            fml2 = solver.opset.leq(
                actx,
                solver.opset.power(actx,
                    solver.opset.real_literal(actx, 4.0),
                    solver.opset.real_literal(actx, 1//2)
                ),
                solver.get_variable(actx, 3)
            )
            solver.solve.add_constraint(slv, fml2)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 4.0)
                @test solver.solve.evaluate_model(model, solver.get_variable(actx, 3)) >= 2.0
            end

            fml3 = solver.opset.lt(
                actx,
                solver.get_variable(actx, 3),
                solver.opset.real_literal(actx, 0.0)
            )
            solver.solve.add_constraint(slv, fml3)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_unsat(res)
            
        end
    end
end

function smt_eq_leq_lt_var_real_plus_mul(solver)
    solver.get_context(3) do (ctx)
        solver.get_solver(ctx,"qfnra") do (slv)
            actx = solver.get_ast_context(ctx)
            # x1 = 1.0
            fml = solver.opset.and(
                actx, [
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.opset.real_literal(actx, 1.0)
                ),
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.opset.add(actx,
                        solver.get_variable(actx, 1),
                        solver.opset.real_literal(actx, 1.0)
                    )
                )
            ])
            solver.solve.add_constraint(slv, fml)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
            end
            fml2 = solver.opset.leq(
                actx,
                solver.opset.mul(actx,
                    solver.opset.real_literal(actx, 2.0),
                    solver.get_variable(actx, 2)
                ),
                solver.get_variable(actx, 3)
            )
            solver.solve.add_constraint(slv, fml2)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 3)), 4.0)
            end

            fml3 = solver.opset.lt(
                actx,
                solver.get_variable(actx, 3),
                solver.opset.real_literal(actx, 0.0)
            )
            solver.solve.add_constraint(slv, fml3)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_unsat(res)
        end
    end
end

function smt_and_or_implies_ite_true_false(solver)
    solver.get_context(3) do (ctx)
        solver.get_solver(ctx,"qfnra") do (slv)
            actx = solver.get_ast_context(ctx)
            # x1 = 1.0
            fml = solver.opset.and(
                actx, [
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.opset.real_literal(actx, 1.0)
                ),
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.opset.real_literal(actx, 2.0)
                )
            ])
            solver.solve.add_constraint(slv, fml)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
            end
            fml2 = solver.opset.or(
                actx,
                [
                    solver.opset.eq(
                        actx,
                        solver.get_variable(actx, 1),
                        solver.opset.real_literal(actx, 1.0)
                    ),
                    solver.opset.eq(
                        actx,
                        solver.get_variable(actx, 2),
                        solver.opset.real_literal(actx, 3.0)
                    )
                ]
            )
            solver.solve.add_constraint(slv, fml2)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
            end
            fml3 = solver.opset.implies(
                actx,
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.opset.real_literal(actx, 1.0)
                ),
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.opset.real_literal(actx, 2.0)
                )
            )
            solver.solve.add_constraint(slv, fml3)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
            end
            fml4 = solver.opset.eq(
                actx,
                solver.get_variable(actx, 3),
                solver.opset.ite(
                    actx,
                    solver.opset.eq(
                        actx,
                        solver.get_variable(actx, 1),
                        solver.opset.real_literal(actx, 1.0)
                    ),
                    solver.get_variable(actx, 2),
                    solver.opset.real_literal(actx, 3.0)
                )
            )
            solver.solve.add_constraint(slv, fml4)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)

            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 3)), 2.0)
            end

            fml5 = solver.opset.eq(
                actx,
                solver.get_variable(actx, 3),
                solver.opset.ite(
                    actx,
                    solver.opset.eq(
                        actx,
                        solver.get_variable(actx, 1),
                        solver.opset.real_literal(actx, 2.0)
                    ),
                    solver.get_variable(actx, 2),
                    solver.opset.real_literal(actx, 3.0)
                )
            )

            solver.solve.add_constraint(slv, fml5)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_unsat(res)
        end
    end
end

function smt_comparators(solver)
    # Test eq, neq, lt, leq, gt, geq
    solver.get_context(3) do (ctx)
        solver.get_solver(ctx,"qfnra") do (slv)
            actx = solver.get_ast_context(ctx)
            # x1 = 1.0
            fml = solver.opset.and(
                actx, [
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.opset.real_literal(actx, 1.0)
                ),
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.opset.real_literal(actx, 2.0)
                )
            ])
            solver.solve.add_constraint(slv, fml)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 2.0)
            end
            fml2 = solver.opset.and(
                actx, [
                solver.opset.lt(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.get_variable(actx, 2)
                ),
                solver.opset.leq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.get_variable(actx, 2)
                ),
                solver.opset.gt(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.get_variable(actx, 1)
                ),
                solver.opset.geq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.get_variable(actx, 1)
                )
            ])
            solver.solve.add_constraint(slv, fml2)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)

            fml3 = solver.opset.not_eq(
                actx,
                solver.get_variable(actx, 1),
                solver.get_variable(actx, 2)
            )
            solver.solve.add_constraint(slv, fml3)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)

            fml4 = solver.opset.lt(
                actx,
                solver.get_variable(actx, 2),
                solver.get_variable(actx, 1)
            )
            solver.solve.add_constraint(slv, fml4)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_unsat(res)
        end
    end
end

function smt_eq_leq_lt_var_real_sub_div(solver)
    solver.get_context(3) do (ctx)
        solver.get_solver(ctx,"qfnra") do (slv)
            actx = solver.get_ast_context(ctx)
            # x1 = 1.0
            fml = solver.opset.and(
                actx, [
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 1),
                    solver.opset.real_literal(actx, 1.0)
                ),
                solver.opset.eq(
                    actx,
                    solver.get_variable(actx, 2),
                    solver.opset.sub(actx,
                        solver.opset.real_literal(actx, 8.0),
                        solver.opset.real_literal(actx, 2.0)
                    )
                )
            ])
            solver.solve.add_constraint(slv, fml)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 6.0)
            end
            fml2 = solver.opset.leq(
                actx,
                solver.opset.div(actx,
                    solver.opset.real_literal(actx, 6.0),
                    solver.get_variable(actx, 2)
                ),
                solver.get_variable(actx, 3)
            )
            solver.solve.add_constraint(slv, fml2)
            solver.solve.process_ast_context(slv, actx)
            res = solver.solve.check_sat(slv)
            @test solver.solve.is_sat(res)
            solver.solve.get_model(slv, res) do model
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 1)), 1.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 2)), 6.0)
                @test isapprox(solver.solve.evaluate_model(model, solver.get_variable(actx, 3)), 1.0)
            end
        end
    end
end

function smt_setup_unsat(solver,ctx,slv)
    actx = solver.get_ast_context(ctx)
    # x1 = 1.0
    fml1 = solver.opset.eq(
        actx,
        solver.get_variable(actx, 1),
        solver.opset.real_literal(actx, 1.0)
    )
    solver.solve.add_constraint(slv, fml1; idx=1)
    fml2 = solver.opset.eq(
        actx,
        solver.get_variable(actx, 1),
        solver.get_variable(actx, 3)
    )
    solver.solve.add_constraint(slv, fml2; idx=2)
    fml3 = solver.opset.eq(
        actx,
        solver.get_variable(actx, 2),
        solver.opset.real_literal(actx, 3.0)
    )
    solver.solve.add_constraint(slv, fml3; idx=3)
    fml4 = solver.opset.eq(
        actx,
        solver.get_variable(actx, 4),
        solver.opset.real_literal(actx, 3.0)
    )
    solver.solve.add_constraint(slv, fml4; idx=4)
    fml5 = solver.opset.eq(
        actx,
        solver.get_variable(actx, 3),
        solver.opset.real_literal(actx, 3.0)
    )
    solver.solve.add_constraint(slv, fml5; idx=5)
    solver.solve.process_ast_context(slv, actx)
end

function smt_core(solver)
    old_core_val = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = true
    try
        solver.get_context(4) do (ctx)
            solver.get_solver(ctx,"qfnra") do (slv)
                smt_setup_unsat(solver,ctx, slv)
                res = solver.solve.check_sat(slv)
                @test solver.solve.is_unsat(res)
                core = solver.solve.get_core(slv)
                @test 1 in core
                @test 2 in core
                @test 5 in core
            end
        end
    finally
        Config.SMT_USE_CORES = old_core_val
    end
end

function smt_no_core(solver)
    old_core_val = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = false
    try
        solver.get_context(4) do (ctx)
            solver.get_solver(ctx,"qfnra") do (slv)
                smt_setup_unsat(solver,ctx, slv)
                res = solver.solve.check_sat(slv)
                @test solver.solve.is_unsat(res)
                core = solver.solve.get_core(slv)
                @test 1 in core
                @test 2 in core
                @test 3 in core
                @test 4 in core
                @test 5 in core
            end
        end
    finally
        Config.SMT_USE_CORES = old_core_val
    end
end


function test_smt_solver(solver)
    smt_eq_var_real(solver)
    smt_eq_leq_lt_var_real_pow(solver)
    smt_eq_leq_lt_var_real_plus_mul(solver)
    smt_eq_leq_lt_var_real_sub_div(solver)
    smt_and_or_implies_ite_true_false(solver)
    smt_comparators(solver)
    smt_core(solver)
    smt_no_core(solver)
end

@testset "SMT Solvers" begin
    @testset "Z3" begin
        test_smt_solver(SMTSolving.Registry.SMT_SOLVERS["Z3"])
    end
end