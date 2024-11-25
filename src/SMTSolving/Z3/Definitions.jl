struct Z3ExprContainer
    expr :: Z3.Expr
    additional :: Vector{Z3.Expr}
end

struct Z3Context
    ctx :: Z3.Context
    variables :: Vector{Z3.Expr}
end

struct ASTZ3Context
    ctx :: Z3Context
    smt_cache :: Dict{ParsedNode,Z3ExprContainer}
end

mutable struct Z3SolverContainer
    ctx :: Z3Context
    solver
    named_assertions :: Dict{Z3.Z3_ast,Int}
    function Z3SolverContainer(ctx, solver)
        named_assertions = Dict{Z3.Expr,Int}()
        s = new(ctx, solver, named_assertions)
        finalizer(finalizer_z3_solver_container, s)
    end
end
function finalizer_z3_solver_container(s :: Z3SolverContainer)
    for (k,_) in s.named_assertions
        Z3.Z3_dec_ref(s.ctx.ctx.ctx, k)
    end
end

struct Z3ModelContainer
    ctx :: Z3Context
    model
    function Z3ModelContainer(ctx, model)
        new(ctx, model)
    end
end
