"""
NCubeV — Neural Network Verification via Mosaic for ReLU NNs

Top-level module that wires together parsing, analysis, linearization (OVERT-based),
Mosaic-style DPLL(T) decomposition, counterexample generalization, enumeration, and
SMT-based filtering for open-loop NNV queries on piece-wise linear (ReLU) neural networks.

This package implements the Mosaic algorithm described in [1], specifically:
- Linearization (Appendix B.1)
- Mosaic decomposition (Appendix B.2)
- Counterexample generalization and enumeration: Definition 11 (Appendix B.3)
- SMT filtering of counterexample regions: Lemma 12 (Appendix B.3)

[1] Teuber, S., Mitsch, S., Platzer, A.: Provably safe neural network controllers via dif-
ferential dynamic logic. In: Advances in Neural Information Processing Systems. Curran Associates, Inc. (2024), https://doi.org/10.48550/arXiv.2402.10998

Notes
- Assumes ReLU networks. Other activations may require different/exended NN verification backends.
- Uses external SAT/SMT and open-loop NNV backends; see submodules `SMTInterface` and `Verifiers`.

See also: `Control`, `Approx`, `QueryGeneration`, `SMTInterface`, `Verifiers`.
"""
module NCubeV

ENV["PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"]="python"

#Util
include("Util/Main.jl")
# Configuration
include("Config/Main.jl")

# Basic Definitions
include("AST/Main.jl")
include("VerifierInterface/Main.jl")

# Parsing
include("Parsing/Main.jl")

# Analysis
include("Analysis/Main.jl")

# Constraint Solvers
include("LP/Main.jl")
include("SMTInterface/Main.jl")

# Query Generation
include("QueryGeneration/Main.jl")

# Query Approximation
include("Approx/Main.jl")

# Verifier Integration
include("Verifiers/Main.jl")

# Bringing it all together
include("Control/Main.jl")

# Cmd Interface
include("Cmd/Main.jl")

using .AST
#export not, and, or, implies, <, <=, >, >=, ==, !=, +, -, *, /, ^
#export istree, exprhead, operation, arguments,similarterm, symtype, promote_symtype

using .Control
#export load_query, run_query, prepare_for_olnnv

using .Verifiers
#export VERIFIER_CALLBACKS

using .Cmd

export run_cmd

"""
    main_NCubeV() -> Cint

Entrypoint for the NCubeV command-line interface. Invokes `run_cmd(ARGS)` and returns
an integer exit code.

# Returns
- `Cint`: Process exit code compatible with `Base._start`.

# Example
```julia
julia> using NCubeV
julia> NCubeV.main_NCubeV()
0
```

Notes
- This is a thin wrapper around the CLI defined in `Cmd`.
"""
function main_NCubeV():Cint
    result = run_cmd(ARGS)
    return convert(Cint, result)
end

end # module
