using PyCall

PY_CVC5 = nothing

function __init__()
	py"""
	import cvc5.pythonic
	"""
	global PY_CVC5 = py"cvc5.pythonic"
end

include("AST2CVC5.jl")
include("Base.jl")