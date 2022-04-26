function not_division(x :: Term)
	return !(x isa CompositeTerm) || operation(x) != (/) && (!istree(x) || all(y->not_division(y), arguments(x)))
end

function _isone(x :: Term)
	return x isa TermNumber && isone(x.value)
end

function _iszero(x :: Term)
	return x isa TermNumber && iszero(x.value)
end

function _istwo(x :: Term)
	return x isa TermNumber && x.value == 2
end

function _isnotzero(x :: Term)
	return !_iszero(x)
end

function _istrue(x :: Formula)
	return x isa TrueAtom
end

function _isfalse(x :: Formula)
	return x isa FalseAtom
end

function is_literal_number(x :: Term)
	return x isa TermNumber
end

function is_linear(f :: Atom)
	return f.right isa TermNumber && is_linear(f.left)
end
function is_linear(f :: Term)
	if f isa TermNumber || f isa Variable
		return true
	elseif f.operation == AST.Mul && length(f.args) == 2
		return f.args[1] isa TermNumber && f.args[2] isa Variable
	elseif f.operation == AST.Add
		return all(is_linear, f.args)
	else
		return false
	end
end