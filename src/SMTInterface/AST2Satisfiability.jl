using Satisfiability
Sat = Satisfiability

# TODO(steuber): Floating Point Correctness?
function ast2smt(f :: CompositeFormula, variables, additional, smt_cache=Dict())
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	arguments = map(x -> ast2smt(x, variables, additional, smt_cache), f.args)
	res = @match f.connective begin
		Not => Sat.not(arguments[1])
		And => Sat.and(arguments...)
		Or => Sat.or(arguments...)
		Implies => Sat.implies(arguments[1],arguments[2])
		ITE => Sat.ite(arguments[1],arguments[2],arguments[3])
	end

	smt_cache[f] = res
	return res
end
function ast2smt(f :: TrueAtom, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
    res = true
	smt_cache[f] = res
	return res
end
function ast2smt(f :: FalseAtom, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
    res = false
	smt_cache[f] = res
	return res
end
"""
	ast2smt(f::LinearConstraint, variables, additional, smt_cache)

Encode a linear (or weakly linear) constraint `A*x [</<=] b` as a Sat
comparison. Coefficients and bias are rationalized for stability.
"""
#TODO(steuber): FLOAT INCORRECTNESS
function ast2smt(f :: LinearConstraint, variables, additional, smt_cache=Dict())
	
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	
	coeff = map(c -> Float64(c), f.coefficients)
	n = length(coeff) # variables may have more entries than coefficients (input constraints)
	lincomb = sum(coeff .* variables[1:n])
	
	res = f.equality ? lincomb ≤ Float64(f.bias) : lincomb < Float64(f.bias)
	
	smt_cache[f] = res
	return res
end

"""
	ast2smt(t::LinearTerm, variables, additional, smt_cache)

Lower a linear term into a Sat arithmetic expression.
"""
function ast2smt(t :: LinearTerm, variables, additional, smt_cache)
	
	if haskey(smt_cache, t)
		return smt_cache[t]
	end
	
	coeff = map(c -> Float64(c), t.coefficients)
	lincomb = sum(coeff .* variables)

	res = lincomb ≤ Float64(t.bias)
	smt_cache[t] = res
	return res
end

"""
	ast2smt(f::ApproxNode, ...)

Forward translation to the underlying formula carried by an approximation node.
"""
function ast2smt(f :: ApproxNode, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	res = ast2smt(f.formula, variables, additional, smt_cache)
	smt_cache[f] = res
	return res
end
"""
	ast2smt(f::Atom, ...)

Translate atomic comparisons by recursively lowering both sides and applying
the respective Sat comparator.
"""
function ast2smt(f :: Atom, variables, additional, smt_cache=Dict())
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
		Neq => Sat.distinct(termLeft, termRight)
	end
	smt_cache[f] = res
	return res
end


function smt_pow(term, exp)
	if exp.den == 1
		if exp.num > 0
			return foldl(*, fill(term, exp.num))
		elseif exp.num < 0
			return 1.0 / foldl(*, fill(term, -exp.num))
		else
			return 1.0
		end
	else
		@assert false "Non-integer exponents not supported in SMT backend yet."
		# TODO(steuber): Implement roots again (but probably hard for SMT solver anyway...)
	end
end

"""
	ast2smt(f::CompositeTerm, ...)

Handle arithmetic combinations Add/Sub/Mul/Div/Pow/Neg. For non-integer
exponents, guards restrict the domain to non-negative and fall back to 0 otherwise.
"""
function ast2smt(f :: CompositeTerm, variables, additional, smt_cache)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
	if f.operation ≠ Pow
		arguments = map(x -> ast2smt(x, variables, additional, smt_cache), f.args)
		res = @match f.operation begin
			Add => +(arguments...)
			Sub => -(arguments...)
			Mul => *(arguments...)
			Div => /(arguments...)
			Neg => return -arguments[1]
		end
	else
		@assert length(f.args) == 2 "Pow operation requires exactly two arguments."
		term = ast2smt(f.args[1], variables, additional, smt_cache)
		exp = (f.args[2]).value
		res = smt_pow(term, exp)
	end
	
	smt_cache[f] = res
	return res
end
function ast2smt(v :: Variable, variables, additional, smt_cache)
	return variables[v.position]
end
function ast2smt(n :: TermNumber, variables, additional, smt_cache)
	return Float64(n.value)
end
