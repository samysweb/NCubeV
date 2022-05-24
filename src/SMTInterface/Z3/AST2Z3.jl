# TODO(steuber): Floating Point Correctness?
function ast2smt(f :: CompositeFormula, variables, additional)
	arguments = map(x -> ast2smt(x, variables, additional), f.args)
	return @match f.connective begin
		Not => return Z3.not(arguments[1])
		And => return Z3.and(arguments...)
		Or => return Z3.or(arguments...)
		Implies => return Z3.implies(arguments[1],arguments[2])
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
				new_var = smt_internal_variable(ctx, "pow"*string(hash(f)))
				push!(additional, Z3.and(
					^(new_var, exp) == (arguments[1]),
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
	return rationalize(Int32,Float32(n.value))
end
function ast2smt(q :: NormalizedQuery, variables, additional)
	conjunction = []
	num_inputs = length(q.input_bounds)
	num_outputs = length(q.output_bounds)
	for (i,b) in enumerate(q.input_bounds)
		push!(conjunction, b[1] <= variables[i])
		push!(conjunction, variables[i] <= b[end])
	end
	for (i,b) in enumerate(q.output_bounds)
		push!(conjunction, b[1] <= variables[num_inputs + i])
		push!(conjunction, variables[num_inputs + i] <= b[end])
	end
	push!(conjunction, ast2smt(q.input_constraints, variables, additional))
	disjuntion = []
	for c in q.mixed_constraints
		push!(disjuntion, ast2smt(c, variables, additional))
	end
	if length(disjuntion) > 1
		push!(conjunction, Z3.or(disjuntion...))
	else
		push!(conjunction, disjuntion[1])
	end
	return Z3.and(conjunction...)
end

function ast2smt(pwl :: PwlConjunction, variables, additional)
	conjunction = []
	for (i,b) in enumerate(pwl.bounds)
		if length(b) < 2
			# Skip if no bounds available
			continue
		end
		push!(conjunction, b[1] <= variables[i])
		push!(conjunction, variables[i] <= b[end])
	end
	for c in pwl.linear_constraints
		push!(conjunction, ast2smt(c, variables, additional))
	end
	for c in pwl.semilinear_constraints
		push!(conjunction, ast2smt(c, variables, additional))
	end
	return Z3.and(conjunction...)
end

function ast2smt(semi :: SemiLinearConstraint, variables, additional)
	term = 0.0
	for (i,c) in enumerate(semi.coefficients)
		term = term + rationalize(Int32,BigFloat(c)) * variables[i]
	end
	for (approx_query, coeff) in semi.semilinears
		term = term + rationalize(Int32,BigFloat(coeff)) * ast2smt(approx_query.term, variables, additional)
	end
	if semi.equality
		return term <= rationalize(Int32,BigFloat(semi.bias))
	else
		return term < rationalize(Int32,BigFloat(semi.bias))
	end
end