module LP
	using JuMP
	using GLPK
	using TimerOutputs
	using LinearAlgebra

	using ..Util
	using ..AST
	using ..Config

	export is_infeasible, get_model, optimize_dim

	function to_linear_constraint_coeff(c :: LinearConstraint)
		return round_minimize.(c.coefficients)
	end

	function to_linear_constraint_bias(c :: LinearConstraint)
		return round_maximize(c.bias)
	end

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

	function optimize_dim(dim :: Int, dir :: Float64, model_input)
		model,x = model_input
		@assert dir==-1.0 || dir==1.0 "Direction must be -1 or 1"
		@objective(model, Max, dir*x[dim])
		res = optimize!(model)
		return value(x[dim])
	end

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