module AST

export ParsedNode, Term, Variable, TermNumber, Operation, CompositeTerm, Formula, Comparator, Atom, Connective, CompositeFormula
export istree, exprhead, operation, arguments,similarterm,symtype, promote_symtype

include("Definitions.jl")
include("Operations.jl")
include("TermInterface.jl")


end