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
	@satvariable(t, Bool)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
    res = Sat.__wrap_const(true)
	smt_cache[f] = res
	return res
end
function ast2smt(f :: FalseAtom, variables, additional, smt_cache)
	@satvariable(t, Bool)
	if haskey(smt_cache, f)
		return smt_cache[f]
	end
    res = Sat.__wrap_const(false)
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
	for c in coeff
		if isa(c, Sat.NumericExpr)
			c = c.value
		end
	end
	
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


function smt_pow(arguments)
	@assert length(arguments) == 2
	if arguments[2] isa IntExpr
		exp = Rational{BigInt}(arguments[2].value)
	else
		exp = Rational{BigInt}(arguments[2])
	end
	base = arguments[1]
	if exp.den == 1
		if exp.num > 0
			# xⁿ = x ⋅ x ⋯ x
			return foldl(*, fill(base, exp.num))
		elseif exp.num < 0
			# x⁻ⁿ = 1 / (x ⋅ x ⋯ x)
			return 1.0 / foldl(*, fill(base, -exp.num))
		else
			return 1.0
		end
	else
		@assert False, "Non-integer exponents not supported in SMT backend yet."
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
	arguments = map(x -> ast2smt(x, variables, additional, smt_cache), f.args)
	res = @match f.operation begin
		Add => +(arguments...)
		Sub => -(arguments...)
		Mul => *(arguments...)
		Div => /(arguments...)
		Pow => smt_pow(arguments)
		Neg => return -arguments[1]
	end
	smt_cache[f] = res
	return res
end
function ast2smt(v :: Variable, variables, additional, smt_cache)
	return variables[v.position]
end
function secure_int(val::Integer, zero_var)
    LIMIT = 1000000 
    if abs(val) < LIMIT
        return Int64(val)
    end
    CUTOFF = 100000 
    lower = Int64(rem(val, CUTOFF))
    upper = Int64(div(val, CUTOFF))
	#@show val, upper, lower
	secure_upper = secure_int(upper, zero_var)
	return (secure_upper * (CUTOFF + zero_var)) + lower
end

function ast2smt(n::TermNumber, variables, additional, smt_cache) 
	x_rat = n.value
	num = numerator(x_rat)
    den = denominator(x_rat)
	#@show x_rat
	@satvariable(t_zero, Real)
    if !any(c -> isequal(c, (t_zero == 0.0)), additional)
        push!(additional, t_zero == 0.0)
    end
    
	if den == 1
        return Sat.__wrap_const(secure_int(num, t_zero))
    end

	#@show num, den
	num = secure_int(num, t_zero)
    den = secure_int(den, t_zero)

	@satvariable(t_one, Real)
    if !any(c -> isequal(c, (t_one == 1.0)), additional)
        push!(additional, t_one == 1.0)
    end
    return num / den * t_one
end