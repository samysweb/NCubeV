function get_approx_normalized_query(initial_query :: NormalizedQuery)
	@info "Constructing Approximation"
	incomplete_query=IncompleteApproxNormalizedQuery(initial_query)
	@info "Resolving approximation"
	ready_approximations = Dict{ApproxQuery, Approximation}()
	for (approx_query, incomplete_approx) in incomplete_query.approximations
		new_approx = resolve_approximation(incomplete_approx, approx_query.bound)
		ready_approximations[approx_query] = new_approx
	end
	return ApproxNormalizedQuery(incomplete_query, ready_approximations)
end