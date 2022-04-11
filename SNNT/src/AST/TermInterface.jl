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

istree(x :: TermNumber) = false
istree(x :: Variable) = false
istree(x::Type{CompositeTerm}) = true
istree(x::Type{Atom}) = true
istree(x::Type{CompositeFormula}) = true

issym(x::Type{TermNumber}) = true
issym(x::Type{Variable}) = true

nameof(x :: TermNumber) = x
nameof(x :: Variable) = x

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
exprhead(x :: CompositeFormula) = :call

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
arguments(x :: CompositeFormula) = x.args

function similarterm(t::CompositeTerm, f, args, symtype=CompositeTerm;metadata=nothing, exprhead=:call)
	# @debug "similarterm(CompositeTerm)"
	# @debug "t: ", t
	# @debug "f: ", f
	# @debug "args: ", args
	# @debug "symtype: ", symtype
	# @debug "metadata: ", metadata
	# @debug "exprhead: ", exprhead
	if args[1]==(*)
		println("Weird case")
		println(args[1])
		println(args[1]==(*))
		args = args[2:end]
		throw("Weird case")
	end
	return CompositeTerm(operation_to_ast(f), args)
end

function similarterm(::Type{CompositeFormula}, c, args, symtype=CompositeFormula;metadata=nothing, exprhead=:call)
	# @debug "similarterm(CompositeFormula)"
	return CompositeFormula(operation_to_ast(c), args)
end

function similarterm(::Type{Atom}, c, args, symtype=Atom;metadata=nothing, exprhead=:call)
	# @debug "similarterm(Atom)"
	if length(args) == 2
		return Atom(operation_to_ast(c), args[1], args[2])
	else
		throw("Can only instantiate atom with two arguments!")
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
	end
end

symtype(x :: TermNumber) = Number
symtype(x :: Variable) = Number
symtype(x :: CompositeTerm) = Number
symtype(x :: Atom) = Bool
symtype(x :: CompositeFormula) = Bool

isequal(x :: TermNumber, y :: TermNumber) = x.value == y.value
isequal(x :: Variable, y :: Variable) = isequal(x.name, y.name)
function isequal(x :: CompositeTerm, y :: CompositeTerm)
	if x.operation == y.operation
		return all(isequal(x.args, y.args))
	end
	return false
end
isequal(x :: Atom, y :: Atom) = x.comparator == y.comparator && isequal(x.left, y.left) && isequal(x.right, y.right)
isequal(x :: CompositeFormula, y :: CompositeFormula) = x.connective == y.connective && all(isequal(x.args, y.args))

is_literal_number(x :: TermNumber) = true