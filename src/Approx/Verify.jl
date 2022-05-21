function verify_approximation(approx_query :: ApproxQuery, new_approx::Approximation)
	prinln("[APPROX] Verifying correctness of approximation for term ", approx_query.term)
	num_vars = length(new_approx.bounds)
	for b in bounds_iterator(new_approx.bounds)
		linear_term = get_linear_term(b, new_approx)
		smt_context(num_vars;timeout=0) do (ctx, variables)
			constraints = Formula[]
			# Variable bounds
			for (i,(blow,bhigh)) in enumerate(b)
				c = zeros(Rational{BigInt}, num_vars)
				c[i] = 1
				push!(
					constraints,
					LinearConstraint(c,bhigh,true)
				)
				c = zeros(Rational{BigInt}, num_vars)
				c[i] = -1
				push!(
					constraints,
					LinearConstraint(c,-blow,true)
				)
			end
			# Search for opposite of what bound is supposed to be
			# Lower => term < linear_term
			# Upper => term > linear_term
			operator = AST.Less
			if approx_query.bound == AST.Upper
				operator = AST.Greater
			end
			push!(
				constraints,
				Atom(operator,approx_query.term,linear_term)
			)
			if SMTInterface.nl_feasible(constraints, ctx, variables)
				@error "Found error in approximation of "*AST.term_to_string(approx_query.term)*": Linear Term "*AST.term_to_string(linear_term)*" may be below/above allowed threshold in interval "*string(b)
			end
		end
	end
end