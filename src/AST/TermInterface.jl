import TermInterface.istree
import TermInterface.exprhead
import TermInterface.operation
import TermInterface.arguments
import TermInterface.similarterm
import TermInterface.symtype
import TermInterface.issym
import TermInterface.nameof
import SymbolicUtils.promote_symtype
import SymbolicUtils.is_literal_number
import Base.isequal
#import MultivariatePolynomials.similarvariable

export istree, exprhead, operation, arguments, similarterm, symtype, issym, nameof, promote_symtype, is_literal_number

istree(x :: TermNumber) = false
istree(x :: Variable) = false
istree(x::Type{CompositeTerm}) = true
istree(x::Type{LinearTerm}) = true
istree(x::Type{Atom}) = true
istree(x::Type{Predicate}) = true
istree(x::Type{LinearConstraint}) = true
istree(x::Type{CompositeFormula}) = true
istree(x::Type{OverApprox}) = true
istree(x::Type{UnderApprox}) = true
istree(x::Type{TrueAtom}) = false
istree(x::Type{FalseAtom}) = false

issym(x::Type{TermNumber}) = true
issym(x::Type{Variable}) = true
issym(x::Type{TrueAtom}) = true
issym(x::Type{FalseAtom}) = true

nameof(x :: TermNumber) = x
nameof(x :: Variable) = x
nameof(x :: TrueAtom) = :true
nameof(x :: FalseAtom) = :false

# function similarvariable(p,v::Variable)
# 	return Variable(v.name)
# end
# function similarvariable(p,v::TermNumber)
# 	return TermNumber(v.value)
# end

function exprhead(x :: CompositeTerm)
	# @debug "exprhead(CompositeTerm)"
	return :call
end
exprhead(x :: Atom) = :call
exprhead(x :: Predicate) = :call
exprhead(x :: LinearConstraint) = :call
exprhead(x :: LinearTerm) = :call
exprhead(x :: CompositeFormula) = :call
exprhead(x :: OverApprox) = :call
exprhead(x :: UnderApprox) = :call

function operation(x :: CompositeTerm)
	# @debug "operation(CompositeTerm)"
	if x.operation == Add
		return (+)
	elseif x.operation == Sub
		return (-)
	elseif x.operation == Mul
		return (*)
	elseif x.operation == Div
		return (/)
	elseif x.operation == Pow
		return (^)
	elseif x.operation == Neg
		return (-)
	elseif x.operation == Min
		return (min)
	elseif x.operation == Max
		return (max)
	else
		error("Unknown operation: "*x.operation)
	end
end
function operation(x :: Atom)
	if x.comparator == Less
		return (<)
	elseif x.comparator == LessEq
		return (<=)
	elseif x.comparator == Greater
		return (>)
	elseif x.comparator == GreaterEq
		return (>=)
	elseif x.comparator == Eq
		return (==)
	elseif x.comparator == Neq
		return (!=)
	end
end

function operation(x :: Predicate)
	return Symbol(x.predicate_name)
end

function operation(x :: LinearConstraint)
	if x.equality
		return linear_lesseq
	else
		return linear_less
	end
end
function operation(x :: LinearTerm)
	return linear
end
function operation(x :: CompositeFormula)
	if x.connective == Not
		return (not)
	elseif x.connective == And
		return (and)
	elseif x.connective == Or
		return (or)
	elseif x.connective == Implies
		return (implies)
	end
end
function operation(x :: OverApprox)
	return (overapprox_fun)
end
function operation(x :: UnderApprox)
	return (underapprox_fun)
end

function operation_to_ast(op)
	# @debug "operation_to_ast(op)"
	# @debug op
	if op == (+)
		return Add
	elseif op == (-)
		return Sub
	elseif op == (*)
		return Mul
	elseif op == (/)
		return Div
	elseif op == (^)
		return Pow
	elseif op == (min)
		return Min
	elseif op == (max)
		return Max
	elseif op == (not)
		return Not
	elseif op == (and)
		return And
	elseif op == (or)
		return Or
	elseif op == (implies)
		return Implies
	elseif op == (<)
		return Less
	elseif op == (<=)
		return LessEq
	elseif op == (>)
		return Greater
	elseif op == (>=)
		return GreaterEq
	elseif op == (==)
		return Eq
	elseif op == (!=)
		return Neq
	end
	throw("Unknown operation")
end

function arguments(x :: CompositeTerm)
	# @debug "arguments(CompositeTerm) returning ", x.args
	return x.args
end
arguments(x :: Atom) = [x.left, x.right]
arguments(x :: Predicate) = x.parameters
arguments(x :: LinearConstraint) = [x.coefficients, x.bias]
arguments(x :: LinearTerm) = [x.coefficients, x.bias]
arguments(x :: CompositeFormula) = x.args
arguments(x :: OverApprox) = [x.formula, x.under_approx, x.over_approx]
arguments(x :: UnderApprox) = [x.formula, x.under_approx, x.over_approx]


function similarterm(t::Type{CompositeTerm}, f, args, symtype=CompositeTerm;metadata=nothing, exprhead=:call)
	# @debug "similarterm(CompositeTerm)"
	# @debug "t: ", t
	# @debug "f: ", f
	# @debug "args: ", args
	# @debug "symtype: ", symtype
	# @debug "metadata: ", metadata
	# @debug "exprhead: ", exprhead
	if args[1]==(*)
		print_msg("Weird case")
		print_msg(args[1])
		print_msg(args[1]==(*))
		args = args[2:end]
		throw("Weird case")
	end
	return CompositeTerm(operation_to_ast(f), convert(Vector{Term},args))
end

function similarterm(::Type{CompositeFormula}, c, args, symtype=CompositeFormula;metadata=nothing, exprhead=:call)
	# @debug "similarterm(CompositeFormula)"
	return CompositeFormula(operation_to_ast(c), convert(Vector{Formula},args))
end

function similarterm(::Type{OverApprox}, c, args, symtype=OverApprox;metadata=nothing, exprhead=:call)
	# @debug "similarterm(OverApprox)"
	if length(args)==1 || (isnothing(args[2]) && isnothing(args[3]))
		return OverApprox(args[1])
	else
		return OverApprox(args[1],args[2],args[3])
	end
end

function similarterm(::Type{UnderApprox}, c, args, symtype=UnderApprox;metadata=nothing, exprhead=:call)
	# @debug "similarterm(UnderApprox)"
	if length(args) == 1 || (isnothing(args[2]) && isnothing(args[3]))
		return UnderApprox(args[1])
	else
		return UnderApprox(args[1],args[2],args[3])
	end
end

function similarterm(::Type{Atom}, c, args, symtype=Atom;metadata=nothing, exprhead=:call)
	# @debug "similarterm(Atom)"
	if length(args) == 2
		return Atom(operation_to_ast(c), args[1], args[2])
	else
		throw("Can only instantiate atom with two arguments!")
	end
end

function similarterm(::Type{Predicate}, c, args, symtype=Predicate;metadata=nothing,exprhead=:call)
	     #similarterm(x::Type{SNNT.AST.Predicate}, head::Symbol, args::Vector{SNNT.AST.Variable}, symtype::Type; metadata::Nothing, exprhead::Symbol)
	return Predicate(string(c), args)
end

function similarterm(::Type{LinearConstraint}, c, args, symtype=LinearConstraint;metadata=nothing, exprhead=:call)
	# @debug "similarterm(LinearConstraint)"
	if length(args) == 2
		return LinearConstraint(args[1],args[2],(c==linear_lesseq))
	else
		throw("Can only instantiate linear constraint with two arguments!")
	end
end

function similarterm(::Type{LinearTerm}, c, args, symtype=LinearTerm;metadata=nothing, exprhead=:call)
	# @debug "similarterm(LinearTerm)"
	if length(args) == 2
		return LinearTerm(args[1],args[2])
	else
		throw("Can only instantiate linear term with two arguments!")
	end
end

function promote_symtype(f :: Symbol, arg_symtypes)
	# @debug "promote_symtype(Symbol, Vector{Symbol})"
	# @debug f
	# @debug arg_symtypes
	if f == (+) || f == (-) || f == (*) || f == (/) || f == (^)
		return CompositeTerm
	elseif f == :(!) || f == :(&&) || f == :(||) || f == :implies
		return CompositeFormula
	elseif f == :(<) || f == :(<=) || f == :(>) || f == :(>=) || f == :(==) || f == :(!=)
		return Atom
	else
		raise("Unclear symtype for symbol $(f)")
	end
end

symtype(x :: TermNumber) = Number
symtype(x :: Variable) = Number
symtype(x :: CompositeTerm) = Number
symtype(x :: LinearTerm) = Number
symtype(x :: Atom) = Bool
symtype(x :: Predicate) = Bool
symtype(x :: LinearConstraint) = Bool
symtype(x :: CompositeFormula) = Bool
symtype(x :: OverApprox) = Bool
symtype(x :: UnderApprox) = Bool
symtype(x :: TrueAtom) = Bool
symtype(x :: FalseAtom) = Bool


function is_literal_number(x :: Term)
	return x isa TermNumber
end


istree(x :: NonLinearSubstitution) = false
issym(x :: NonLinearSubstitution) = true
nameof(x :: NonLinearSubstitution) = x
symtype(x :: NonLinearSubstitution) = Number