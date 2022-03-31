
function term_to_string(v :: Variable)
	return v.name
end

function term_to_string(n :: TermNumber)
	return string(n.value)
end

function term_to_string(t :: CompositeTerm)
	if t.operation == AST.Neg
		return "-"*term_to_string(t.args[1])
	else
		first_value = true
		result = ""
		for v in t.args
			if first_value
				first_value = false
			else
				result = result*term_to_string(t.operation)
			end
			result = result*term_to_string(v)
		end
		return "("*result*")"
	end
end

function term_to_string(a :: Atom)
	return term_to_string(a.left)*term_to_string(a.comparator)*term_to_string(a.right)
end

function term_to_string(c :: CompositeFormula)
	if c.connective == AST.Not
		return "!("*term_to_string(c.args[1])*")"
	else
		first_value = true
		result = ""
		for v in c.args
			if first_value
				first_value = false
			else
				result = result*term_to_string(c.connective)
			end
			result = result*term_to_string(v)
		end
		return "("*result*")"
	end
end

function term_to_string(op :: Operation)
	if op == AST.Add
		return "+"
	elseif op == AST.Sub
		return "-"
	elseif op == AST.Mul
		return "*"
	elseif op == AST.Div
		return "/"
	elseif op == AST.Pow
		return "^"
	else
		throw("Unknown operation")
	end
end

function term_to_string(con :: Connective)
	if con == AST.Not
		return "!"
	elseif con == AST.And
		return "&"
	elseif con == AST.Or
		return "|"
	elseif con == AST.Implies
		return "->"
	else
		throw("Unknown connective")
	end
end

function term_to_string(comp :: Comparator)
	if comp == AST.Less
		return "<"
	elseif comp == AST.LessEq
		return "<="
	elseif comp == AST.Greater
		return ">"
	elseif comp == AST.GreaterEq
		return ">="
	elseif comp == AST.Eq
		return "="
	elseif comp == AST.Neq
		return "!="
	else
		throw("Unknown comparator")
	end
end