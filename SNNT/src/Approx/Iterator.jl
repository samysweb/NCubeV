import Base.iterate

function bounds_iterator(bounds :: Vector{Vector{Float64}})
	return map(x->collect( b for b in reverse(x)),
		Iterators.product(
			map(x -> zip(x,x[2:end]),
				# First iterator changes the fastest -> reverse direction of bounds
				reverse(bounds)
			)...
		)
	)
end

function iterate(approx :: ApproxNormalizedQuery, state)
	iter = state[1]
	iter_res = iterate(iter, state[2])
	if isnothing(iter_res)
		return nothing
	else
		return iter_res[1], (iter, iter_res[2])
	end
end

function iterate(approx :: ApproxNormalizedQuery)
	iter = map(b-> generate_conjunction(approx, b), bounds_iterator(approx.input_bounds))
	iter_res = iterate(iter)
	if isnothing(iter_res)
		return nothing
	else
		return iter_res[1], (iter, iter_res[2])
	end
end

function get_linear_term(bounds :: Vector{Tuple{Float64,Float64}}, approx :: Approximation)
	pos = get_linear_term_position(approx, bounds)
	return approx.linear_constraints[pos]
end

function generate_linear_constraint(bounds :: Vector{Tuple{Float64, Float64}}, semi :: SemiLinearConstraint, approximations :: Dict{ApproxQuery,Approximation},startpos,endpos)
	coefficients = map(Float32,semi.coefficients[startpos:endpos])
	bias = semi.bias
	for (query, coeff) in semi.semilinears
		linear_term = get_linear_term(bounds, approximations[query])
		@debug "Linear term: ", linear_term
		@debug "Coefficients before: ", coefficients
		coefficients[:] += coeff * map(Float32,linear_term.coefficients[startpos:endpos])
		@debug "Coefficients after: ", coefficients
		bias -= coeff * linear_term.bias
	end
	return coefficients, bias
end

function generate_conjunction(approx :: ApproxNormalizedQuery, bounds :: Vector{Tuple{Float64, Float64}})
	num_input_vars = length(approx.input_bounds)
	num_output_vars = length(approx.output_bounds)
	num_linear_input_constraints = length(approx.nonlinear_query.input_linear)
	num_input_constraints = num_linear_input_constraints+length(approx.nonlinear_query.input_nonlinear)
	input_matrix = Matrix{Float32}(undef, num_input_constraints, num_input_vars)
	input_bias = Vector{Float32}(undef, num_input_constraints)
	for (i,li) in enumerate(approx.nonlinear_query.input_linear)
		@debug "Matrix line before insertion: ", input_matrix[i,:]
		@debug "Coefficients: ", li.coefficients[1:num_input_vars]
		input_matrix[i,:] = map(Float32,li.coefficients[1:num_input_vars])
		@debug "Matrix line after insertion: ", input_matrix[i,:]
		input_bias[i] = li.bias
	end
	for (i,ni) in enumerate(approx.nonlinear_query.input_nonlinear)
		@debug "Matrix line before insertion: ", input_matrix[i+num_linear_input_constraints,:]
		input_matrix[num_linear_input_constraints+i,:], input_bias[num_linear_input_constraints+i] = generate_linear_constraint(bounds, ni, approx.approximations,1,num_input_vars)
		@debug "Matrix line after insertion: ", input_matrix[i+num_linear_input_constraints,:]
	end
	output_disjunction = Vector{Tuple{Matrix{Float32},Vector{Float32}}}()
	for output_bound in bounds_iterator(approx.output_bounds)
		all_bounds = [bounds; output_bound]
		for output_conjunction in approx.nonlinear_query.mixed_constraints
			num_linear_output_constraints = length(output_conjunction[1])+2*num_output_vars
			num_output_constraints = num_linear_output_constraints + length(output_conjunction[2])
			output_matrix = Matrix{Float32}(undef, num_output_constraints, num_input_vars+num_output_vars)
			output_bias = Vector{Float32}(undef, num_output_constraints)
			@debug "OUTPUT with ", num_output_constraints, " constraints (", num_linear_output_constraints, " linear, ", length(output_conjunction[2]), " nonlinear)"
			for (i,(blow,bhigh)) in enumerate(output_bound)
				output_matrix[2*i-1,:] .= 0.
				output_matrix[2*i,:] .= 0.
				output_matrix[2*i-1,num_input_vars+i] = 1.
				output_matrix[2*i,num_input_vars+i] = -1.
				output_bias[2*i-1] = bhigh+EPSILON
				output_bias[2*i] = -blow+EPSILON
			end
			for (i,li) in enumerate(output_conjunction[1])
				output_matrix[2*num_output_vars+i,:] = map(Float32,li.coefficients[1:num_input_vars+num_output_vars])
				output_bias[2*num_output_vars+i] = li.bias
			end
			for (i,ni) in enumerate(output_conjunction[2])
				@debug "Adding nonlinear constraint"
				output_matrix[num_linear_output_constraints+i,:], output_bias[num_linear_output_constraints+i] = generate_linear_constraint(all_bounds, ni, approx.approximations,1,num_input_vars+num_output_vars)
			end
			push!(output_disjunction, (output_matrix, output_bias))
		end
	end
	bounds = map(b -> (b[1]-EPSILON, b[2]+EPSILON), bounds)
	return (bounds, (input_matrix, input_bias), output_disjunction)
end