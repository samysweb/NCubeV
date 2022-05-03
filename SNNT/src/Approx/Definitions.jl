abstract type ApproximationPrototype end

struct Approximation <: ApproximationPrototype
	bounds :: Vector{Vector{Float64}}
	# Coefficients for linear constraint
	linear_constraints :: Vector{LinearTerm}
end

struct IncompleteApproximation <: ApproximationPrototype
	bounds :: Vector{Vector{Float64}}
	# [[0,100],[-200,0,200],[-100,100]]
	constraints :: Vector{Term}
	# [-vel, vel]
	function IncompleteApproximation( bounds :: Vector{Vector{Float64}}, formula :: Term)
		constraints = Union{Vector{Float64}, Term}[formula]
		return new(bounds, constraints)
	end
end


struct ApproxNormalizedQueryPrototype{T <: ApproximationPrototype}
	nonlinear_query :: NormalizedQuery
	input_bounds :: Vector{Vector{Float64}}
	output_bounds :: Vector{Vector{Float64}}
	approximations :: Dict{ApproxQuery, T}
	function ApproxNormalizedQueryPrototype{IncompleteApproximation}(nonlinear_query :: NormalizedQuery)
		@info "Constructor"
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
		return new{Approximation}(incomplete.nonlinear_query, input_bounds, output_bounds, approximations)
	end
end

ApproxNormalizedQuery = ApproxNormalizedQueryPrototype{Approximation}
IncompleteApproxNormalizedQuery = ApproxNormalizedQueryPrototype{IncompleteApproximation}