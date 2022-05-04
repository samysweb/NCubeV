module Config
	INCLUDE_APPROXIMATIONS = true

	RIGOROUS_APPROXIMATIONS = false

	function set_include_approximations(flag :: Bool)
		global INCLUDE_APPROXIMATIONS = flag
	end

	function set_rigorous_approximations(flag :: Bool)
		global RIGOROUS_APPROXIMATIONS = flag
	end
end