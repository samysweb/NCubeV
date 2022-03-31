not(f :: Formula) =  CompositeFormula(Not,[f])
and(f :: Formula, g :: Formula) = nothing
or(f :: Formula, g :: Formula) = CompositeFormula(Or,[f,g])
implies(f :: Formula, g :: Formula) = CompositeFormula(Implies,[f,g])

<(t1 :: Term, t2 :: Term) = Atom(Less,t1,t2)
<=(t1 :: Term, t2 :: Term) = Atom(LessEq,t1,t2)
>(t1 :: Term, t2 :: Term) = Atom(Greater,t1,t2)
>=(t1 :: Term, t2 :: Term) = Atom(GreaterEq,t1,t2)
==(t1 :: Term, t2 :: Term) = Atom(Eq,t1,t2)
!=(t1 :: Term, t2 :: Term) = Atom(Neq,t1,t2)

+(t1 :: Term, t2 :: Term) = CompositeTerm(Add,[t1,t2])
-(t1 :: Term, t2 :: Term) = CompositeTerm(Sub,[t1,t2])
*(t1 :: Term, t2 :: Term) = CompositeTerm(Mul,[t1,t2])
/(t1 :: Term, t2 :: Term) = CompositeTerm(Div,[t1,t2])
^(t1 :: Term, t2 :: Term) = CompositeTerm(Pow,[t1,t2])