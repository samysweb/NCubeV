import Base.iterate

function bounds_iterator(bounds :: AbstractArray{Vector{Float64}};limit_bounds :: Union{Nothing,Vector{Tuple{Float64, Float64}}}=nothing)
	#TODO(steuber): This should be possible without any memory allocation
	if isnothing(limit_bounds)
		used_bounds = bounds
	else
		used_bounds = Vector{Vector{Float64}}()
		for (i,cur_bound) in enumerate(bounds)
			if i <= length(limit_bounds)
				push!(used_bounds,
					filter(x -> limit_bounds[i][1]-EPSILON <= x && x <= limit_bounds[i][2]+EPSILON, cur_bound))
			else
				push!(used_bounds, cur_bound)
			end
		end
	end
	return Iterators.map(x->collect( b for b in reverse(x)),
			Iterators.product(
				map(x -> zip(x,(@view x[2:end])),
					# First iterator changes the fastest -> reverse direction of bounds
					reverse(used_bounds)
				)...
			)
		)
end

function iterate(approx :: ApproxNormalizedQueryPrototype{Approximation}, state)
	iter = state[1]
	iter_res = iterate(iter, state[2])
	if isnothing(iter_res)
		return nothing
	else
		return iter_res[1], (iter, iter_res[2])
	end
end

function iterate(approx :: ApproxNormalizedQueryPrototype{Approximation})
	return @timeit Config.TIMER "olnnv_query_gen" begin
		all_bounds = [approx.input_bounds;approx.output_bounds]
		# Initialization...
		init_pwl_bounds(approx.nonlinear_query.input_constraints, approx.approximations, all_bounds)
		for output_conjunciton in approx.nonlinear_query.mixed_constraints
			for (i, cur_bounds) in enumerate(approx.nonlinear_query.input_constraints.bounds)
				@inbounds append!(output_conjunciton.bounds[i],cur_bounds)
			end
			init_pwl_bounds(output_conjunciton, approx.approximations, all_bounds)
			#@info "Initialized bounds for disjunction: ", output_conjunciton.bounds
		end
		# Iterator...
		num_inputs = length(approx.input_bounds)
		iter = Iterators.filter( query -> !LP.is_infeasible(query.bounds, query.input_matrix, query.input_bias) ,
			Iterators.map(b-> generate_conjunction(approx, b), bounds_iterator(
				(@view approx.nonlinear_query.input_constraints.bounds[1:num_inputs])
			))
		)
		iter_res = iterate(iter)
		if isnothing(iter_res)
			return nothing
		else
			return iter_res[1], (iter, iter_res[2])
		end
	end
end

function generate_linear_constraint(
	coefficient_matrix :: Matrix{Float32}, bias_vector :: Vector{Float32}, row :: Int64,
	bounds :: Vector{Tuple{Float64, Float64}}, semi :: SemiLinearConstraint, approximations :: Dict{ApproxQuery,Approximation},startpos,endpos)
	coefficient_matrix[row,:] .= 0.0
	bias_vector[row] = epsilon
	
	coefficient_matrix[row,startpos:endpos] .= round_minimize.(@view semi.coefficients[startpos:endpos])
	bias_vector[row] = semi.bias
	for (query, coeff) in semi.semilinears
		linear_term = get_linear_term(bounds, approximations[query])
		#@debug "Linear term: ", linear_term
		#@debug "Coefficients before: ", coefficient_matrix[row,startpos:endpos]
		coefficient_matrix[row,startpos:endpos] .+= round_minimize.(coeff .* @view linear_term.coefficients[startpos:endpos])
		#@debug "Coefficients after: ", coefficient_matrix[row,startpos:endpos]
		bias_vector[row] -= round_maximize(coeff * linear_term.bias)
	end
end

function generate_conjunction(approx :: ApproxNormalizedQueryPrototype{Approximation}, bounds :: Vector{Tuple{Float64, Float64}})
	num_input_vars = length(approx.input_bounds)
	num_output_vars = length(approx.output_bounds)
	num_linear_input_constraints = length(approx.nonlinear_query.input_constraints.linear_constraints)
	num_input_constraints = num_linear_input_constraints+length(approx.nonlinear_query.input_constraints.semilinear_constraints)
	input_matrix = Matrix{Float32}(undef, num_input_constraints, num_input_vars)
	input_bias = Vector{Float32}(undef, num_input_constraints)
	for (i,li) in enumerate(approx.nonlinear_query.input_constraints.linear_constraints)
		@inbounds input_matrix[i,:] .= round_minimize.(@view li.coefficients[1:num_input_vars])
		#@debug "Matrix line after insertion: ", input_matrix[i,:]
		@inbounds input_bias[i] = round_maximize(li.bias)
	end
	for (i,ni) in enumerate(approx.nonlinear_query.input_constraints.semilinear_constraints)
		#@debug "Matrix line before insertion: ", input_matrix[i+num_linear_input_constraints,:]
		generate_linear_constraint(
			input_matrix, input_bias, num_linear_input_constraints+i,
			bounds, ni, approx.approximations,1,num_input_vars)
		#@debug "Matrix line after insertion: ", input_matrix[i+num_linear_input_constraints,:]
	end
	output_disjunction = Vector{Tuple{Matrix{Float32},Vector{Float32}}}()
	#@debug "Considering bounds ", bounds
	for output_conjunction in approx.nonlinear_query.mixed_constraints
		#@debug "|- Considering output conjunction: ", output_conjunction
		for all_bounds in bounds_iterator(output_conjunction.bounds;limit_bounds=bounds)
			#@debug "|-- Considering bounds: ", all_bounds
			num_linear_output_constraints = length(output_conjunction.linear_constraints)+2*length(all_bounds)
			num_output_constraints = num_linear_output_constraints + length(output_conjunction.semilinear_constraints)
			output_matrix = Matrix{Float32}(undef, num_output_constraints, num_input_vars+num_output_vars)
			output_bias = Vector{Float32}(undef, num_output_constraints)
			#@debug "OUTPUT with ", num_output_constraints, " constraints (", num_linear_output_constraints, " linear, ", length(output_conjunction.semilinear_constraints), " nonlinear)"
			for (i,(blow,bhigh)) in enumerate(all_bounds)
				#@info "Placing bounds for dimension ",i," at ",2*i-1," and ",2*i," at column ",i," blow,bhigh: ",blow,",",bhigh
				high_epsilon = true
				low_epsilon = true
				min_low = (i<=num_input_vars) ? approx.input_bounds[i][1] : approx.output_bounds[i-num_input_vars][1]
				max_high = (i<=num_input_vars) ? approx.input_bounds[i][end] : approx.output_bounds[i-num_input_vars][end]
				if blow == min_low
					high_epsilon = false
				end
				if bhigh == max_high
					low_epsilon = false
				end
				@inbounds output_matrix[2*i-1,:] .= 0.
				@inbounds output_matrix[2*i,:] .= 0.
				@inbounds output_matrix[2*i-1,i] = 1.
				@inbounds output_matrix[2*i,i] = -1.
				@inbounds output_bias[2*i-1] = bhigh+((high_epsilon) ? EPSILON : 0.)
				@inbounds output_bias[2*i] = -blow+((low_epsilon) ? EPSILON : 0.)
			end
			for (i,li) in enumerate(output_conjunction.linear_constraints)
				@inbounds output_matrix[2*length(all_bounds)+i,:] .= round_minimize.(@view li.coefficients[1:num_input_vars+num_output_vars])
				@inbounds output_bias[2*length(all_bounds)+i] = round_maximize(li.bias)
			end
			for (i,ni) in enumerate(output_conjunction.semilinear_constraints)
				#@debug "Adding nonlinear constraint"
				generate_linear_constraint(
					output_matrix, output_bias, num_linear_output_constraints+i,
					all_bounds, ni, approx.approximations,1,num_input_vars+num_output_vars)
			end
			push!(output_disjunction, (output_matrix, output_bias))
		end
	end
	print_msg("[APPROX] # Conjunctions over output: ", length(output_disjunction))
	query_bounds = []
	for (i,(b1,b2)) in enumerate(bounds)
		b1_res = b1
		b2_res = b2
		if b1 != approx.input_bounds[i][1]
			b1_res -=EPSILON
		end
		if b2 != approx.input_bounds[i][end]
			b2_res += EPSILON
		end
		push!(query_bounds, (b1_res,b2_res))
	end
	res =  OlnnvQuery(query_bounds, input_matrix, input_bias, output_disjunction)
	return res
end