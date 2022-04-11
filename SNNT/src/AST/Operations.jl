import Base.*
import Base.+
import Base.-
import Base.^
import Base./
import Base.convert

export not, and, or, implies, le, leq, gr, geq, eq, neq, +, -, *, /, ^

not(f :: T1) where {T1 <: Formula} =  CompositeFormula(Not,[f])
function and(fs :: T1...) where {T1 <: Formula}
	return and_construction(fs)
end
function and_construction(fs :: Vector{Formula})
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
function or_construction(fs :: Vector{Formula})
	if length(fs) == 0
		return FalseAtom()
	elseif length(fs) == 1
		return fs[1]
	else
		return CompositeFormula(Or, fs)
	end
end
implies(f :: T1, g :: T2) where {T1 <: Formula,T2 <: Formula} = CompositeFormula(Implies,[f,g])

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
	@debug result
	return result
end
function /(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}}
	if t1 isa TermNumber && t2 isa TermNumber
		return TermNumber(t1.value / t2.value)
	else
		return CompositeTerm(Div,Term[t1,t2])
	end
end
^(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Pow,Term[t1,t2])

convert(::Type{Term}, x :: T) where {T <: Number} = TermNumber(x)