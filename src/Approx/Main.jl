"""
module Approx

Linearization and query approximation for Mosaic.

This module implements the linearization step from Appendix B.1 of the paper. It uses
OVERT-style over- and under-approximations and additional treatments for max/min terms,
including the multivariate max upper bound from Lemma 8. It produces piece-wise linear
conjunctions that can be consumed by the Mosaic decomposition and the open-loop NNV backends.

Implements
- Definition 5 (Linearization) and Lemma 6 (Equivalence) — Appendix B.1
- Lemma 8 (Upper bound for multivariate max) — Appendix B.1

See also: `QueryGeneration`, `Control.prepare_for_olnnv`, `SMTInterface.StarFilter`.
"""
module Approx
	using LinearAlgebra
	using TimerOutputs

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
	EPSILON=Config.EPSILON

	include("Definitions.jl")
	include("OVERT.jl")
	include("Util.jl")
	include("PwlConjunction.jl")
	include("Iterator.jl")
	include("Approximation.jl")
	include("Verify.jl")
	include("Generation.jl")

	export ApproxCache
	export get_approx_query
	export get_approx_normalized_query
	export ApproxNormalizedQueryPrototype, IncompleteApproximation, Approximation, set_approx_density
	export get_linear_term_position, get_linear_term

    """
        set_approx_density(Nparam)

    Set the internal approximation density used by OVERT-style linearization.

    Larger values increase precision but may also increase the number of azulejos
    and the size of generated linear disjunctions.

    # Arguments
    - `Nparam::Integer`: Grid density parameter forwarded to OVERT (default 2).

    # Example
    ```julia
    julia> using NCubeV.Approx
    julia> set_approx_density(4)
    ```

    Notes
    - A higher value can cause exponential blowup in the number of generated regions.
    - See Appendix B.1 for details on approximation granularity.
    """
	function set_approx_density(Nparam)
		global N = Nparam
	end

end