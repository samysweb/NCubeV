# TODO(steuber): Floating Point Correctness?
function ast2smt(f :: CompositeFormula, variables, additional)
	arguments = map(x -> ast2smt(x, variables, additional), f.args)
	return @match f.connective begin
		Not => return Z3.not(arguments[1])
		And => return Z3.and(arguments...)
		Or => return Z3.or(arguments...)
		Implies => return Z3.implies(arguments[1],arguments[2])
		ITE => return Z3.ite(arguments[1],arguments[2],arguments[3])
	end
end
function ast2smt(f :: TrueAtom, variables, additional)
	ctx = Z3.ctx(variables[1])
	return Z3.bool_val(ctx, true)
end
function ast2smt(f :: FalseAtom, variables, additional)
	ctx = Z3.ctx(variables[1])
	return Z3.bool_val(ctx, false)
end
#TODO(steuber): FLOAT INCORRECTNESS
function ast2smt(f :: LinearConstraint, variables, additional)
	formula = 0.0
	for (i,c) in enumerate(f.coefficients)
		formula = formula + rationalize(Int32,Float32(c)) * variables[i]
	end
	if f.equality
		return formula <= rationalize(Int32,Float32(f.bias))
	else
		return formula < rationalize(Int32,Float32(f.bias))
	end
end

function ast2smt(t :: LinearTerm, variables, additional)
	term = rationalize(Int32,BigFloat(t.bias))
	for (i,c) in enumerate(t.coefficients)
		term = term + rationalize(Int32,BigFloat(c)) * variables[i]
	end
	return term
end

function ast2smt(f :: ApproxNode, variables, additional)
	return ast2smt(f.formula, variables, additional)
end
function ast2smt(f :: Atom, variables, additional)
	termLeft = ast2smt(f.left, variables, additional)
	termRight = ast2smt(f.right, variables, additional)
	return @match f.comparator begin
		Less => return termLeft < termRight
		LessEq => return termLeft <= termRight
		Greater => return termLeft > termRight
		GreaterEq => return termLeft >= termRight
		Eq => return termLeft == termRight
		Neq => return termLeft != termRight
	end
end
function ast2smt(f :: CompositeTerm, variables, additional)
	arguments = map(x -> ast2smt(x, variables, additional), f.args)
	ctx = Z3.ctx(variables[1])
	return @match f.operation begin
		Add => return +(arguments...)
		Sub => return -(arguments...)
		Mul => return *(arguments...)
		Div => return /(arguments...)
		Pow => begin
			@assert length(arguments) == 2
			exp = arguments[2]
			if exp.den == 1
				return ^(arguments...)
			else
				exp = 1//exp
				@assert exp.den == 1
				result = Z3.ite(arguments[1]>=0, ^(arguments[1], exp), real_val(ctx,0))
				return result
			end
		end
		Neg => return -arguments[1]
	end
end
function ast2smt(v :: Variable, variables, additional)
	return variables[v.position]
end
function ast2smt(n :: TermNumber, variables, additional)
	#value32 = Float32(n.value)
	#return rationalize(value32)
	return rationalize(Int32,Float32(n.value))
end
