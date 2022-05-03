import Base.show

function term_to_string(v :: Variable)
	return v.name
end

function term_to_string(n :: TermNumber)
	return string(convert(Float32,n.value))
end

function term_to_string(t :: CompositeTerm)
	if t.operation == AST.Neg || (t.operation == AST.Sub && length(t.args) == 1)
		return "-("*term_to_string(t.args[1])*")"
	elseif t.operation == Min || t.operation == Max
		res = term_to_string(t.operation)*"("
		for arg in t.args
			res = res*term_to_string(arg)*","
		end
		res = res[1:end-1]*")"
		return res
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
function term_to_string(a :: TrueAtom)
	return "true"
end
function term_to_string(a :: FalseAtom)
	return "false"
end
function term_to_string(a :: LinearConstraint)
	if a.equality
		return string(a.coefficients)*"<="*string(a.bias)
	else
		return string(a.coefficients)*"<"*string(a.bias)
	end
end
function term_to_string(a :: LinearTerm)
	return string(a.coefficients)*"+"*string(a.bias)
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
	elseif op == AST.Neg
		return "-"
	elseif op == AST.Min
		return "min"
	elseif op == AST.Max
		return "max"
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

function term_to_string(o :: OverApprox)
	return "O("*term_to_string(o.formula)*")"
end

function term_to_string(o :: UnderApprox)
	return "U("*term_to_string(o.formula)*")"
end

function term_to_string(v :: NonLinearSubstitution)
	return "(N)" #term_to_string(v.term)
end

function term_to_string(a :: SemiLinearConstraint)
	nonlinearities = join([term_to_string(k.term)*"*"*string(c) for (k,c) in a.semilinears],",")
	if a.equality
		return string(a.coefficients)*"+N("*nonlinearities*")<="*string(a.bias)
	else
		return string(a.coefficients)*"+N("*nonlinearities*")<"*string(a.bias)
	end
end

function show(io::IO, p :: ParsedNode)
	print(io, term_to_string(p))
end