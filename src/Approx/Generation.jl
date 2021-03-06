function get_approx_normalized_query(initial_query :: NormalizedQuery, approx_cache :: ApproxCache)
	bounds = map(x->(x[1],x[end]), initial_query.input_bounds)
	append!(bounds, map(x->(x[1],x[end]), initial_query.output_bounds))
	ready_approximations = Dict{ApproxQuery, Approximation}()
	print_msg("[APPROX] Checking cache: ",[k for (k,v) in approx_cache])
	for (approx_term,all_bound_types) in initial_query.approx_queries
		cur_bounds = generate_bounds(approx_term, bounds)
		needed_bound_types = []
		for bound_type in all_bound_types
			cache_needle = ApproxCacheObject(ApproxQuery(bound_type, approx_term), cur_bounds)
			if haskey(approx_cache,cache_needle)
				print_msg("[APPROX] Reusing approximation for query: ", cache_needle)
				update_bounds(approx_term, bounds, approx_cache[cache_needle].bounds)
				ready_approximations[cache_needle.query] = approx_cache[cache_needle]
				delete!(initial_query.approx_queries, approx_term)
			else
				print_msg("[APPROX] Not found: ", cache_needle)
				push!(needed_bound_types, bound_type)
			end
		end
		if length(needed_bound_types) == 0
			delete!(initial_query.approx_queries, approx_term)
		else
			initial_query.approx_queries[approx_term] = needed_bound_types
		end
	end
	print_msg("[APPROX] Constructing Approximation")
	incomplete_query=ApproxNormalizedQueryPrototype{IncompleteApproximation}(initial_query)
	print_msg("[APPROX] Resolving approximation")
	for (approx_query, incomplete_approx) in incomplete_query.approximations
		new_approx = resolve_approximation(incomplete_approx, approx_query.bound)
		if Config.RIGOROUS_APPROXIMATIONS
			verify_approximation(approx_query, new_approx)
		else
			print_msg("[APPROX] Skipping verification of approximation (switch on using SNNT.Config.set_rigorous_approximations(true))")
		end
		ready_approximations[approx_query] = new_approx
		cur_bounds = generate_bounds(approx_query.term, bounds)
		cache_needle = ApproxCacheObject(approx_query, cur_bounds)
		approx_cache[cache_needle] = new_approx
	end
	return ApproxNormalizedQueryPrototype{Approximation}(incomplete_query, ready_approximations)
end

function generate_bounds(term :: Term, bounds :: Vector{Tuple{Float64,Float64}})
	variables = sort!(get_variable_positions(term))
	return bounds[variables]
end

function get_variable_positions(term :: Term)
	@match term begin
		Variable(_,_,pos) => return [pos]
		TermNumber(_) => return []
		CompositeTerm(op, args,_) => begin
			positions = []
			for arg in args
				append!(positions, get_variable_positions(arg))
			end
			return positions
		end
		_ => throw("Unexpected term type"*string(typeof(term)))
	end
end

function update_bounds(term :: Term, given_bounds :: Vector{Tuple{Float64,Float64}}, bounds :: Vector{Vector{Float64}})
	variables = sort!(get_variable_positions(term))
	for (i,b) in enumerate(given_bounds)
		if !(i in variables)
			bounds[i] = Float64[b[1],b[2]]
		end
	end
end