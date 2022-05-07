# TODO(steuber): Floating Point Correctness?
function ast2z3(f :: CompositeFormula, variables)
	arguments = map(x -> ast2z3(x, variables), f.args)
	return @match f.connective begin
		Not => return Z3.not(arguments[1])
		And => return Z3.and(arguments...)
		Or => return Z3.or(arguments...)
		Implies => return Z3.implies(arguments[1],arguments[2])
	end
end
#TODO(steuber): FLOAT INCORRECTNESS
function ast2z3(f :: LinearConstraint, variables)
	formula = 0.0
	for (i,c) in enumerate(f.coefficients)
		formula = formula + Float32(c) * variables[i]
	end
	if f.equality
		return formula <= Float32(f.bias)
	else
		return formula < Float32(f.bias)
	end
end

function ast2z3(t :: LinearTerm, variables)
	term = rationalize(Int32,BigFloat(t.bias))
	for (i,c) in enumerate(t.coefficients)
		term = term + rationalize(Int32,BigFloat(c)) * variables[i]
	end
	return term
end

function ast2z3(f :: ApproxNode, variables)
	return ast2z3(f.formula, variables)
end
function ast2z3(f :: Atom, variables)
	termLeft = ast2z3(f.left, variables)
	termRight = ast2z3(f.right, variables)
	return @match f.comparator begin
		Less => return termLeft < termRight
		LessEq => return termLeft <= termRight
		Greater => return termLeft > termRight
		GreaterEq => return termLeft >= termRight
		Eq => return termLeft == termRight
		Neq => return termLeft != termRight
	end
end
function ast2z3(f :: CompositeTerm, variables)
	arguments = map(x -> ast2z3(x, variables), f.args)
	return @match f.operation begin
		Add => return +(arguments...)
		Sub => return -(arguments...)
		Mul => return *(arguments...)
		Div => return /(arguments...)
		Pow => return ^(arguments...)
		Neg => return -arguments[1]
	end
end
function ast2z3(v :: Variable, variables)
	return variables[v.position]
end
function ast2z3(n :: TermNumber, variables)
	#value32 = Float32(n.value)
	#return rationalize(value32)
	return Float32(n.value)
end