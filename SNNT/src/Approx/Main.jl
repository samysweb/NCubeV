module Approx
	using LinearAlgebra

	using MLStyle
	using OVERT
	using SymbolicUtils

	using ..AST
	using ..Analysis
	using ..QueryGeneration


	EPSILON=1e-3

	include("Definitions.jl")
	include("OVERT.jl")
	include("Util.jl")
	include("Iterator.jl")
	include("Approximation.jl")
	include("Generation.jl")

	export get_approx_normalized_query

end