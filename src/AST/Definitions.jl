using MLStyle.AbstractPatterns: literal

abstract type ParsedNode end

# Terms
abstract type Term <: ParsedNode end
@as_record struct TermNumber <: Term
	value :: Rational{BigInt}
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
@enum Operation Add=0 Sub=1 Mul=2 Div=3 Pow=4 Neg=5 Min=6 Max=7
MLStyle.is_enum(::Operation)=true
MLStyle.pattern_uncall(o::Operation, _, _, _, _) = literal(o)
@as_record struct CompositeTerm <: Term
	operation :: Operation
	args :: Vector{Term}
	args_hash :: UInt
	CompositeTerm(operation :: Operation, args :: Vector{T}) where {T <: Term} = new(operation, args, reduce(+,Iterators.map(hash,args)))
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

struct ApproxQuery
	bound :: BoundType
	term :: Term
end

@as_record struct SemiLinearConstraint <: Formula
	semilinears :: Dict{ApproxQuery, Rational{BigInt}}
	coefficients :: Array{Rational{BigInt}}
	bias :: Rational{BigInt}
	equality :: Bool
	function SemiLinearConstraint(semilinears :: Dict{ApproxQuery, Rational{BigInt}})
		return function(coefficients :: Array{Rational{BigInt}}, bias :: Rational{BigInt}, equality :: Bool)
			return new(semilinears, coefficients, bias, equality)
		end
	end
end

@as_record struct OverApprox <: ApproxNode
	formula :: Formula
	under_approx :: Union{Nothing, SemiLinearConstraint}
	over_approx :: Union{Nothing, SemiLinearConstraint}
	OverApprox(formula :: Formula) = new(formula, nothing, nothing)
	OverApprox(formula :: Formula, under_approx :: SemiLinearConstraint, over_approx :: SemiLinearConstraint) = new(formula, under_approx, over_approx)
end

@as_record struct UnderApprox <: ApproxNode
	formula :: Formula
	under_approx :: Union{Nothing, SemiLinearConstraint}
	over_approx :: Union{Nothing, SemiLinearConstraint}
	UnderApprox(formula :: Formula) = new(formula, nothing, nothing)
	UnderApprox(formula :: Formula, under_approx :: SemiLinearConstraint, over_approx :: SemiLinearConstraint) = new(formula, under_approx, over_approx)
end

@as_record struct NonLinearSubstitution <: Term
	query :: ApproxQuery
end

@as_record struct LinearConstraint <: Formula
	# !equality => coefficients * variables <= constant
	# equality => coefficients * variables == constant
	coefficients :: Array{Rational{BigInt}}
	bias :: Rational{BigInt}
	equality :: Bool
end

@as_record struct LinearTerm <: Term
	coefficients :: Array{Rational{BigInt}}
	bias :: Rational{BigInt}
end

# Composite formulae
@enum Connective Not=0 And=1 Or=2 Implies=3
MLStyle.is_enum(::Connective)=true
MLStyle.pattern_uncall(e::Connective, _, _, _, _) = literal(e)
@as_record struct CompositeFormula <: Formula
	connective :: Connective
	args :: Vector{Formula}
	args_hash :: UInt
	CompositeFormula(connective :: Connective, args :: Vector{T}) where {T <: Formula} = new(connective, args, reduce(+,Iterators.map(hash,args)))
end

abstract type ApproximationPrototype end

struct Approximation <: ApproximationPrototype
	bounds :: Vector{Vector{Float64}}
	# Coefficients for linear constraint
	linear_constraints :: Vector{LinearTerm}
end

struct IncompleteApproximation <: ApproximationPrototype
	bounds :: Vector{Vector{Float64}}
	# [[0,100],[-200,0,200],[-100,100]]
	constraints :: Vector{Term}
	# [-vel, vel]
	function IncompleteApproximation( bounds :: Vector{Vector{Float64}}, formula :: Term)
		constraints = Term[formula]
		return new(bounds, constraints)
	end
end


struct Query
	formula :: Formula
	variables :: Set{Variable}
	num_input_vars :: Int64
	num_output_vars :: Int64
	approximations :: Dict{ApproxQuery, Approximation}
	bounds :: Vector{Vector{Float64}}
	function Query(formula :: Formula, variables :: Set{Variable})
		num_input_vars = length(filter(x->x.mapping[1]==Input,variables))
		num_output_vars = length(variables)-num_input_vars
		return new(formula, variables, num_input_vars, num_output_vars, Dict{ApproxQuery, Approximation}(), Vector{Vector{Float64}}())
	end
	Query(formula :: Formula, variables :: Set{Variable}, approximations :: Dict{ApproxQuery, Approximation}, bounds :: Vector{Vector{Float64}}) = new(formula, variables, length(filter(x->x.mapping[1]==Input,variables)), length(variables)-length(filter(x->x.mapping[1]==Input,variables)), approximations, bounds)
end

struct PwlConjunction
	bounds :: Vector{Vector{Float64}}
	linear_constraints :: Vector{LinearConstraint}
	semilinear_constraints :: Vector{SemiLinearConstraint}
	function PwlConjunction(num_vars :: Int64, linear_constraints :: Vector{LinearConstraint}, semilinear_constraints :: Vector{SemiLinearConstraint})
		return new(
			Vector{Float64}[Float64[] for _ in 1:num_vars],
			linear_constraints,
			semilinear_constraints
		)
	end
end

struct NormalizedQuery
	input_bounds :: Vector{Vector{Float64}}
	output_bounds :: Vector{Vector{Float64}}
	input_constraints :: PwlConjunction
	mixed_constraints :: Vector{PwlConjunction}
	approx_queries :: Dict{Term, Vector{BoundType}}
	function NormalizedQuery(
		input :: Vector{T1},
		disjunction :: Vector{Vector{T2}},
		approx_queries :: Set{ApproxQuery},
		query :: Query) where {T1 <: Formula, T2 <: Formula}
		# Initiate properties
		input_bounds = Vector{Vector{Float64}}()
		for _ in 1:query.num_input_vars
			push!(input_bounds, Float64[-Inf, Inf])
		end
		output_bounds = Vector{Vector{Float64}}()
		for _ in 1:query.num_output_vars
			push!(output_bounds, Float64[-Inf, Inf])
		end
		num_vars = query.num_input_vars + query.num_output_vars
		input_linear = Vector{LinearConstraint}()
		input_nonlinear = Vector{SemiLinearConstraint}()
		mixed_constraints = Vector{PwlConjunction}()
		approx_query_result = Dict{Term, Vector{BoundType}}()
		for f in input
			if f isa LinearConstraint
				if count(!=(0),f.coefficients)==1
					init_linear_to_bound(f, input_bounds, true, 0)
				else
					push!(input_linear, f)
				end
			elseif f isa SemiLinearConstraint
				push!(input_nonlinear, f)
			else
				error("Unsupported formula type")
			end
		end
		for conj in disjunction
			linears = Vector{LinearConstraint}()
			nonlinears = Vector{SemiLinearConstraint}()
			for f in conj
				if f isa LinearConstraint
					if count(!=(0),f.coefficients)==1
						# This assumes that every combination of constraints is linearly bounded which we do not explicitly check at the moment
						init_linear_to_bound(f, output_bounds, false, query.num_input_vars)
					end
					push!(linears, f)
				elseif f isa SemiLinearConstraint
					push!(nonlinears, f)
				else
					error("Unsupported formula type")
				end
			end
			push!(mixed_constraints, PwlConjunction(num_vars,linears, nonlinears))
		end
		for aq in approx_queries
			if !haskey(approx_query_result, aq.term)
				approx_query_result[aq.term] = BoundType[aq.bound]
			else
				push!(approx_query_result[aq.term], aq.bound)
			end
		end
		return new(input_bounds, output_bounds, PwlConjunction(num_vars,input_linear, input_nonlinear), mixed_constraints, approx_query_result)
	end
					
end

function init_linear_to_bound(f :: LinearConstraint, bounds :: Vector{Vector{Float64}},tighten::Bool, offset::Int64)
	var_index = findnext(map(!=(0.0),f.coefficients),1)
	coeff = f.coefficients[var_index]
	lower, upper = bounds[var_index-offset]
	if coeff < 0.0
		op = (tighten||isinf(lower)) ? (max) : (min)
		bounds[var_index-offset][1] = (op)(lower, f.bias/coeff)
	else
		op = (tighten||isinf(upper)) ? (min) : (max)
		bounds[var_index-offset][2] = (op)(upper, f.bias/coeff)
	end
end