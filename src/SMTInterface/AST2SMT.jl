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
	println("Translating NormalizedQuery to SMT formula...")
	num_inputs = length(q.input_bounds)
	num_outputs = length(q.output_bounds)	

	input_vars = variables[1:num_inputs]
	output_vars = variables[num_inputs .+ (1:num_outputs)]
	
	input_lb = [b[1] for b in q.input_bounds]
	input_ub = [b[end] for b in q.input_bounds]
	input_bounds = Sat.and(input_lb .<= input_vars) ∧ Sat.and(input_vars .<= input_ub)
	
	output_lb = [b[1] for b in q.output_bounds]
	output_ub = [b[end] for b in q.output_bounds]
	output_bounds = Sat.and(output_lb .<= output_vars) ∧ Sat.and(output_vars .<= output_ub)

	expr = 	
		input_bounds ∧ 
		output_bounds ∧ 
		pwl2term(q.input_constraints, variables, additional) ∧
		Sat.or([pwl2term(c, variables, additional) for c in q.mixed_constraints])

	return expr

end

"""
	pwl2term(pwl::PwlConjunction) -> Union{Formula,Nothing}

Flatten a piecewise-linear conjunction into a single formula by combining
variable bounds, linear constraints, and semi-linear constraints as an AND.
Returns `nothing` if the conjunction is empty.
"""
function pwl2term(pwl :: PwlConjunction, variables, additional)
println("Translating PwlConjunction to SMT term...")
	bounds = Sat.and([(b[1] <= variables[i]) ∧ (variables[i] <= b[end]) 
				for (i,b) in enumerate(pwl.bounds) if length(b) >= 2])
	
	linear_constraints =
    	Sat.and(((lc) -> ast2smt(lc, variables, additional)).(pwl.linear_constraints))

	semilinear_constraints =
    	Sat.and(((sc) -> ast2smt(sc, variables, additional)).(pwl.semilinear_constraints))

	expr = bounds ∧ linear_constraints ∧ semilinear_constraints 
	return expr
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
function ast2smt(semi :: SemiLinearConstraint, variables, additional, smt_cache=Dict())
	println("Translating SemiLinearConstraint to SMT...")
	coeff = map(c -> Float64(c), semi.coefficients)	
	bias = Float64(semi.bias)
	n = length(coeff) # variables may have more entries than coefficients (input constraints)

	term1 = coeff .* variables
	term2 = [Float64(c) * ast2smt(approx_query.term, variables, additional, smt_cache) 
		for (approx_query, c) in semi.semilinears]
		
	return semi.equality ? sum(term1) + sum(term2) ≤ bias :
		sum(term1) + sum(term2) < bias
end