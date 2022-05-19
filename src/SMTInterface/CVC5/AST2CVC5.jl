# TODO(steuber): Floating Point Correctness?
function ast2smt(f :: CompositeFormula, variables, additional)
	arguments = map(x -> ast2smt(x, variables, additional), f.args)
	return @match f.connective begin
		Not => return PY_CVC5.Not(arguments[1])
		And => return PY_CVC5.And(arguments...)
		Or => return PY_CVC5.Or(arguments...)
		Implies => return PY_CVC5.Implies(arguments[1],arguments[2])
	end
end
#TODO(steuber): FLOAT INCORRECTNESS
function ast2smt(f :: LinearConstraint, variables, additional)
	formula = 0.0
	for (i,c) in enumerate(f.coefficients)
		formula = PY_CVC5.Add(formula, PY_CVC5.Mult(rationalize(Int32,Float32(c)), variables[i]))
	end
	if f.equality
		return PY_CVC5.Leq(formula, rationalize(Int32,Float32(f.bias)))
	else
		return PY_CVC5.Lt(formula, rationalize(Int32,Float32(f.bias)))
	end
end

function ast2smt(t :: LinearTerm, variables, additional)
	term = rationalize(Int32,BigFloat(t.bias))
	for (i,c) in enumerate(t.coefficients)
		term = PY_CVC5.Add(term, PY_CVC5.Mult(rationalize(Int32,BigFloat(c)), variables[i]))
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
		Less => return PY_CVC5.Lt(termLeft, termRight)
		LessEq => return PY_CVC5.Leq(termLeft, termRight)
		Greater => return PY_CVC5.Gt(termLeft, termRight)
		GreaterEq => return PY_CVC5.Geq(termLeft, termRight)
		Eq => return termLeft.__eq__(termRight)
		Neq => return termLeft.__ne__(termRight)
	end
end
function ast2smt(f :: CompositeTerm, variables, additional)
	arguments = map(x -> ast2smt(x, variables, additional), f.args)
	ctx = variables[1].ctx
	return @match f.operation begin
		Add => return PY_CVC5.Add(arguments...)
		Sub => return PY_CVC5.Sub(arguments...)
		Mul => return PY_CVC5.Mult(arguments...)
		Div => return PY_CVC5.Div(arguments...)
		Pow => begin
			@assert length(arguments) == 2
			exp = arguments[2].as_fraction()
			if exp.denominator == 1
				return PY_CVC5.Pow(arguments...)
			else
				exp = 1/exp
				@assert exp.denominator == 1
				new_var = smt_internal_variable((nothing,ctx), "pow"*string(hash(f)))
				push!(additional, PY_CVC5.And(
					PY_CVC5.Pow(new_var, exp).__eq__(arguments[1]),
					PY_CVC5.Leq(0, new_var),
					PY_CVC5.Leq(0, arguments[1])
				))
				return new_var
			end
		end
		Neg => return PY_CVC5.Neg(arguments[1])
	end
end
function ast2smt(v :: Variable, variables, additional)
	return variables[v.position]
end
function ast2smt(n :: TermNumber, variables, additional)
	#value32 = Float32(n.value)
	#return rationalize(value32)
	num =  rationalize(Int32,Float32(n.value))
	return PY_CVC5.RealVal(string(numerator(num))*"/"*string(denominator(num)),ctx=variables[1].ctx)
end