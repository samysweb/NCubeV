# TODO(steuber): Put this somewhere else? Doesn't really belong here...
struct OlnnvQuery
	bounds :: Vector{Tuple{Float64,Float64}}
	input_matrix :: Matrix{Float32}
	input_bias :: Vector{Float32}
	disjunction :: Vector{Tuple{Matrix{Float32},Vector{Float32}}}
end

struct Star
	constraint_matrix :: Matrix{Float32}
	constraint_bias :: Vector{Float32}
	output_map_matrix :: Matrix{Float32}
	output_map_bias :: Vector{Float32}
	bounds :: Vector{Tuple{Float64,Float64}}
	counter_example :: Tuple{Vector{Float32},Vector{Float32}}
	function Star(star_tuple)
		bound_result = star_tuple[5]
		bounds = Vector{Tuple{Float64,Float64}}(undef,size(bound_result)[1])
		for b in eachrow(bound_result)
			bounds[b[1]+1] = (b[2],b[3])
		end
		return new(star_tuple[1], star_tuple[2], star_tuple[3], star_tuple[4], bounds, star_tuple[6])
	end
end

struct OlnnvResult
	result_str :: String
	metadata :: Any
	stars :: Vector{Star}
	function OlnnvResult(result_str, metadata, stars)
		return new(result_str, metadata, stars)
	end
	function OlnnvResult()
		return new("none", nothing, Star[])
	end
end
