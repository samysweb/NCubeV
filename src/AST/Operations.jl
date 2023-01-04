import Base.*
import Base.+
import Base.-
import Base.^
import Base./
import Base.convert

export not, and, or, implies, le, leq, gr, geq, eq, neq, +, -, *, /, ^

# TODO(steuber): Improve memory efficiency

not(f :: T1) where {T1 <: Formula} =  CompositeFormula(Not,Formula[f])
function and(fs :: T1...) where {T1 <: Formula}
	return and_construction(fs)
end

function and_construction(fs)
	if fs isa Formula
		# In case there is only one element in and
		return fs
	end
	fs = convert(Vector{Formula}, fs)
	if length(fs) == 0
		return TrueAtom()
	elseif length(fs) == 1
		return fs[1]
	else
		return CompositeFormula(And, fs)
	end
end
function or(fs :: T1...) where {T1 <: Formula}
	return or_construction(fs)
end

function or_construction(fs)
	if fs isa Formula
		# In case there is only one element in or
		return fs
	end
	fs = convert(Vector{Formula}, fs)
	if length(fs) == 0
		return FalseAtom()
	elseif length(fs) == 1
		return fs[1]
	else
		return CompositeFormula(Or, fs)
	end
end
implies(f :: T1, g :: T2) where {T1 <: Formula,T2 <: Formula} = CompositeFormula(Implies,Formula[f,g])

linear_lesseq(coeff :: Vector{Rational{BigInt}}, bias :: Rational{BigInt}) = LinearConstraint(coeff, bias, true)
linear_less(coeff :: Vector{Rational{BigInt}}, bias :: Rational{BigInt}) = LinearConstraint(coeff, bias, false)

linear(coeff :: Vector{Rational{BigInt}}, bias :: Rational{BigInt}) = LinearTerm(coeff, bias)

overapprox_fun(f :: T1) where {T1 <: Formula} = OverApprox(f)
underapprox_fun(f :: T1) where {T1 <: Formula} = UnderApprox(f)

le(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(Less,t1,t2)
leq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(LessEq,t1,t2)
gr(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(Greater,t1,t2)
geq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(GreaterEq,t1,t2)
eq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(Eq,t1,t2)
neq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(Neq,t1,t2)

#+(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Add,Term[t1,t2])
#+(t1 :: T1) where {T1 <: Union{Term,Number}} = t1
+(t1 :: Term, t2 :: Number) = +(t1, TermNumber(t2))
+(t1 :: Number, t2 :: Term) = +(TermNumber(t1), t2)
function +(t1 :: T1, t2 :: T2...) where {T1 <: Term,T2 <: Term}
	args = Term[t1]
	append!(args, t2)
	if all(x->x isa TermNumber, args)
		return TermNumber(+(map(x->x.value, args)...))
	else
		CompositeTerm(Add,args)
	end
end
-(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Sub,Term[t1,t2])
#*(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Mul,Term[t1,t2])
#*(t1 :: T1) where {T1 <: Union{Term,Number}} = t1
function *(t1 :: Term, t2 :: Number)
	*(t1, TermNumber(t2))
end
function *(t1 :: Number, t2 :: Term)
	return *(TermNumber(t1), t2)
end
function *(t1 :: T1, t2 :: T2...) where {T1 <: Term,T2 <: Term}
	args = Term[t1]
	append!(args, t2)
	if all(x->x isa Number, args)
		return Base.*(args...)
	elseif all(x->x isa TermNumber, args)
		result = TermNumber(*(map(x->x.value, args)...))
	else
		result = CompositeTerm(Mul,args)
	end
	# @debug result
	return result
end
function /(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}}
	if t1 isa TermNumber && t2 isa TermNumber
		return TermNumber(t1.value // t2.value)
	else
		return CompositeTerm(Div,Term[t1,t2])
	end
end
function ^(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}}
	if t1 isa TermNumber && t2 isa TermNumber
		return TermNumber(Rational{BigInt}((t1.value.num ^ t2.value))//Rational{BigInt}((t1.value.den ^ t2.value)))
	elseif t1 isa TermNumber && t2 isa Number
		return TermNumber((t1.value.num ^ t2)//(t1.value.den ^ 1))
	else
		return CompositeTerm(Pow,Term[t1,t2])
	end
end

convert(::Type{Term}, x :: T) where {T <: Number} = TermNumber(x)



function negate(a :: Atom)
	if a.comparator == Less
		return Atom(LessEq, simplify(CompositeTerm(Neg,Term[a.left])), TermNumber(-a.right.value))
	elseif a.comparator == LessEq
		return Atom(Less, simplify(CompositeTerm(Neg,Term[a.left])), TermNumber(-a.right.value))
	else
		throw("Unexpected comparator in negate"*string(a))
	end
	# elseif a.comparator == Greater
	# 	return Atom(LessEq, a.left, a.right)
	# elseif a.comparator == GreaterEq
	# 	return Atom(Less, a.left, a.right)
	# elseif a.comparator == Eq
	# 	return Atom(Neq, a.left, a.right)
	# elseif a.comparator == Neq
	# 	return Atom(Eq, a.left, a.right)
	# else
	# 	return CompositeFormula(Not, [a])
	# end
end

function negate(a :: LinearConstraint)
	return LinearConstraint(-a.coefficients, -a.bias, !a.equality)
end