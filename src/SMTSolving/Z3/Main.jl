module Z3Solver
    using Z3

    using ....AST
    using ....Config

    VAR_COUNTER = 0
    include("Helper.jl")
    using .Z3Helper

    include("Definitions.jl")
    include("Base.jl")
    include("Opset.jl")
    include("SolveOpset.jl")

    using ..Registry
    using ..SMTInterface

    function __init__()
        global VAR_COUNTER = 0
        opset = SMTOpset(
            z3_not,
            z3_and,
            z3_or,
            z3_implies,
            z3_ite,
            z3_true_literal,
            z3_false_literal,
            z3_real_literal,
            z3_add,
            z3_mul,
            z3_sub,
            z3_div,
            z3_power,
            z3_neg,
            z3_eq,
            z3_not_eq,
            z3_lt,
            z3_leq,
            z3_gt,
            z3_geq
        )
        solve = SolveOpset(
            add_constraint,
            process_ast_context,
            check_sat,
            is_sat,
            is_unsat,
            get_model,
            evaluate_model,
            print_model,
            push,
            pop,
            get_core
        )
        smt_solver = SMTSolver("Z3",
            get_context,
            get_ast_context,
            is_cached,
            get_cached,
            cache,
            get_ast_ctx_variable,
            opset,
            get_solver,
            solve
        )
        register_smt_solver("Z3",smt_solver)
    end
end