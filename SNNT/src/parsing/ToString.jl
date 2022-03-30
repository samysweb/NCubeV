
function term_to_string(v :: Variable)
	return v.name
end

function term_to_string(n :: Number)
	return string(n.value)
end

function term_to_string(t :: CompositeTerm)
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

function term_to_string(a :: Atom)
	return term_to_string(a.left)*term_to_string(a.comparator)*term_to_string(a.right)
end

function term_to_string(c :: CompositeFormula)
	if c.connective == Not
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
	if op == Add
		return "+"
	elseif op == Sub
		return "-"
	elseif op == Mul
		return "*"
	elseif op == Div
		return "/"
	elseif op == Pow
		return "^"
	else
		throw("Unknown operation")
	end
end

function term_to_string(con :: Connective)
	if con == Not
		return "!"
	elseif con == And
		return "&"
	elseif con == Or
		return "|"
	elseif con == Implies
		return "->"
	else
		throw("Unknown connective")
	end
end

function term_to_string(comp :: Comparator)
	if comp == Less
		return "<"
	elseif comp == LessEq
		return "<="
	elseif comp == Greater
		return ">"
	elseif comp == GreaterEq
		return ">="
	elseif comp == Eq
		return "="
	elseif comp == Neq
		return "!="
	else
		throw("Unknown comparator")
	end
end