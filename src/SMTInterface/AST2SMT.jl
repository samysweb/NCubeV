"""
AST-to-SMT translation utilities
--------------------------------

Translate NCubeV AST nodes to solver-native expressions used by SMT backends.
The functions here are solver-agnostic and produce intermediate `Formula`
structures ready to be consumed by backend-specific translators (e.g., Z3 in
`SMTInterface/Z3/AST2Z3.jl`).

Key responsibilities:
- Construct input/output box constraints from `NormalizedQuery`
- Flatten piecewise-linear conjunctions (`PwlConjunction`) into AND terms
- Convert semi-linear constraints to linear atoms

See also:
- `SMTInterface.StarFilter` for counterexample filtering logic (Lemma 12)
- `SMTInterface.Z3.AST2Z3` for backend-specific lowering
"""
function ast2smt(q :: NormalizedQuery, variables, additional)
	conjunction = Formula[]
	num_inputs = length(q.input_bounds)
	num_outputs = length(q.output_bounds)
	for (i,b) in enumerate(q.input_bounds)
		push!(conjunction, Atom(LessEq, b[1], Variable("x"*string(i),nothing,i)))
		push!(conjunction, Atom(LessEq, Variable("x"*string(i),nothing,i), b[end]))
	end
	for (i,b) in enumerate(q.output_bounds)
		push!(conjunction, Atom(LessEq,b[1], Variable("x"*string(num_inputs + i),nothing,num_inputs + i)))
		push!(conjunction, Atom(LessEq, Variable("x"*string(num_inputs + i),nothing,num_inputs + i), b[end]))
	end
	encoded_input =pwl2term(q.input_constraints)
	if !isnothing(encoded_input)
		push!(conjunction, encoded_input)
	end
	disjuntion = Formula[]
	for c in q.mixed_constraints
		push!(disjuntion, pwl2term(c))
	end
	if length(disjuntion) > 1
		push!(conjunction, CompositeFormula(Or,disjuntion))
	else
		push!(conjunction, disjuntion[1])
	end
	if length(conjunction)==1
		return ast2smt(conjunction[1], variables, additional)
	else
		return ast2smt(CompositeFormula(And,conjunction), variables, additional)
	end
end

"""
	pwl2term(pwl::PwlConjunction) -> Union{Formula,Nothing}

Flatten a piecewise-linear conjunction into a single formula by combining
variable bounds, linear constraints, and semi-linear constraints as an AND.
Returns `nothing` if the conjunction is empty.
"""
function pwl2term(pwl :: PwlConjunction)
	conjunction = Formula[]
	for (i,b) in enumerate(pwl.bounds)
		if length(b) < 2
			# Skip if no bounds available
			continue
		end
		push!(conjunction, Atom(LessEq,b[1], Variable("x"*string(i),nothing,i)))
		push!(conjunction, Atom(LessEq,Variable("x"*string(i),nothing,i), b[end]))
	end
	for c in pwl.linear_constraints
		push!(conjunction, c)
	end
	for c in pwl.semilinear_constraints
		push!(conjunction, c)
	end
	if length(conjunction) > 1
		return CompositeFormula(And,conjunction)
	elseif length(conjunction)==1
		return conjunction[1]
	else
		return nothing
	end
end

"""
	ast2smt(semi::SemiLinearConstraint, variables, additional)

Convert a semi-linear constraint (linear part plus weighted approx queries)
to an SMT atom by substituting the semi-linear components into the
left-hand side term and creating a strict/weak inequality depending on
`semi.equality`.

Notes:
- Coefficients are rationalized to improve solver stability.
"""
function ast2smt(semi :: SemiLinearConstraint, variables, additional)
	term = TermNumber(0.0)
	for (i,c) in enumerate(semi.coefficients)
		term = CompositeTerm(Add, Term[term, rationalize(Int32,BigFloat(c)) * Variable("x"*string(i),nothing,i)])
	end
	for (approx_query, coeff) in semi.semilinears
		term = CompositeTerm(Add, Term[term, rationalize(Int32,BigFloat(coeff)) * approx_query.term])
	end
	if semi.equality
		return ast2smt(Atom(LessEq, term, rationalize(Int32,BigFloat(semi.bias))), variables, additional)
	else
		return ast2smt(Atom(Less, term, rationalize(Int32,BigFloat(semi.bias))), variables, additional)
	end
end