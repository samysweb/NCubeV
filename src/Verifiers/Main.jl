"""
Verifiers
=========

Interface and default registration for verifier implementations.

This module wires in available verifiers (see `Verifiers.NNEnum`) and provides
a fallback option "NoVerify" that performs no verification. Verifiers are
registered via `Verifiers.Registry.register_verifier` and can be selected by
the control flow (see `Control.run_query`).

See also:
- `Verifiers.Registry` – central registry of verifier callbacks
- `Verifiers.NNEnum` – NNEnum-based (enumerative) verification
"""
module Verifiers

include("Registry.jl")

include("NNEnum.jl")

using ..Util
using ..AST
using ..VerifierInterface

using .Registry

function __init__()
	register_verifier("NoVerify",no_verify)
end

"""
	no_verify(model, SMTFilter, olnnv_query::OlnnvQuery) -> OlnnvResult

Dummy verifier that performs no verification and immediately returns an empty
`OlnnvResult`. Useful for smoke-testing the pipeline without invoking a
backend.

Arguments:
- `model`: Path/handle to the model (ignored)
- `SMTFilter`: Filter function (not called)
- `olnnv_query`: Open-loop NNV query structure (for logging)

Returns: `OlnnvResult()` with default values.

Note:
- Only emits log output and then returns immediately.
"""
function no_verify(model, SMTFilter, olnnv_query :: OlnnvQuery)
	print_msg("[NOVERY] Running NoVerify now...")
	lb = [b[1] for b in olnnv_query.bounds]
	ub = [b[2] for b in olnnv_query.bounds]
	print_msg("[NOVERY] lb: ", lb)
	print_msg("[NOVERY] ub: ", ub)
	print_msg("[NOVERY] # Input Constraint Matrix Size: ", size(olnnv_query.input_matrix))
	print_msg("[NOVERY] # Mixed Conjunctions: ", length(olnnv_query.disjunction))
	@warn "Skipping run since you chose NoVerify"
	return OlnnvResult()
end

export VERIFIER_CALLBACKS
end