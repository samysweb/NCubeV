"""
module Control

High-level orchestration of the NCubeV pipeline.

This module ties together parsing, normalization, approximation, Mosaic iteration,
open-loop NNV backend calls, and SMT-based counterexample filtering.

Implements the end-to-end flow described throughout Appendix B:
- B.1 Linearization via `Approx`
- B.2 Mosaic decomposition via `QueryGeneration` and `Approx.Iterator`
- B.3 Counterexample generalization and SMT filtering via `Verifiers` and `SMTInterface`

See also: `load_query`, `prepare_for_olnnv`, `run_query`.
"""
module Control

using JLD
using TimerOutputs

using ..Config
using ..Util
using ..Parsing
using ..AST
using ..Analysis
using ..Approx
using ..QueryGeneration
using ..SMTInterface

export load_query, prepare_for_olnnv, run_query

include("Processing.jl")

end