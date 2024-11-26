function test_lin_smt_feasible()
    smt_context(2) do (ctx)
        @test lin_feasible(
            LinearConstraint[
                LinearConstraint([1.0, 0.0], 2.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, true)
            ],
            ctx,
            []
        )
        @test lin_feasible(
            LinearConstraint[
                LinearConstraint([1.0, 1.0], 2.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, true)
            ],
            ctx,
            []
        )
    end
end

function test_lin_smt_infeasible_core()
    core_config = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = true
    try
    smt_context(2) do (ctx)
        conflicts = []
        @test !lin_feasible(
            LinearConstraint[
                LinearConstraint([1.0, 0.0], 2.0, true),
                LinearConstraint([0.0, 1.0], -2.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, false)
            ],
            ctx,
            conflicts
        )
        @test 1 in conflicts
        # 2 might not be in conflict
        @test 3 in conflicts
        conflicts = []
        @test !lin_feasible(
            LinearConstraint[
                LinearConstraint([1.0, 1.0], 2.0, true),
                LinearConstraint([0.0, -1.0], 0.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, false)
            ],
            ctx,
            conflicts
        )
        @test 1 in conflicts
        @test 2 in conflicts
        @test 3 in conflicts

    end
    finally
        Config.SMT_USE_CORES = core_config
    end
end

function test_lin_smt_infeasible_nocore()
    core_config = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = false
    try
    smt_context(2) do (ctx)
        conflicts = []
        @test !lin_feasible(
            LinearConstraint[
                LinearConstraint([1.0, 0.0], 2.0, true),
                LinearConstraint([0.0, 1.0], -2.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, false)
            ],
            ctx,
            conflicts
        )
        @test 1 in conflicts
        @test 2 in conflicts
        @test 3 in conflicts
        conflicts = []
        @test !lin_feasible(
            LinearConstraint[
                LinearConstraint([1.0, 1.0], 2.0, true),
                LinearConstraint([0.0, -1.0], 0.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, false)
            ],
            ctx,
            conflicts
        )
        @test 1 in conflicts
        @test 2 in conflicts
        @test 3 in conflicts

    end
    finally
        Config.SMT_USE_CORES = core_config
    end
end

function test_lin_smt()
    Config.SMT_SOLVER = "Z3"
    @testset "Feasible" begin
        test_lin_smt_feasible()
    end
    @testset "Infeasible" begin
        test_lin_smt_infeasible_core()
        test_lin_smt_infeasible_nocore()
    end
end

@testset "LinFeasible" begin
    test_lin_smt()
end