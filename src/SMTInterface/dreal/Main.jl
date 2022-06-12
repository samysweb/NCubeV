using PyCall

PY_DREAL = nothing

function __init__()
	py"""
	import dreal
	"""
	global PY_CVC5 = py"dreal"
end

include("AST2dreal.jl")
include("Base.jl")