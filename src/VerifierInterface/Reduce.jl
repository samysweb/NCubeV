function reduce_results(results :: Vector{Any}) :: OlnnvResult
	# reduce the results to a single result
	status = Safe
	meta_data = []
	stars = Star[]
	for cur_result in results
		if !(cur_result isa OlnnvResult)
			@warn "Ignored result of type ", typeof(cur_result)
			continue
		end
		status = merge_status(status, cur_result.status)
		push!(meta_data, cur_result.metadata)
		append!(stars, cur_result.stars)
	end
	return OlnnvResult(status, meta_data, stars)
end

function merge_status(old_status, incoming_status)
	if old_status == Safe
		return incoming_status
	elseif incoming_status == Unknown
		return Unknown
	else
		return old_status
	end	
end