module Config
	using TimerOutputs
	
	# Option to (soundly!) omit all nonlinear constraints.
	# Makes problem significantly more complicated
	INCLUDE_APPROXIMATIONS = true

	# Check correctness of approximations using SMT solver
	RIGOROUS_APPROXIMATIONS = false

	# Deprecated
	APPROX_FIRST = true

	SMT_SOLVER = "Z3"

	# Overlap in approximations
	EPSILON = 1e-3

	TIMER = nothing

	# DO NOT SET THIS VARIABLE UNLESS YOU KNOW WHAT YOU ARE DOING!
	# But in case you must know: This lets you export the sat skeletons
	# (e.g. for model counting)
	QUERY_GEN_SAVE_SAT = nothing

	# Normalize numerical values within atoms
	NORMALIZE_ATOMS = true

	function __init__()
		global INCLUDE_APPROXIMATIONS = true
		global RIGOROUS_APPROXIMATIONS = false
		global SMT_SOLVER = "Z3"
		reset_timer()
	end

	function reset_timer()
		global TIMER = TimerOutput()
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