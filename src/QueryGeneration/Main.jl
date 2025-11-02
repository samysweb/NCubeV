"""
QueryGeneration
===============

Boolean skeleton and Mosaic-style decomposition utilities.

This module provides the DPLL(T)-style decomposition (Appendix B.2), transforming a
non-normalized open-loop NNV query into a sequence of normalized linear input azulejos
paired with disjunctive output constraints. It interacts with linear and nonlinear
SMT solvers to ensure satisfiability of each tile and to minimize duplicates.

Implements
- Mosaic decomposition with flatness: Proposition 9 and 10 (Appendix B.2)

See also: `Approx` for linearization, `Control.run_query`.
"""
module QueryGeneration
	using TimerOutputs

	include("PicoSAT.jl")
	using Metatheory.Rewriters
	using MLStyle
	using SymbolicUtils
	using IterTools
	using LinearAlgebra

	using ..Util
	using ..Config
	using ..AST
	using ..LP
	using ..SMTInterface
	using ..Analysis
	include("Definitions.jl")
	include("Skeleton.jl")
	include("NonLinear.jl")
	include("FeasibilityCache.jl")
	include("Iterator.jl")

	export iterate
	export NormalizedQuery
	export PwlConjunction
	export handle_nonlinearity
	export IterableQuery
end