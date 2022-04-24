abstract type ApproximationPrototype end

struct Approximation <: ApproximationPrototype
	constraints :: Vector{Vector{Float64}}
	# Coefficients for linear constraint
	linear_constraints :: Vector{Vector{Float64}}
end

struct IncompleteApproximation <: ApproximationPrototype
	bounds :: Vector{Vector{Float64}}
	constraints :: Vector{Union{Vector{Float64}, Term}}
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
		input_bounds = nonlinear_query.input_bounds
		output_bounds = nonlinear_query.output_bounds
		approximations = construct_approx(nonlinear_query)
		return new{IncompleteApproximation}(nonlinear_query, input_bounds, output_bounds, approximations)
	end
end

ApproxNormalizedQuery = ApproxNormalizedQueryPrototype{Approximation}
IncompleteApproxNormalizedQuery = ApproxNormalizedQueryPrototype{IncompleteApproximation}