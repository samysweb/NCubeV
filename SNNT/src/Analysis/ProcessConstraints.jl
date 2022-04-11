function get_variables(x :: CompositeFormula)
	variables = nothing
	for arg in x.args
		found_variables = get_variables(arg)
		if isnothing(variables)
			variables = found_variables
		else
			variables = union!(variables, found_variables)
		end
	end
	return variables
end
function get_variables(x :: Atom)
	variables = get_variables(x.left)
	variables = union!(variables, get_variables(x.right))
	return variables
end
function get_variables(x :: CompositeTerm)
	variables = nothing
	for arg in x.args
		found_variables = get_variables(arg)
		if isnothing(variables)
			variables = found_variables
		else
			variables = union!(variables, found_variables)
		end
	end
	return variables
end
function get_variables(x :: Variable)
	return Set{Variable}([x])
end
function get_variables(x :: TermNumber)
	return Set{Variable}()
end

function fix_variables(f :: Formula, mapping::Dict{String, Union{String, Number}})
	replacement_map = Dict{Variable, Term}()
	for (k, v) in mapping
		if v isa String
			replacement_map[Variable(k)] = Variable(v)
		else
			replacement_map[Variable(k)] = TermNumber(v)
		end
	end
	return simplify(substitute(f, replacement_map, fold=false))
end