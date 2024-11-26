function ast2smt(
    f :: ParsedNode,
    ast_context,
    solver :: SMTSolver)
    if solver.is_cached(ast_context, f)
        return solver.get_cached(ast_context, f)
    end
    res = ast2smt_internal(f, ast_context, solver)
    solver.cache(ast_context, f, res)
    return res
end

function ast2smt_internal(
    f :: CompositeFormula,
    ast_context,
    solver :: SMTSolver)
    arguments = map(x -> ast2smt(x, ast_context, solver), f.args)
    return @match f.connective begin
        Not => begin
            @assert length(arguments) == 1
            return solver.opset.not(ast_context, arguments[1])
        end
        And => solver.opset.and(ast_context, arguments)
        Or => solver.opset.or(ast_context, arguments)
        Implies => begin
            @assert length(arguments) == 2
            return solver.opset.implies(ast_context, arguments[1], arguments[2])
        end
        ITE => begin
            @assert length(arguments) == 3
            return solver.opset.ite(ast_context, arguments[1], arguments[2], arguments[3])
        end
    end
end

function ast2smt_internal(
    f :: TrueAtom,
    ast_context,
    solver :: SMTSolver)
    return solver.opset.true_literal(ast_context)
end

function ast2smt_internal(
    f :: FalseAtom,
    ast_context,
    solver :: SMTSolver)
    return solver.opset.false_literal(ast_context)
end

function ast2smt_internal_linear(
    coefficients :: Array{Rational{BigInt}},
    ast_context,
    solver :: SMTSolver)
    formula = solver.opset.real_literal(ast_context, zero(Rational{BigInt}))
    for (i,c) in enumerate(coefficients)
        formula = solver.opset.add(
            ast_context,
            formula,
            solver.opset.mul(
                ast_context,
                solver.opset.real_literal(ast_context, c),
                solver.get_variable(ast_context, i)
            )
        )
    end
    return formula
end

function ast2smt_internal(
    f :: LinearConstraint,
    ast_context,
    solver :: SMTSolver)
    formula = ast2smt_internal_linear(f.coefficients, ast_context, solver)
    if f.equality
        return solver.opset.leq(
            ast_context,
            formula,
            solver.opset.real_literal(ast_context, f.bias)
        )
    else
        return solver.opset.lt(
            ast_context,
            formula,
            solver.opset.real_literal(ast_context, f.bias)
        )
    end
end

function ast2smt_internal(
    f :: LinearTerm,
    ast_context,
    solver :: SMTSolver)
    return solver.add(
        ast2smt_internal_linear(f.coefficients, ast_context, solver),
        solver.opset.real_literal(ast_context, f.bias)
    )
end

function ast2smt_internal(
    f :: ApproxNode,
    ast_context,
    solver :: SMTSolver)
    return ast2smt(f.formula, ast_context, solver)
end

function ast2smt_internal(
    f :: Atom,
    ast_context,
    solver :: SMTSolver)
    termLeft = ast2smt(f.left, ast_context, solver)
    termRight = ast2smt(f.right, ast_context, solver)
    return @match f.comparator begin
        Eq => solver.opset.eq(ast_context, termLeft, termRight)
        Neq => solver.opset.neq(ast_context, termLeft, termRight)
        Less => solver.opset.lt(ast_context, termLeft, termRight)
        LessEq => solver.opset.leq(ast_context, termLeft, termRight)
        Greater => solver.opset.gt(ast_context, termLeft, termRight)
        GreaterEq => solver.opset.geq(ast_context, termLeft, termRight)
    end
end

function ast2smt_internal(
    f :: CompositeTerm,
    ast_context,
    solver :: SMTSolver)
    arguments = map(x -> ast2smt(x, ast_context, solver), f.args)
    return @match f.operation begin
        Add => begin
            res = arguments[1]
            for cur_arg in arguments[2:end]
                res = solver.opset.add(ast_context, res, cur_arg)
            end
            return res
        end
        Sub => begin
            res = arguments[1]
            for cur_arg in arguments[2:end]
                res = solver.opset.sub(ast_context, res, cur_arg)
            end
            return res
        end
        Mul => begin
            res = arguments[1]
            for cur_arg in arguments[2:end]
                res = solver.opset.mul(ast_context, res, cur_arg)
            end
            return res
        end
        Div => begin
            @assert length(arguments) == 2
            return solver.opset.div(ast_context, arguments[1], arguments[2])
        end
        Pow => begin
            @assert length(arguments) == 2
            return solver.opset.power(ast_context, arguments[1], arguments[2])
        end
        Neg => begin
            @assert length(arguments) == 1
            return solver.opset.neg(ast_context, arguments[1])
        end
        _  => begin
            throw("Unknown SMT Operation "*string(f))
        end
    end
end

function ast2smt_internal(
    f::Variable,
    ast_context,
    solver :: SMTSolver)
    return solver.get_variable(ast_context, f.position)
end

function ast2smt_internal(
    f::TermNumber,
    ast_context,
    solver :: SMTSolver)
    return solver.opset.real_literal(ast_context, f.value)
end