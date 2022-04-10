module SNNT
include("AST/Main.jl")
include("Parsing/Main.jl")
using .AST
export not, and, or, implies, <, <=, >, >=, ==, !=, +, -, *, /, ^
export istree, exprhead, operation, arguments,similarterm, symtype, promote_symtype

using SymbolicUtils

x = SNNT.AST.Variable("x")
test = SNNT.AST.CompositeTerm(SNNT.AST.Mul,[TermNumber(4.0),TermNumber(2.0),x])
simplify(test,expand=false)

end # module
