import Base.*
import Base.+
import Base.-
import Base.^
import Base./
import Base.convert

export not, and, or, implies, le, leq, gr, geq, eq, neq, +, -, *, /, ^

not(f :: T1) where {T1 <: Formula} =  CompositeFormula(Not,[f])
and(f :: T1, g :: T2) where {T1 <: Formula,T2 <: Formula} = nothing
or(f :: T1, g :: T2) where {T1 <: Formula,T2 <: Formula} = CompositeFormula(Or,[f,g])
implies(f :: T1, g :: T2) where {T1 <: Formula,T2 <: Formula} = CompositeFormula(Implies,[f,g])

le(t1 :: T1, t2 :: T1) where {T1 <: Term,T2 <: Term} = Atom(Less,t1,t2)
leq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(LessEq,t1,t2)
gr(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(Greater,t1,t2)
geq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(GreaterEq,t1,t2)
eq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(Eq,t1,t2)
neq(t1 :: T1, t2 :: T2) where {T1 <: Term,T2 <: Term} = Atom(Neq,t1,t2)

+(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Add,Term[t1,t2])
function +(t1 :: T1, t2 :: T2, t3 :: T3, t4 :: T4...) where {T1 <: Term,T2 <: Term,T3 <: Term,T4 <: Term}
	args = Term[t1,t2,t3]
	append!(args, t4)
	CompositeTerm(Add,args)
end
+(t1 :: T1) where {T1 <: Union{Term,Number}} = t1
-(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Sub,Term[t1,t2])
*(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Mul,Term[t1,t2])
function *(t1 :: T1, t2 :: T2, t3 :: T3, t4 :: T4...) where {T1 <: Term,T2 <: Term,T3 <: Term,T4 <: Term}
	args = Term[t1,t2,t3]
	append!(args, t4)
	CompositeTerm(Mul,args)
end
*(t1 :: T1) where {T1 <: Union{Term,Number}} = t1
/(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Div,Term[t1,t2])
^(t1 :: T1, t2 :: T2) where {T1 <: Union{Term,Number},T2 <: Union{Term,Number}} = CompositeTerm(Pow,Term[t1,t2])

convert(::Type{Term}, x :: T) where {T <: Number} = TermNumber(x)