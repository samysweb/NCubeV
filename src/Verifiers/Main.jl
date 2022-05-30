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