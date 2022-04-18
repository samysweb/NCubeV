module LP
	using JuMP
	using GLPK

	using ..AST

	export is_feasible

	function is_feasible(linear_constraints :: Vector{LinearConstraint})
		model = Model(GLPK.Optimizer)
		var_num = length(linear_constraints[1].coefficients)
		@variable(model, x[1:var_num])
		constraints = Array{Float64}(undef,(length(linear_constraints),var_num))
		biases = Array{Float64}(undef,(length(linear_constraints),1))
		for (i,c) in enumerate(linear_constraints)
			constraints[i,:] = c.coefficients
			biases[i] = c.bias
			# TODO(steuber): Ignores inequality vs equality
		end
		@debug "Checking feasibility of ", constraints, " * x <= ", biases
		@constraint(model, constraints * x .<= biases)
		@objective(model, Min, 0)
		res = optimize!(model)
		@debug "Result: ", res
		@debug "Status: ", primal_status(model)
		@debug "Value: ", value.(x)
		return termination_status(model) != MOI.INFEASIBLE
	end
end