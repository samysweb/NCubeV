# TODO(steuber): Floating Point Correctness?
function ast2smt(f :: CompositeFormula, variables, additional)
	arguments = map(x -> ast2smt(x, variables, additional), f.args)
	return @match f.connective begin
		Not => return PY_DREAL.Not(arguments[1])
		And => return PY_DREAL.And(arguments...)
		Or => return PY_DREAL.Or(arguments...)
		Implies => return PY_DREAL.Implies(arguments[1],arguments[2])
	end
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
		Eq => return termLeft.__eq__(termRight)
		Neq => return termLeft.__ne__(termRight)
	end
end
function ast2smt(f :: CompositeTerm, variables, additional)
	arguments = map(x -> ast2smt(x, variables, additional), f.args)
	ctx = variables[1].ctx
	return @match f.operation begin
		Add => return foldl(+,arguments)
		Sub => return foldl(+,arguments)
		Mul => return foldl(*,arguments)
		Div => return foldl(/,arguments)
		Pow => begin
			@assert length(arguments) == 2
			exp = arguments[2].as_fraction()
			if exp.denominator == 1
				return foldl(^,arguments)
			else
				exp = 1/exp
				@assert exp.denominator == 1
				new_var = smt_internal_variable((nothing,ctx), "pow"*string(hash(f)))
				push!(additional, PY_DREAL.And(
					new_var^exp.__eq__(arguments[1]),
					0 <= new_var
				))
				return new_var
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
	num =  rationalize(Int32,Float32(n.value))
	return num
end