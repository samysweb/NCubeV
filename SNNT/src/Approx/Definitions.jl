abstract type ApproximationPrototype end

struct Approximation <: ApproximationPrototype
	bounds :: Vector{Vector{Float64}}
	# Coefficients for linear constraint
	linear_constraints :: Vector{Tuple{Vector{Rational{Int128}},Rational{Int128}}}
end

struct IncompleteApproximation <: ApproximationPrototype
	bounds :: Vector{Vector{Float64}}
	# [[0,100],[-200,0,200],[-100,100]]
	constraints :: Vector{Union{Tuple{Vector{Rational{Int128}},Rational{Int128}}, Term}}
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
		input_bounds = nonlinear_query.input_bounds
		output_bounds = nonlinear_query.output_bounds
		approximations = construct_approx(nonlinear_query)
		return new{IncompleteApproximation}(nonlinear_query, input_bounds, output_bounds, approximations)
	end
end

ApproxNormalizedQuery = ApproxNormalizedQueryPrototype{Approximation}
IncompleteApproxNormalizedQuery = ApproxNormalizedQueryPrototype{IncompleteApproximation}