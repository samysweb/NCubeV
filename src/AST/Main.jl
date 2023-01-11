module AST

using SymbolicUtils
using MLStyle

using ..Util
using ..Config

export Query, ParsedNode, Term, VariableType, Variable, NonLinearSubstitution, TermNumber, LinearTerm, Operation, CompositeTerm, Formula, Comparator, Atom, TrueAtom, FalseAtom, Connective, CompositeFormula, BoundType
export Input, Output, Add, Sub, Mul, Div, Pow, Neg, Less, LessEq, Greater, GreaterEq, Eq, Neq, Not, And, Or, Implies, ITE, Lower, Upper
export ApproxNode, ApproxQuery, OverApprox, UnderApprox, LinearConstraint, SemiLinearConstraint, OlnnvQuery
export NormalizedQuery, PwlConjunction
export flip
export istree, exprhead, operation, arguments,similarterm,symtype, promote_symtype
export to_expr, from_expr
export ApproximationPrototype, Approximation, IncompleteApproximation
export get_num_cases, get_bounds_by_id, get_linear_term_position, get_position, get_linear_term

include("Definitions.jl")
include("Equality.jl")
include("Util.jl")
include("Operations.jl")
include("TermInterface.jl")
include("SymbolicUtils.jl")
include("ToString.jl")
include("Expr.jl")

end