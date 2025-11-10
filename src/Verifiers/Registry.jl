"""
Registry
========

Simple callback registry for verifiers. Verifiers register with a key (name)
and a callback (signature typically `(model, SMTFilter, query)`) and can later
be selected by the pipeline.
"""
module Registry
	export VERIFIER_CALLBACKS, register_verifier

	"""
	Global map from verifier names to callbacks. Re-initialized in `__init__`
	to keep re-loads clean.
	"""
	VERIFIER_CALLBACKS = Dict{String, Any}()
	function __init__()
		global VERIFIER_CALLBACKS = Dict{String, Any}()
	end

	"""
		register_verifier(name::AbstractString, callback)

	Insert a verifier callback under the given name into the registry, or
	overwrite an existing entry.
	"""
	function register_verifier(name, callback)
		global VERIFIER_CALLBACKS[name] = callback
	end
end