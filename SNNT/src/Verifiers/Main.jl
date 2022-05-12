module Verifiers
include("NNEnum.jl")

import .NNEnum: verify as nnenum_verify

VERIFIER_CALLBACKS = Dict{String, Any}()

function __init__()
	global VERIFIER_CALLBACKS["NNEnum"] = nnenum_verify
end

export VERIFIER_CALLBACKS
end