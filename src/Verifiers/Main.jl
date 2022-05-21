module Verifiers
include("NNEnum.jl")

using ..VerifierInterface

import .NNEnum: verify as nnenum_verify

VERIFIER_CALLBACKS = Dict{String, Any}()

function __init__()
	global VERIFIER_CALLBACKS["NNEnum"] = nnenum_verify
	global VERIFIER_CALLBACKS["NoVerify"] = no_verify
end

function no_verify(model, olnnv_query :: OlnnvQuery)
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