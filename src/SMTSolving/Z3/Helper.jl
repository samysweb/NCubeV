module Z3Helper

# Import Z3 to extend...
import Base: +, *, -, /, ^, <, <=, >, >=
using Z3
for cur_sym in names(Z3;all=true)
    try
        if !(string(cur_sym) in ["#eval","#include","clear_ctx","del_solver","eval","include","init_ctx"])
            if !startswith(string(cur_sym),"#")
                @eval import Z3: $cur_sym
            end
        end
    catch e
        println("Error importing ", string(cur_sym)," from Z3: ",e)
    end
end

export Implies, Ite, +, *, -, /, ^, <, <=, >, >=, is_eq, not_eq, RealVar, RealVal, RealSort


function Implies(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_implies(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function Ite(arg1 :: Z3.Expr, arg2 :: Z3.Expr, arg3 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_ite(ref(ctx), as_ast(arg1), as_ast(arg2), as_ast(arg3)))
end

function +(args :: Z3.Expr...)
    ctx = args[1].ctx
    args = collect(Z3.Z3_ast, map(e -> as_ast(e), args))
    return Expr(ctx, Z3.Z3_mk_add(ref(ctx), length(args), args))
end

function *(args :: Z3.Expr...)
    ctx = args[1].ctx
    args = collect(Z3.Z3_ast, map(e -> as_ast(e), args))
    return Expr(ctx, Z3.Z3_mk_mul(ref(ctx), length(args), args))
end

function -(arg1 :: Z3.Expr, args :: Z3.Expr...)
    ctx = args[1].ctx
    args = collect(Z3.Z3_ast, map(e -> as_ast(e), vcat([arg1],collect(Z3.Expr,args))))
    return Expr(ctx, Z3.Z3_mk_sub(ref(ctx), length(args), args))
end

function -(arg :: Z3.Expr)
    ctx = arg.ctx
    return Expr(ctx, Z3.Z3_mk_unary_minus(ref(ctx), as_ast(arg)))
end

function /(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_div(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function ^(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_power(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function is_eq(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_eq(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function not_eq(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    args = collect(Z3.Z3_ast, map(e -> as_ast(e), [arg1,arg2]))
    return Expr(ctx, Z3.Z3_mk_distinct(ref(ctx), 2, args))
end

function <(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_lt(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function <=(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_le(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function >(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_gt(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function >=(arg1 :: Z3.Expr, arg2 :: Z3.Expr)
    ctx = arg1.ctx
    return Expr(ctx, Z3.Z3_mk_ge(ref(ctx), as_ast(arg1), as_ast(arg2)))
end

function RealSort(ctx=nothing)
    ctx = _get_ctx(ctx)
    Sort(ctx, Z3.Z3_mk_real_sort(ref(ctx)))
end

function RealVar(name::String, ctx=nothing)
    ctx = _get_ctx(ctx)
    return Expr(ctx, Z3.Z3_mk_const(ref(ctx), to_symbol(name, ctx), RealSort(ctx).ast))
end

function RealVal(r::Rational{Int64}, ctx=nothing)
    ctx = _get_ctx(ctx)
    Expr(ctx, Z3.Z3_mk_real(ref(ctx), r.num, r.den))
end



end # module