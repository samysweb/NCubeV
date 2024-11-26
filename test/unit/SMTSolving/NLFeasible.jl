using SNNT.AST
using SNNT.SMTSolving
using SNNT.Config

function test_nl_lin_smt_feasible()
    smt_context(2) do (ctx)
        @test nl_feasible(
            Formula[
                LinearConstraint([1.0, 0.0], 2.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, true)
            ],
            ctx,
            []
        )
        @test nl_feasible(
            Formula[
                LinearConstraint([1.0, 1.0], 2.0, true),
                LinearConstraint([-1.0, 0.0], -2.0, true)
            ],
            ctx,
            []
        )
    end
end

function test_nl_lin_smt_infeasible_core()
    core_config = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = true
    try
    smt_context(2) do (ctx)
        conflicts = []
        @test !nl_feasible(
            Formula[
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
        @test !nl_feasible(
            Formula[
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

function test_nl_lin_smt_infeasible_nocore()
    core_config = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = false
    try
    smt_context(2) do (ctx)
        conflicts = []
        @test !nl_feasible(
            Formula[
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
        @test !nl_feasible(
            Formula[
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

function test_nl_nl_smt_feasible()
    smt_context(2) do (ctx)
        @test nl_feasible(
            Formula[
                Atom(
                    LessEq,
                    CompositeTerm(Pow, [Variable("x1",nothing,1), TermNumber(2//1)]),
                    CompositeTerm(Pow, [Variable("x2",nothing,2), TermNumber(1//2)])
                ),
                Atom(
                    Eq,
                    CompositeTerm(Div, Term[Variable("x1",nothing,1),TermNumber(1//2)]),
                    TermNumber(1//1)
                ),
                Atom(
                    GreaterEq,
                    TermNumber(2//1),
                    Variable("x2",nothing,2)
                )
            ],
            ctx,
            []
        )
    end
end

function test_nl_nl_smt_infeasible_nocore()
    core_config = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = false
    try
    smt_context(2) do (ctx)
        conflicts = []
        @test !nl_feasible(
            Formula[
                Atom(
                    LessEq,
                    CompositeTerm(Pow, [Variable("x1",nothing,1), TermNumber(2//1)]),
                    CompositeTerm(Pow, [Variable("x2",nothing,2), TermNumber(1//2)])
                ),
                Atom(
                    Eq,
                    Variable("x1",nothing,1),
                    TermNumber(2//1)
                ),
                Atom(
                    Less,
                    Variable("x2",nothing,2),
                    TermNumber(2//1)
                ),
                Atom(
                    Greater,
                    CompositeTerm(Neg,Term[Variable("x2",nothing,2)]),
                    CompositeTerm(Sub, Term[TermNumber(0//1),TermNumber(1000//1)])
                )
            ],
            ctx,
            conflicts
        )
        @test 1 in conflicts
        @test 2 in conflicts
        @test 3 in conflicts
        @test 4 in conflicts

        @test !nl_feasible(
            Formula[
                Atom(
                    Less,
                    CompositeTerm(Pow, [Variable("x1",nothing,1), TermNumber(2//1)]),
                    TermNumber(0//1)
                )
            ],
            ctx,
            []
        )
    end
    finally
        Config.SMT_USE_CORES = core_config
    end
end

function test_nl_nl_smt_infeasible_core()
    core_config = Config.SMT_USE_CORES
    Config.SMT_USE_CORES = true
    try
    smt_context(2) do (ctx)
        conflicts = []
        @test !nl_feasible(
            Formula[
                Atom(
                    LessEq,
                    CompositeTerm(Pow, [Variable("x1",nothing,1), TermNumber(2//1)]),
                    CompositeTerm(Pow, [Variable("x2",nothing,2), TermNumber(1//2)])
                ),
                CompositeFormula(
                    AST.And,
                    Formula[
                    Atom(
                        Eq,
                        Variable("x1",nothing,1),
                        TermNumber(2//1)
                    ),
                    Atom(
                        Less,
                        Variable("x2",nothing,2),
                        TermNumber(2//1)
                    )
                ]),
                Atom(
                    GreaterEq,
                    CompositeTerm(Mul,Term[TermNumber(-1//1),Variable("x2",nothing,2)]),
                    TermNumber(-1000//1)
                )
            ],
            ctx,
            conflicts
        )
        @test 1 in conflicts
        @test 2 in conflicts
    end
    finally
        Config.SMT_USE_CORES=core_config
    end
end

function test_nl_lin_smt()
    Config.SMT_SOLVER = "Z3"
    @testset "Feasible" begin
        test_nl_lin_smt_feasible()
        test_nl_nl_smt_feasible()
    end
    @testset "Infeasible" begin
        test_nl_lin_smt_infeasible_core()
        test_nl_lin_smt_infeasible_nocore()
        test_nl_nl_smt_infeasible_core()
        test_nl_nl_smt_infeasible_nocore()
    end
end

@testset "NLFeasible" begin
    @testset "Linear_Sanity" begin
        test_nl_lin_smt()
    end
end