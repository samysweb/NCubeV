module Analysis
	using SymbolicUtils
	using MLStyle

	using ..Parsing
	using ..AST
	export map_variables, fix_variables, translate_constraints, make_linear
	export get_overapprox, get_underapprox
	include("ProcessConstraints.jl")
end