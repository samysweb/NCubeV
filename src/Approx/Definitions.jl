import Base.hash
import Base.isequal

struct ApproxNormalizedQueryPrototype{T <: ApproximationPrototype}
	nonlinear_query :: NormalizedQuery
	input_bounds :: Vector{Vector{Float64}}
	output_bounds :: Vector{Vector{Float64}}
	approximations :: Dict{ApproxQuery, T}
	function ApproxNormalizedQueryPrototype{IncompleteApproximation}(nonlinear_query :: NormalizedQuery)
		input_bounds = nonlinear_query.input_bounds
		output_bounds = nonlinear_query.output_bounds
		approximations = construct_approx(nonlinear_query)
		return new{IncompleteApproximation}(nonlinear_query, input_bounds, output_bounds, approximations)
	end
	function ApproxNormalizedQueryPrototype{Approximation}(
		incomplete :: ApproxNormalizedQueryPrototype{IncompleteApproximation},
		approximations :: Dict{ApproxQuery, Approximation})
		input_bounds = deepcopy(incomplete.input_bounds)
		input_length = length(input_bounds)
		output_bounds = deepcopy(incomplete.output_bounds)
		output_length = length(output_bounds)
		for (_, approximation) in approximations
			for i in 1:input_length
				input_bounds[i] = union(input_bounds[i], approximation.bounds[i])
			end
			for j in 1:output_length
				output_bounds[j] = union(output_bounds[j], approximation.bounds[input_length+j])
			end
		end
		map(x->sort!(x),input_bounds)
		map(x->sort!(x),output_bounds)
		input_bounds = filter_bounds(input_bounds)
		output_bounds = filter_bounds(output_bounds)
		@debug "Generating ApproxNormalizedQueryPrototype{Approximation} with bounds: ", input_bounds, output_bounds
		return new{Approximation}(incomplete.nonlinear_query, input_bounds, output_bounds, approximations)
	end
end

struct ApproxCacheObject
	query :: ApproxQuery
	bounds :: Vector{Tuple{Float64,Float64}}
end

isequal(a :: ApproxCacheObject, b :: ApproxCacheObject) = isequal(a.query, b.query) && isequal(a.bounds, b.bounds)
hash(a :: ApproxCacheObject) = hash(a.query) + hash(a.bounds)

ApproxCache = Dict{ApproxCacheObject, Approximation}