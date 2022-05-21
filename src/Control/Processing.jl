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
	approx_cache :: ApproxCache = ApproxCache()
	println("[CTRL] Iterating over conjunctions...")
	results = []
	for current_conjunction in query
		println("[CTRL] Considering conjunction with ",
			length(current_conjunction.input_constraints.linear_constraints)+length(current_conjunction.input_constraints.semilinear_constraints),
			" input constraints and a disjunction of size ",length(current_conjunction.mixed_constraints))
		#@info "Input Constraints:",current_conjunction.input_constraints
		#@info "Mixed:"
		#for mixed in current_conjunction.mixed_constraints
		#	@info mixed
		#end
		approx_normalized :: ApproxNormalizedQueryPrototype{Approximation} = get_approx_normalized_query(current_conjunction, approx_cache)
		#@info "Initiating iterator"
		for linear_query in approx_normalized
			push!(results,f(linear_query))
		end
	end
	return results
end