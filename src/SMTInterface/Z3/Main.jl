using Z3

#=
Z3 backend
----------

Bindings for the Z3 backend. This file wires the Z3-specific AST lowering
(`AST2Z3.jl`) and provides context/solver utilities from `Base.jl`.

Exposes Z3 via the `Z3.jl` package.
=#

include("AST2Z3.jl")
include("Base.jl")
