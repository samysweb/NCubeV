module Approx
	using LinearAlgebra

	using MLStyle
	using OVERT
	using SymbolicUtils

	using ..AST
	using ..Analysis
	using ..QueryGeneration

	include("Definitions.jl")
	include("OVERT.jl")
	include("Util.jl")
	include("Approximation.jl")

end