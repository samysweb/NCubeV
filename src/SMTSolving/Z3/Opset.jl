function z3_not(ctx :: ASTZ3Context, f :: Z3ExprContainer)
    return Z3ExprContainer(Z3.Not(f.expr), f.additional)
end

function z3_and(ctx :: ASTZ3Context, fs :: Vector{Z3ExprContainer})
    return Z3ExprContainer(Z3.And(map(f -> f.expr, fs)), vcat(map(f -> f.additional, fs)...))
end

function z3_or(ctx :: ASTZ3Context, fs :: Vector{Z3ExprContainer})
    return Z3ExprContainer(Z3.Or(map(f -> f.expr, fs)), vcat(map(f -> f.additional, fs)...))
end

function z3_implies(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(Z3Helper.Implies(f1.expr, f2.expr), Z3.Expr[f1.additional; f2.additional])
end

function z3_ite(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer, f3 :: Z3ExprContainer)
    return Z3ExprContainer(
        Z3Helper.Ite(f1.expr, f2.expr, f3.expr),
        Z3.Expr[f1.additional; f2.additional; f3.additional])
end

function z3_true_literal(ctx :: ASTZ3Context)
    return Z3ExprContainer(Z3.BoolVal(true, ctx.ctx.ctx), Z3.Expr[])
end

function z3_false_literal(ctx :: ASTZ3Context)
    return Z3ExprContainer(Z3.BoolVal(false, ctx.ctx.ctx), Z3.Expr[])
end

function z3_real_literal(ctx :: ASTZ3Context, r :: T) where {T <: Real}
    r = rationalize(Int32, r)
    return Z3ExprContainer(Z3Helper.RealVal(r, ctx.ctx.ctx), Z3.Expr[])
end

function z3_add(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr + f2.expr, Z3.Expr[f1.additional;f2.additional])
end

function z3_mul(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr * f2.expr, Z3.Expr[f1.additional;f2.additional])
end

function z3_sub(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr - f2.expr, Z3.Expr[f1.additional;f2.additional])
end

function z3_div(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr / f2.expr, Z3.Expr[f1.additional;f2.additional])
end

function z3_power(ctx :: ASTZ3Context, base :: Z3ExprContainer, exp :: Z3ExprContainer)
    #return f1 ^ f2
    # Careful! This only works because z3_real_literal has no side constraints...
    denExp = Z3.Z3_get_denominator(ctx.ctx.ctx.ctx,Z3.as_ast(exp.expr))
    den = Z3.Z3_get_numeral_double(ctx.ctx.ctx.ctx,denExp)
    denExp = z3_real_literal(ctx, den).expr
	if isone(den)
		return Z3ExprContainer((base.expr)^(exp.expr), Z3.Expr[base.additional;exp.additional])
	else
        global VAR_COUNTER+=1
        helper = RealVar("h$VAR_COUNTER", ctx.ctx.ctx)
        additional = Z3.Expr[base.additional;exp.additional]
        if convert(Int,den) % 2 == 0
            push!(
                additional,
                Z3.And(Z3.Expr[
                    Z3Helper.is_eq(helper^denExp, base.expr),
                    (z3_real_literal(ctx,0).expr <= helper)
                ])
            )
        else
            push!(
                additional,
                Z3Helper.is_eq(helper^denExp, base.expr)
            )
        end
        numExp = Z3.Z3_get_numerator(ctx.ctx.ctx.ctx,Z3.as_ast(exp.expr))
        num = Z3.Z3_get_numeral_double(ctx.ctx.ctx.ctx,numExp)
        numExp = z3_real_literal(ctx, num).expr
        if isone(num)
            return Z3ExprContainer(helper,additional)
        else
            return Z3ExprContainer(helper^numExp,additional)
        end
	end
end

function z3_neg(ctx :: ASTZ3Context, f :: Z3ExprContainer)
    return Z3ExprContainer(-f.expr, f.additional)
end

function z3_eq(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(Z3Helper.is_eq(f1.expr, f2.expr), Z3.Expr[f1.additional;f2.additional])
end

function z3_not_eq(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(Z3Helper.not_eq(f1.expr, f2.expr), Z3.Expr[f1.additional;f2.additional])
end

function z3_lt(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr < f2.expr, Z3.Expr[f1.additional;f2.additional])
end

function z3_leq(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr <= f2.expr, Z3.Expr[f1.additional;f2.additional])
end

function z3_gt(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr > f2.expr, Z3ExprContainer[f1.additional;f2.additional])
end

function z3_geq(ctx :: ASTZ3Context, f1 :: Z3ExprContainer, f2 :: Z3ExprContainer)
    return Z3ExprContainer(f1.expr >= f2.expr, Z3ExprContainer[f1.additional;f2.additional])
end

