module Config
	INCLUDE_APPROXIMATIONS = true

	function set_include_approximations(flag :: Bool)
		global INCLUDE_APPROXIMATIONS = flag
	end
end