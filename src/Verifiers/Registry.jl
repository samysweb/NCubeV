module Registry
	export VERIFIER_CALLBACKS, register_verifier

	VERIFIER_CALLBACKS = Dict{String, Any}()
	function __init__()
		global VERIFIER_CALLBACKS = Dict{String, Any}()
	end

	function register_verifier(name, callback)
		global VERIFIER_CALLBACKS[name] = callback
	end
end