module SMTInterface

export SMTOpset, SMTSolver

export SMTSolver, SolveOpset, SMTOpset

struct SMTOpset
    not # (ast_context, SMTExpr) -> SMTExpr
    and # (ast_context, Vector{SMTExpr}) -> SMTExpr
    or # (ast_context, Vector{SMTExpr}) -> SMTExpr
    implies # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    ite # (ast_context, SMTExpr, SMTExpr, SMTExpr) -> SMTExpr

    true_literal # (ast_context) -> SMTExpr
    false_literal # (ast_context) -> SMTExpr

    real_literal # (ast_context, Rational{BigInt}) -> SMTExpr

    add # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    mul # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    sub # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    div # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    power # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    neg # (ast_context, SMTExpr) -> SMTExpr

    eq # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    not_eq # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    lt # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    leq # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    gt # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
    geq # (ast_context, SMTExpr, SMTExpr) -> SMTExpr
end

struct SolveOpset

    add_constraint # (solver, constraint; idx=nothing) -> nothing
    process_ast_context # (solver, ast_context) -> nothing

    check_sat # (solver) -> result

    is_sat # (result) -> Bool
    is_unsat # (result) -> Bool

    get_model # (f, solver, result) -> f(model)
    evaluate_model # (model, SMTExpr) -> Any
    print_model # (model) -> nothing

    push # (solver) -> nothing
    pop # (solver) -> nothing

    get_core # (solver) -> Vector{Int}
end

struct SMTSolver
    name::String

    # Init
    get_context # (f, var_num) -> f(ctx)

    # AST2SMT
    # AST2SMT Context
    get_ast_context # (context) -> ast_context
    is_cached # (ast_context, f) -> Bool
    get_cached # (ast_context, f) -> SMTExpr
    cache # (ast_context, f, SMTExpr) -> nothing

    get_variable # (ast_context, Int) -> SMTExpr

    # AST2SMT Opset
    opset :: SMTOpset

    # Solver
    # theory ∈ {"qfnra", "qflra"}
    get_solver # (f, ctx, theory) -> f(solver)

    # Solver
    solve :: SolveOpset
end
end