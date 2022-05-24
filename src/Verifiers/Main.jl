module Verifiers

include("Registry.jl")

include("NNEnum.jl")

using ..AST
using ..VerifierInterface

using .Registry

import .NNEnum: verify as nnenum_verify

function __init__()
	register_verifier("NoVerify",no_verify)
end

function no_verify(model, SMTFilter, olnnv_query :: OlnnvQuery)
	println("[NOVERY] Running NoVerify now...")
	lb = [b[1] for b in olnnv_query.bounds]
	ub = [b[2] for b in olnnv_query.bounds]
	println("[NOVERY] lb: ", lb)
	println("[NOVERY] ub: ", ub)
	println("[NOVERY] # Input Constraint Matrix Size: ", size(olnnv_query.input_matrix))
	println("[NOVERY] # Mixed Conjunctions: ", length(olnnv_query.disjunction))
	@warn "Skipping run since you chose NoVerify"
	return OlnnvResult()
end

export VERIFIER_CALLBACKS
end