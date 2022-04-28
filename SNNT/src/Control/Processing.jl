function load_query(file::String,
						fixed_variables::Dict{String, Union{String, Number}},
						mapping::Dict{String, Tuple{AST.VariableType, Int64}})
	# Load the problem
	constraints :: Formula  = Parsing.parse_constraint(file)
	# Fix the variables
	constraints_fixed_vars :: Formula  = fix_variables(constraints, fixed_variables)
	# Get the variables
	variable_set :: Set{Variable}, constraints_updated_vars :: Formula = map_variables(constraints_fixed_vars,mapping)

	# Translate the constraints to linear (LinearConstraint)/nonlinear (remains Atom)
	constraints_translated_constraints :: Formula = translate_constraints(constraints_updated_vars, variable_set)
	
	return Query(AST.simplify(constraints_translated_constraints), variable_set)
end

function prepare_for_olnnv(query :: Query)
	formula = query.formula
	variable_set = query.variables
	underapprox_formula :: Formula = get_underapprox(formula)
	# We are looking for counter-examples so we use the negation...
	olnnv_formula = CompositeFormula(Not,[underapprox_formula])
	return Query(olnnv_formula, variable_set)
end

function run_query(f, query :: Query)
	for current_conjunction in query
		approx_normalized = get_approx_normalized_query(current_conjunction)
		for linear_query in approx_normalized
			f(linear_query)
		end
	end
end