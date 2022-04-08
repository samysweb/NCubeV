module SNNT
include("AST/Main.jl")
include("Parsing/Main.jl")
using .AST
export not, and, or, implies, <, <=, >, >=, ==, !=, +, -, *, /, ^
export istree, exprhead, operation, arguments,similarterm, symtype, promote_symtype

end # module
