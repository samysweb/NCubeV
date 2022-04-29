function init_pwl_bounds(conjunction :: PwlConjunction, approximations :: Dict{ApproxQuery, Approximation})
	num_vars = length(conjunction.bounds)
	for semilinear in conjunction.semilinear_constraints
		for (approx_query,_) in semilinear.semilinears
			additional_bounds = approximations[approx_query].bounds
			for i in 1:num_vars
				conjunction.bounds[i] = union(conjunction.bounds[i], additional_bounds[i])
			end
		end
	end
	for i in 1: num_vars
		sort!(conjunction.bounds[i])
		conjunction.bounds[i] = filter_single_bound(conjunction.bounds[i])
	end
end