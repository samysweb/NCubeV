"""
LP
==

Helper utilities for linear programming with JuMP/GLPK.

This module provides primitive operations to check feasibility of (semi-)linear
constraints and to perform simple per-dimension optimizations. It is used in
approximation and when generating input regions.

Notes:
- Coefficients are normalized for numerical stability (`1/norm(coeffs)`).
- The default solver is GLPK; configure via JuMP if needed.
"""
module LP
	using JuMP
	using GLPK
	using TimerOutputs
	using LinearAlgebra

	using ..Util
	using ..AST
	using ..Config

	export is_infeasible, get_model, optimize_dim

	"""
		to_linear_constraint_coeff(c::LinearConstraint) -> Vector{Float32}

	Return the rounded coefficients of a `LinearConstraint`.
	Rounding is applied component-wise via `Util.round_minimize`.
	"""
	function to_linear_constraint_coeff(c :: LinearConstraint)
		return round_minimize.(c.coefficients)
	end

	"""
		to_linear_constraint_bias(c::LinearConstraint) -> Float32

	Return the rounded right-hand side (bias) of a
	`LinearConstraint`. Rounding is applied via `Util.round_maximize`.
	"""
	function to_linear_constraint_bias(c :: LinearConstraint)
		return round_maximize(c.bias)
	end

	"""
		get_model(linear_constraints::Vector{LinearConstraint})
			-> (model::Model, x::JuMP.Containers.DenseAxisArray)

	Build a JuMP/GLPK model with constraints `A*x <= b` according to the
	provided `LinearConstraint`s and return the model and the variable array.
	Constraints are scaled for stability.
	"""
	function get_model(linear_constraints :: Vector{LinearConstraint})
		model = Model(GLPK.Optimizer)
		var_num = length(linear_constraints[1].coefficients)
		@variable(model, x[1:var_num])
		constraints = Array{Float32}(undef,(length(linear_constraints),var_num))
		biases = Array{Float32}(undef,length(linear_constraints))
		for (i,c) in enumerate(linear_constraints)
			coeff_normalization = 1.0/norm(c.coefficients)
			constraints[i,:] .= coeff_normalization.*to_linear_constraint_coeff(c)
			biases[i] = coeff_normalization*to_linear_constraint_bias(c)
		end
		@debug "Checking feasibility of ", constraints, " * x <= ", biases
		@constraint(model, constraints * x .<= biases)
		return model,x
	end

	"""
		optimize_dim(dim::Int, dir::Float64, model_input) -> Float64

	Optimize variable `x[dim]` in direction `dir ∈ {-1.0, 1.0}` and return the
	optimal value. `model_input` is the tuple `(model, x)` as returned by
	`get_model`.
	"""
	function optimize_dim(dim :: Int, dir :: Float64, model_input)
		model,x = model_input
		@assert dir==-1.0 || dir==1.0 "Direction must be -1 or 1"
		@objective(model, Max, dir*x[dim])
		res = optimize!(model)
		return value(x[dim])
	end

	"""
		is_infeasible(linear_constraints::Vector{LinearConstraint}) -> Bool

	Check infeasibility of a system `A*x <= b` based on a list of
	`LinearConstraint`. Returns `true` if GLPK deems the system infeasible.
	"""
	function is_infeasible(linear_constraints :: Vector{LinearConstraint})
		@timeit Config.TIMER "LP_create_model" begin
		model = Model(GLPK.Optimizer)
		var_num = length(linear_constraints[1].coefficients)
		@variable(model, x[1:var_num])
		end
		@timeit Config.TIMER "LP_populate_constraints" begin
		constraints = Array{Float32}(undef,(length(linear_constraints),var_num))
		biases = Array{Float32}(undef,(length(linear_constraints),1))
		for (i,c) in enumerate(linear_constraints)
			coeff_normalization = 1.0/norm(c.coefficients)
			constraints[i,:] .= coeff_normalization.*to_linear_constraint_coeff(c)
			biases[i] = coeff_normalization.*to_linear_constraint_bias(c)
		end
		@debug "Checking feasibility of ", constraints, " * x <= ", biases
		end
		@timeit Config.TIMER "LP_add_constraints" begin
		#println(constraints)
		@constraint(model, constraints * x .<= biases)
		@objective(model, Min, 0)
		end
		res = @timeit Config.TIMER "LP_check"  optimize!(model)
		@debug "Result: ", res
		@debug "Status: ", primal_status(model)
		@debug "Value: ", value.(x)
		return termination_status(model) == MOI.INFEASIBLE
	end

	"""
		is_infeasible(bounds, matrix, bias) -> Bool

	Variant with explicit box bounds `bounds::Vector{Tuple{Float64,Float64}}`
	and additional inequalities `matrix * x <= bias`.
	"""
	function is_infeasible(bounds :: Vector{Tuple{Float64,Float64}},matrix :: Matrix{Float32}, bias :: Vector{Float32})
		@assert size(matrix)[1] == size(bias)[1]
		model = Model(GLPK.Optimizer)
		var_num = size(matrix)[2]
		@variable(model, x[1:var_num])
		for (i,b) in enumerate(bounds)
			@constraint(model, -x[i] <= -b[1])
			@constraint(model, x[i] <= b[2])
		end
		@constraint(model, matrix * x .<= bias)
		@objective(model, Min, 0)
		optimize!(model)
		status = termination_status(model)
		@debug "Status: ", status
		return status == MOI.INFEASIBLE
	end
end