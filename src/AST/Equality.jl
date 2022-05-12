import Base.isequal
import Base.hash

isequal(x :: TermNumber, y :: TermNumber) = x.value == y.value
isequal(x :: Variable, y :: Variable) = isequal(x.name, y.name)
function isequal(x :: CompositeTerm, y :: CompositeTerm)
	if x.operation == y.operation
		return all(isequal(x.args, y.args))
	end
	return false
end
isequal(x :: Atom, y :: Atom) = x.comparator == y.comparator && isequal(x.left, y.left) && isequal(x.right, y.right)
isequal(x :: LinearConstraint, y :: LinearConstraint) = isequal(x.coefficients, y.coefficients) && isequal(x.bias, y.bias) && x.equality == y.equality
isequal(x :: CompositeFormula, y :: CompositeFormula) = x.connective == y.connective && all(isequal(x.args, y.args))
isequal(x :: OverApprox, y :: OverApprox) = isequal(x.formula, y.formula)
isequal(x :: UnderApprox, y :: UnderApprox) = isequal(x.formula, y.formula)

hash(x :: TermNumber) :: UInt = hash(x.value)
hash(x :: Variable) :: UInt = hash(x.name)
hash(x :: CompositeTerm) :: UInt = hash(x.operation) * x.args_hash
hash(x :: Atom) :: UInt = hash(x.comparator) * hash(x.left) * hash(x.right)
hash(x :: LinearConstraint) :: UInt = hash(x.coefficients) * hash(x.bias) * hash(x.equality)
hash(x :: CompositeFormula) :: UInt = hash(x.connective) * x.args_hash
hash(x :: OverApprox) :: UInt = 7*hash(x.formula)
hash(x :: UnderApprox) :: UInt = 11*hash(x.formula)

isequal(a :: ApproxQuery, b :: ApproxQuery) = isequal(a.bound, b.bound) && isequal(a.term, b.term)
hash(a :: ApproxQuery) = hash(a.bound) + hash(a.term)

isequal(a :: NonLinearSubstitution, b :: NonLinearSubstitution) = isequal(a.query, b.query)
hash(a :: NonLinearSubstitution) = 13*hash(a.query)