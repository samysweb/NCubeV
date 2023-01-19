# TODO(steuber): Floating Point Correctness?
function ast2smt(f :: CompositeFormula, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	arguments = map(x -> ast2smt(x, variables, additional, smt_cache), f.args)
	res = @match f.connective begin
		Not => Z3.not(arguments[1])
		And => Z3.and(arguments...)
		Or => Z3.or(arguments...)
		Implies => Z3.implies(arguments[1],arguments[2])
		ITE => Z3.ite(arguments[1],arguments[2],arguments[3])
	end
	smt_cache[f] = res
	return res
end
function ast2smt(f :: TrueAtom, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	ctx = Z3.ctx(variables[1])
	res = Z3.bool_val(ctx, true)
	smt_cache[f] = res
	return res
end
function ast2smt(f :: FalseAtom, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	ctx = Z3.ctx(variables[1])
	res = Z3.bool_val(ctx, false)
	smt_cache[f] = res
	return res
end
#TODO(steuber): FLOAT INCORRECTNESS
function ast2smt(f :: LinearConstraint, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	formula = 0.0
	for (i,c) in enumerate(f.coefficients)
		formula = formula + rationalize(Int32,Float32(c)) * variables[i]
	end
	if f.equality
		res = formula <= rationalize(Int32,Float32(f.bias))
		smt_cache[f] = res
		return res
	else
		res = formula < rationalize(Int32,Float32(f.bias))
		smt_cache[f] = res
		return res
	end
end

function ast2smt(t :: LinearTerm, variables, additional, smt_cache)
	if haskey(smt_cache, t)
		return smt_cache[t]
	end
	term = rationalize(Int32,BigFloat(t.bias))
	for (i,c) in enumerate(t.coefficients)
		term = term + rationalize(Int32,BigFloat(c)) * variables[i]
	end
	res = term
	smt_cache[t] = res
	return res
end

function ast2smt(f :: ApproxNode, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	res = ast2smt(f.formula, variables, additional, smt_cache)
	smt_cache[f] = res
	return res
end
function ast2smt(f :: Atom, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	termLeft = ast2smt(f.left, variables, additional, smt_cache)
	termRight = ast2smt(f.right, variables, additional, smt_cache)
	res = @match f.comparator begin
		Less => termLeft < termRight
		LessEq => termLeft <= termRight
		Greater => termLeft > termRight
		GreaterEq => termLeft >= termRight
		Eq => termLeft == termRight
		Neq => termLeft != termRight
	end
	smt_cache[f] = res
	return res
end
function smt_pow(ctx, arguments)
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
function ast2smt(f :: CompositeTerm, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	arguments = map(x -> ast2smt(x, variables, additional, smt_cache), f.args)
	ctx = Z3.ctx(variables[1])
	res = @match f.operation begin
		Add => +(arguments...)
		Sub => -(arguments...)
		Mul => *(arguments...)
		Div => /(arguments...)
		Pow => smt_pow(ctx, arguments)
		Neg => return -arguments[1]
	end
	smt_cache[f] = res
	return res
end
function ast2smt(v :: Variable, variables, additional, smt_cache)
	return variables[v.position]
end
function ast2smt(n :: TermNumber, variables, additional, smt_cache)
	#value32 = Float32(n.value)
	#return rationalize(value32)
	return rationalize(Int32,Float32(n.value))
end
