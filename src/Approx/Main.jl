module Approx
	using LinearAlgebra

	using MLStyle
	using OVERT
	using SymbolicUtils

	using ..Util
	using ..Config
	using ..AST
	using ..Analysis
	using ..LP
	using ..VerifierInterface
	using ..QueryGeneration
	using ..SMTInterface

	# OVERT configuration
	N = 2
	epsilon = 0.01
	# Pwl bound epsilon
	EPSILON=1e-3

	include("Definitions.jl")
	include("OVERT.jl")
	include("Util.jl")
	include("PwlConjunction.jl")
	include("Iterator.jl")
	include("Approximation.jl")
	include("Verify.jl")
	include("Generation.jl")

	export ApproxCache
	export get_approx_normalized_query
	export ApproxNormalizedQueryPrototype, IncompleteApproximation, Approximation

end