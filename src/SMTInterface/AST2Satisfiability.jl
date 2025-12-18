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
	
	coeff = map(c -> ast2smt(TermNumber(c), variables, additional, smt_cache), f.coefficients)
	bias = ast2smt(TermNumber(f.bias), variables, additional, smt_cache)
	n = length(coeff) # variables may have more entries than coefficients (input constraints)

	lincomb = sum(coeff .* variables[1:n])
	res = f.equality ? lincomb ≤ bias : lincomb < bias
	
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
	
	coeff = map(c -> ast2smt(TermNumber(c), variables, additional, smt_cache), t.coefficients)
	bias = ast2smt(TermNumber(t.bias), variables, additional, smt_cache)
	n = length(coeff) # variables may have more entries than coefficients (input constraints)
	
	lincomb = sum(coeff .* variables[1:n])
	res = lincomb + bias

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


function smt_pow(base, exp, variables=[], additional=[], smt_cache=Dict())
	@assert isa(exp, TermNumber) "Exponent must be a TermNumber."
	@assert isa(base, TermNumber) || isa(base, Variable) "Base must be a TermNumber, Variable."
	
	num = exp.value.num
	den = exp.value.den

	if den == 1
		if isa(base, TermNumber)
			return ast2smt(base^exp, variables, additional, smt_cache)
		else
			var = ast2smt(base, variables, additional, smt_cache)
			if num > 0
				# xⁿ = x ⋅ x ⋯ x
				return foldl(*, fill(var, num))
			elseif num < 0
				# x⁻ⁿ = 1 / (x ⋅ x ⋯ x)
				return 1.0 / foldl(*, fill(var, -num))
			else
				return 1.0
			end		
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
		res = smt_pow(f.args..., variables, additional, smt_cache)
	end
	
	smt_cache[f] = res
	return res
end
function ast2smt(v :: Variable, variables, additional, smt_cache)
	return variables[v.position]
end
function ast2smt(n :: TermNumber, variables, additional, smt_cache)
	#return Satisfiability.__wrap_const(Float64(n.value))
	return Float64(n.value)
	# TODO: Better way?
	#x = convert(BigFloat, n.value)
	#@show x
	#y = rationalize(Int64, x)
	#@show y
	#@show Satisfiability.__wrap_const(numerator(y)), Satisfiability.__wrap_const(denominator(y))
	#@show Satisfiability.__wrap_const(numerator(y)) / Satisfiability.__wrap_const(denominator(y))
	return Satisfiability.__wrap_const(numerator(y)) / Satisfiability.__wrap_const(denominator(y))
end
