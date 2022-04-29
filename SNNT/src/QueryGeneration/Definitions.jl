import Base.isequal
import Base.hash

@data BooleanVariableType begin
	IntermediateVariable
	ConstraintVariable(::Union{LinearConstraint,Atom,ApproxNode})
end

mutable struct BooleanSkeleton
	formula :: Formula
	variable_mapping :: Dict{Int64, BooleanVariableType}
	sat_instance :: PicoPtr
	function BooleanSkeleton(formula :: F) where {F <: Formula}
		variable_mapping = Dict{Int64, BooleanVariableType}()
		sat_instance :: PicoPtr = picosat_init()
		skeleton = new(formula, variable_mapping, sat_instance)
		finalizer(x -> picosat_reset(x.sat_instance), skeleton)
		transform_formula(skeleton)
		return skeleton
	end
end

struct SkeletonFormula <: Formula
	variable_number :: Int64
end

struct PwlConjunction
	bounds :: Vector{Vector{Float64}}
	linear_constraints :: Vector{LinearConstraint}
	semilinear_constraints :: Vector{SemiLinearConstraint}
	function PwlConjunction(num_vars :: Int64, linear_constraints :: Vector{LinearConstraint}, semilinear_constraints :: Vector{SemiLinearConstraint})
		return new(
			Vector{Float64}[Float64[] for _ in 1:num_vars],
			linear_constraints,
			semilinear_constraints
		)
	end
end

struct NormalizedQuery
	input_bounds :: Vector{Vector{Float64}}
	output_bounds :: Vector{Vector{Float64}}
	input_constraints :: PwlConjunction
	mixed_constraints :: Vector{PwlConjunction}
	approx_queries :: Dict{Term, Vector{BoundType}}
	function NormalizedQuery(
		input :: Vector{Formula},
		disjunction :: Vector{Vector{Formula}},
		approx_queries :: Set{ApproxQuery},
		query :: Query)
		# Initiate properties
		input_bounds = Vector{Vector{Float64}}()
		for _ in 1:query.num_input_vars
			push!(input_bounds, Float64[-Inf, Inf])
		end
		output_bounds = Vector{Vector{Float64}}()
		for _ in 1:query.num_output_vars
			push!(output_bounds, Float64[-Inf, Inf])
		end
		num_vars = query.num_input_vars + query.num_output_vars
		input_linear = Vector{LinearConstraint}()
		input_nonlinear = Vector{SemiLinearConstraint}()
		mixed_constraints = Vector{PwlConjunction}()
		approx_query_result = Dict{Term, Vector{BoundType}}()
		for f in input
			if f isa LinearConstraint
				if count(!=(0),f.coefficients)==1
					init_linear_to_bound(f, input_bounds, true, 0)
				else
					push!(input_linear, f)
				end
			elseif f isa SemiLinearConstraint
				push!(input_nonlinear, f)
			else
				error("Unsupported formula type")
			end
		end
		for conj in disjunction
			linears = Vector{LinearConstraint}()
			nonlinears = Vector{SemiLinearConstraint}()
			for f in conj
				if f isa LinearConstraint
					if count(!=(0),f.coefficients)==1
						# This assumes that every combination of constraints is linearly bounded which we do not explicitly check at the moment
						init_linear_to_bound(f, output_bounds, false, query.num_input_vars)
					end
					push!(linears, f)
				elseif f isa SemiLinearConstraint
					push!(nonlinears, f)
				else
					error("Unsupported formula type")
				end
			end
			push!(mixed_constraints, PwlConjunction(num_vars,linears, nonlinears))
		end
		for aq in approx_queries
			if !haskey(approx_query_result, aq.term)
				approx_query_result[aq.term] = BoundType[aq.bound]
			else
				push!(approx_query_result[aq.term], aq.bound)
			end
		end
		return new(input_bounds, output_bounds, PwlConjunction(num_vars,input_linear, input_nonlinear), mixed_constraints, approx_query_result)
	end
					
end

function init_linear_to_bound(f :: LinearConstraint, bounds :: Vector{Vector{Float64}},tighten::Bool, offset::Int64)
	var_index = findnext(map(!=(0.0),f.coefficients),1)
	coeff = f.coefficients[var_index]
	lower, upper = bounds[var_index-offset]
	if coeff < 0.0
		op = (tighten||isinf(lower)) ? (max) : (min)
		bounds[var_index-offset][1] = (op)(lower, f.bias/coeff)
	else
		op = (tighten||isinf(upper)) ? (min) : (max)
		bounds[var_index-offset][2] = (op)(upper, f.bias/coeff)
	end
end