module Registry
	export SMT_SOLVERS, register_smt_solver

	SMT_SOLVERS = Dict{String, Any}()
	function __init__()
		global SMT_SOLVERS = Dict{String, Any}()
	end

	function register_smt_solver(name, solver)
		global SMT_SOLVERS[name] = solver
	end
end