module Analysis
	using SymbolicUtils
	using MLStyle

	using ..AST
	export map_variables, fix_variables, translate_constraints
	export overapprox, underapprox
	include("ProcessConstraints.jl")
end