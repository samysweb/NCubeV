module SNNT
include("AST/Main.jl")
include("Parsing/Main.jl")
include("Analysis/Main.jl")
include("Control/Main.jl")
using .AST
export not, and, or, implies, <, <=, >, >=, ==, !=, +, -, *, /, ^
export istree, exprhead, operation, arguments,similarterm, symtype, promote_symtype

using .Control
export load_task


end # module
