abstract type ParsedNode end

# Terms
abstract type Term <: ParsedNode end
struct TermNumber <: Term
	value :: Float64
end
struct Variable <: Term
	name :: String
end
@enum Operation Add=0 Sub=1 Mul=2 Div=3 Pow=4 Neg=5
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

struct TrueAtom <: Formula end
struct FalseAtom <: Formula end

struct LinearConstraint <: Formula
	# !equality => coefficients * variables <= constant
	# equality => coefficients * variables == constant
	coefficients :: Array{Float64}
	bias :: Float64
	equality :: Bool
end

# Composite formulae
@enum Connective Not=0 And=1 Or=2 Implies=3
struct CompositeFormula <: Formula
	connective :: Connective
	args :: Vector{Formula}
end