module Analysis
	using SymbolicUtils
	using MLStyle

	using ..AST
	export map_variables, fix_variables, translate_constraints, make_linear
	export overapprox, underapprox
	include("ProcessConstraints.jl")
end