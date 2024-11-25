struct Z3Context
    ctx :: Z3.Context
    variables :: Vector{Z3.Expr}
end

struct ASTZ3Context
    ctx :: Z3Context
    additional :: Vector{Z3.Expr}
    smt_cache :: Dict{ParsedNode,Z3.Expr}
end

struct Z3SolverContainer
    ctx :: Z3Context
    solver
    named_assertions :: Dict{Z3.Expr,Int}
    function Z3SolverContainer(ctx, solver)
        named_assertions = Dict{Z3.Expr,Int}()
        new(ctx, solver, named_assertions)
    end
end

struct Z3ModelContainer
    ctx :: Z3Context
    model
    function Z3ModelContainer(ctx, model)
        new(ctx, model)
    end
end
