function z3_not(ctx :: ASTZ3Context, f :: Z3.Expr)
    return Z3.Not(f)
end

function z3_and(ctx :: ASTZ3Context, fs :: Vector{Z3.Expr})
    return Z3.And(fs)
end

function z3_or(ctx :: ASTZ3Context, fs :: Vector{Z3.Expr})
    return Z3.Or(fs)
end

function z3_implies(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return Z3Helper.Implies(f1, f2)
end

function z3_ite(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr, f3 :: Z3.Expr)
    return Z3Helper.Ite(f1, f2, f3)
end

function z3_true_literal(ctx :: ASTZ3Context)
    return Z3.BoolVal(true, ctx.ctx.ctx)
end

function z3_false_literal(ctx :: ASTZ3Context)
    return Z3.BoolVal(false, ctx.ctx.ctx)
end

function z3_real_literal(ctx :: ASTZ3Context, r :: T) where {T <: Real}
    r = rationalize(Int64, r)
    return Z3Helper.RealVal(r, ctx.ctx.ctx)
end

function z3_add(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 + f2
end

function z3_mul(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 * f2
end

function z3_sub(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 - f2
end

function z3_div(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 / f2
end

function z3_power(ctx :: ASTZ3Context, base :: Z3.Expr, exp :: Z3.Expr)
    #return f1 ^ f2
    denExp = Z3.Z3_get_denominator(ctx.ctx.ctx.ctx,Z3.as_ast(exp))
    den = Z3.Z3_get_numeral_double(ctx.ctx.ctx.ctx,denExp)
    denExp = Z3.Expr(ctx.ctx.ctx, denExp)
	if isone(den)
		return base^exp
	else
        global VAR_COUNTER+=1
        helper = RealVar("h$VAR_COUNTER", ctx.ctx.ctx)
        
        if convert(Int,den) % 2 == 0
            push!(ctx.additional,
                z3_and(ctx, Z3.Expr[
                    Z3Helper.is_eq(helper^denExp, base),
                    (z3_real_literal(ctx,0) <= helper)
                    ])
                )
        else
            push!(ctx.additional,
            Z3Helper.is_eq(helper^denExp, base)
            )
        end
        numExp = Z3.Z3_get_numerator(ctx.ctx.ctx.ctx,Z3.as_ast(exp))
        num = Z3.Z3_get_numeral_double(ctx.ctx.ctx.ctx,numExp)
        numExp = Z3.Expr(ctx.ctx.ctx, numExp)
        if isone(num)
            return helper
        else
            return helper^numExp
        end
	end
end

function z3_neg(ctx :: ASTZ3Context, f :: Z3.Expr)
    return -f
end

function z3_eq(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return Z3Helper.is_eq(f1, f2)
end

function z3_not_eq(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return Z3Helper.not_eq(f1, f2)
end

function z3_lt(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 < f2
end

function z3_leq(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 <= f2
end

function z3_gt(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 > f2
end

function z3_geq(ctx :: ASTZ3Context, f1 :: Z3.Expr, f2 :: Z3.Expr)
    return f1 >= f2
end

