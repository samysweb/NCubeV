module Config
	INCLUDE_APPROXIMATIONS = true

	RIGOROUS_APPROXIMATIONS = false

	APPROX_FIRST = true

	SMT_SOLVER = "Z3"

	EPSILON = 1e-3

	function __init__()
		global INCLUDE_APPROXIMATIONS = true
		global RIGOROUS_APPROXIMATIONS = false
		global SMT_SOLVER = "Z3"
	end

	function set_include_approximations(flag :: Bool)
		global INCLUDE_APPROXIMATIONS = flag
	end

	function set_rigorous_approximations(flag :: Bool)
		global RIGOROUS_APPROXIMATIONS = flag
	end

	function set_smt_solver(solver :: String)
		global SMT_SOLVER = solver
	end
end