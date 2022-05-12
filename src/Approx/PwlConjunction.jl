function init_pwl_bounds(conjunction :: PwlConjunction, approximations :: Dict{ApproxQuery, Approximation}, init_bounds :: Vector{Vector{Float64}})
	num_vars = length(conjunction.bounds)
	if length(conjunction.semilinear_constraints) == 0
		for i in 1:num_vars
			conjunction.bounds[i] = union(conjunction.bounds[i], [init_bounds[i][1], init_bounds[i][end]])
		end
	else
		for semilinear in conjunction.semilinear_constraints
			for (approx_query,_) in semilinear.semilinears
				additional_bounds = approximations[approx_query].bounds
				for i in 1:num_vars
					conjunction.bounds[i] = union(conjunction.bounds[i], additional_bounds[i])
				end
			end
		end
	end
	for i in 1: num_vars
		sort!(conjunction.bounds[i])
		conjunction.bounds[i] = filter_single_bound(conjunction.bounds[i])
	end
end