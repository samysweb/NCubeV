using MLStyle.AbstractPatterns: literal

abstract type ParsedNode end

# Terms
abstract type Term <: ParsedNode end
@as_record struct TermNumber <: Term
	value :: Rational{Int32}
end

@enum VariableType Input=1 Output=2
MLStyle.is_enum(::VariableType)=true
MLStyle.pattern_uncall(e::VariableType, _, _, _, _) = literal(e)

@as_record struct Variable <: Term
	name :: String
	mapping :: Union{Nothing,Tuple{VariableType, Int64}}
	position :: Union{Nothing,Int64}
	Variable(name :: String) = new(name, nothing, nothing)
	# Full constructor
	Variable(name :: String, mapping :: Union{Nothing,Tuple{VariableType, Int64}}, position :: Union{Nothing,Int64}) = new(name, mapping, position)
end
@enum Operation Add=0 Sub=1 Mul=2 Div=3 Pow=4 Neg=5
MLStyle.is_enum(::Operation)=true
MLStyle.pattern_uncall(o::Operation, _, _, _, _) = literal(o)
@as_record struct CompositeTerm <: Term
	operation :: Operation
	args :: Vector{Term}
end

# Formulae
abstract type Formula <: ParsedNode end

# Atoms
# After simplification the only ones allowed are Less, LessEq, Eq, Neq
@enum Comparator Less=0 LessEq=1 Greater=2 GreaterEq=3 Eq=4 Neq=5
MLStyle.is_enum(::Comparator)=true
MLStyle.pattern_uncall(e::Comparator, _, _, _, _) = literal(e)
@as_record struct Atom <: Formula
	comparator :: Comparator
	left :: Term
	right :: Term
end

@as_record struct TrueAtom <: Formula end
@as_record struct FalseAtom <: Formula end

abstract type ApproxNode <: Formula end

@enum BoundType Lower=0 Upper=1
MLStyle.is_enum(::BoundType)=true
MLStyle.pattern_uncall(e::BoundType, _, _, _, _) = literal(e)

flip(b :: BoundType) = if b == Lower Upper else Lower end

@as_record struct OverApprox <: ApproxNode
	formula :: Formula
end

@as_record struct UnderApprox <: ApproxNode
	formula :: Formula
end

@as_record struct LinearConstraint <: Formula
	# !equality => coefficients * variables <= constant
	# equality => coefficients * variables == constant
	coefficients :: Array{Float64}
	bias :: Float64
	equality :: Bool
end

# Composite formulae
@enum Connective Not=0 And=1 Or=2 Implies=3
MLStyle.is_enum(::Connective)=true
MLStyle.pattern_uncall(e::Connective, _, _, _, _) = literal(e)
@as_record struct CompositeFormula <: Formula
	connective :: Connective
	args :: Vector{Formula}
end

struct Query
	formula :: Formula
	variables :: Set{Variable}
	num_input_vars :: Int64
	num_output_vars :: Int64
	function Query(formula :: Formula, variables :: Set{Variable})
		num_input_vars = length(filter(x->x.mapping[1]==Input,variables))
		num_output_vars = length(variables)-num_input_vars
		return new(formula, variables, num_input_vars, num_output_vars)
	end
end