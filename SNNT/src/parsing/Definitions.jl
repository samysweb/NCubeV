abstract type ParsedNode end

# Terms
abstract type Term <: ParsedNode end
struct Number <: Term
	value :: Float64
end
struct Variable <: Term
	name :: String
end
@enum Operation Add=0 Sub=1 Mul=2 Div=3 Pow=4
struct CompositeTerm <: Term
	operation :: Operation
	args :: Vector{Term}
end

# Formulae
abstract type Formula <: ParsedNode end

# Atoms
@enum Comparator Less=0 LessEq=1 Greater=2 GreaterEq=3 Eq=4 Neq=5
struct Atom <: Formula
	comparator :: Comparator
	left :: Term
	right :: Term
end

# Composite formulae
@enum Connective Not=0 And=1 Or=2 Implies=3
struct CompositeFormula <: Formula
	connective :: Connective
	args :: Vector{Formula}
end

struct SyntaxParsingException <: Exception
	message
end