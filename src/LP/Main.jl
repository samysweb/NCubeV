module LP
	using JuMP
	using GLPK

	using ..Util
	using ..AST

	export is_infeasible

	function to_linear_constraint(c :: LinearConstraint)
		return round_minimize.(c.coefficients), round_maximize(c.bias)
	end

	function is_infeasible(linear_constraints :: Vector{LinearConstraint})
		model = Model(GLPK.Optimizer)
		var_num = length(linear_constraints[1].coefficients)
		@variable(model, x[1:var_num])
		constraints = Array{Float32}(undef,(length(linear_constraints),var_num))
		biases = Array{Float32}(undef,(length(linear_constraints),1))
		for (i,c) in enumerate(linear_constraints)
			constraints[i,:], biases[i] .= to_linear_constraint(c)
		end
		@debug "Checking feasibility of ", constraints, " * x <= ", biases
		@constraint(model, constraints * x .<= biases)
		@objective(model, Min, 0)
		res = optimize!(model)
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