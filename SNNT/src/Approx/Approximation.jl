# For variable with index i=1
#x  Find all linear min/max expressions only involving variable i
#   For each such expression
#     Find splitting point of expression along i
#     Introduce new splitting point in bounds array at sorted position k
#     Duplicate term at position k-1 and insert at position k
#     For all terms j < k: Substitute with term1
#y     For all terms j >= k: Substitute with term2
# N = length of term vector

# For variables with index i=2...n
#   Duplicate terms array (deep copy)
#   Find all linear min/max expressions only involving variable i
#   For each such expression
#     Find splitting point of expression along i
#     Introduce new splitting point in bounds array at sorted position k
#     For all h=0... with h*N < length of term vector
#       Duplicate term at position h*N+k-1 and insert at position h*N+k
#       For all terms h*N<=j<h*N+k: Substitute with term1
#       For all terms h*N+k<=j<h*N+k+1: Substitute with term2
#       N++

function find_split_point(bounds :: Vector{Float64}, split_point :: Float64)
	lower = searchsortedlast(bounds, split_point)
	if lower < length(bounds) && bounds[lower+1]-EPSILON <= split_point
		lower += 1
	end
	upper = lower+1
	if lower < 1 || (lower==1 && abs(bounds[1]-split_point) < EPSILON)
		return (-1, 2)
	elseif lower >= length(bounds) || (lower == length(bounds) && abs(bounds[lower]-split_point) < EPSILON)
		return (-1, 1)
	elseif abs(bounds[lower]-split_point) < EPSILON
		return (-2, lower)
	elseif upper <= length(bounds) && abs(bounds[upper]-split_point) < EPSILON
		return (-2, upper)
	else
		@assert bounds[lower]-EPSILON <= split_point && split_point <= bounds[upper]+EPSILON
		return (lower, upper)
	end
end

function find_minmax_generic(cur_term :: Term, check; direction=AST.Upper)
	if cur_term isa CompositeTerm
		vars = true
		# TODO(steuber): next_dir is very memory inefficient!
		next_dir = nothing
		if cur_term.operation == AST.Add || cur_term.operation == AST.Min || cur_term.operation == AST.Max
			next_dir = map(x -> direction, cur_term.args)
		elseif cur_term.operation == AST.Sub
			next_dir = [direction;map(x -> flip(direction), cur_term.args[2:end])]
		elseif cur_term.operation == AST.Mul
			@assert length(cur_term.args) == 2
			args = cur_term.args
			f = identity
			if !(args[1] isa TermNumber)
				@assert args[2] isa TermNumber
				args = [args[2], args[1]]
				f = reverse
			end
			next_dir = f([direction, (args[1].value<0) ? flip(direction) : direction])
		elseif cur_term.operation == AST.Div
			@assert cur_term.args[2] isa TermNumber
			next_dir = [(cur_term.args[2].value<0) ? flip(direction) : direction, direction]
		else
			throw("Unexpected operator: "*string(cur_term.operation))
		end
		for (arg, cur_dir) in zip(cur_term.args,next_dir)
			argvars, argres, res_dir = find_minmax_generic(arg, check, direction=cur_dir)
			vars = vars && argvars
			if !isnothing(argres)
				return (vars, argres, res_dir)
			end
		end
		if vars && (operation(cur_term) == min || operation(cur_term) == max)
			#@debug "Found min/max: ", cur_term
			#@debug "Flip bound: ", direction != Upper
			return (true, cur_term, direction != Upper)
		else
			return (vars, nothing, false)
		end
	elseif cur_term isa Variable 
		if check(cur_term)
			return true, nothing, false
		else
			return false, nothing, false
		end
	else
		return true,nothing, false
	end
end

function find_minmax_internal(cur_term :: Term, i :: Int64)
	return find_minmax_generic(cur_term, v -> (v.position == i))
end

function find_any_inner_minmax(cur_term :: Term)
	return find_minmax_generic(cur_term, v -> true)
end

function find_univariate_minmax(cur_term, i)
	_, res, _ = find_minmax_internal(cur_term, i)
	if !isnothing(res)
		term1 = simplify(res.args[1])
		term2 = simplify(res.args[2])
		# term1 <= term2
		linear = make_linear(simplify(term1-term2), TermNumber(0.0), AST.LessEq, i)
		split_point = linear.bias / linear.coefficients[i]
		split_point = Float64(split_point)
		if operation(res) == (max) && linear.coefficients[i] > 0.0 || operation(res) == (min) && linear.coefficients[i] < 0.0
			(term1, term2) = (term2,term1)
		end
		#@assert split isa LinearConstraint
		#split_point = split.bias/split.coefficients[i]
		return term1, term2, split_point, res
	else
		return nothing
	end
end

# Either returns term1, term2 of some max(term1, term2)
# or returns -term1, -term2 of some min(term1, term2) = -max(-term1, -term2)
# or returns nothing
function find_multivariate_minmax(cur_term, var_num :: Int64)
	_, res, doflip = find_any_inner_minmax(cur_term)
	if !isnothing(res)
		c = (res.operation == AST.Min) ? -1.0 : 1.0
		term1 = simplify(res.args[1])
		term2 = simplify(res.args[2])
		# term1 <= term2
		linear1 = make_linear(term1, TermNumber(0.0), AST.LessEq, var_num)
		linear2 = make_linear(term2, TermNumber(0.0), AST.LessEq, var_num)
		linear1.coefficients .*= c
		linear2.coefficients .*= c
		linear_term1 = linear1.coefficients
		linear_term2 = linear2.coefficients
		bias1, bias2 = -c*linear1.bias, -c*linear2.bias
		return LinearTerm(linear_term1,bias1), LinearTerm(linear_term2,bias2), res, doflip
	else
		return nothing
	end
end




function resolve_univariate_minmax(approximation :: IncompleteApproximation)
	N = 1
	bounds = approximation.bounds
	# TODO(steuber): Comment out expensive sanity check (i.e. everything related to old)
	for i in length(bounds):-1:1
		cur_term = approximation.constraints[1]
		next_minmax = find_univariate_minmax(cur_term, i)
		while !isnothing(next_minmax)
			#old = deepcopy(approximation)
			term1, term2, split_point, original_term = next_minmax
			##@debug term2
			k_low, k_high = find_split_point(bounds[i], split_point)
			if k_low == -1 # Split outside bounds
				term = (k_high == 1) ? term1 : term2
				for j in 1:length(approximation.constraints)
					approximation.constraints[j] = substitute(approximation.constraints[j], Dict(original_term => term), fold=false)
				end
			elseif k_low == -2 # Split already there
				for j in 1:((k_high-1)*N)
					approximation.constraints[j] = substitute(approximation.constraints[j], Dict(original_term => term1),fold=false)
				end
				for j in (((k_high-1)*N)+1):length(approximation.constraints)
					approximation.constraints[j] = substitute(approximation.constraints[j], Dict(original_term => term2),fold=false)
				end
			else
				insert!(bounds[i], k_high, split_point)
				@assert bounds[i][k_low] <= bounds[i][k_high] && bounds[i][k_high] <= bounds[i][k_high+1]
				for j in 1:(k_low-1)*N
					approximation.constraints[j] = substitute(approximation.constraints[j], Dict(original_term => term1),fold=false)
				end
				for j in ((k_low+1)*N):length(approximation.constraints)
					approximation.constraints[j] = substitute(approximation.constraints[j], Dict(original_term => term2),fold=false)
				end
				terms = approximation.constraints[((k_low-1)*N+1):(k_low*N)]
				term_list1 = Term[]
				term_list2 = Term[]
				for t in terms
					push!(term_list1, substitute(t, Dict(original_term => term1),fold=false))
					push!(term_list2, substitute(t, Dict(original_term => term2),fold=false))
				end
				splice!(approximation.constraints,((k_low-1)*N+1):(k_low*N), [term_list1; term_list2])
			end
			#check_approx_equiv(old,approximation)
			# Find next splitting point
			cur_term = approximation.constraints[1]
			next_minmax = find_univariate_minmax(cur_term, i)
		end
		N *= (length(bounds[i])-1)
	end
	return approximation
end

function optimize_term(bounds :: Vector{Tuple{Float64,Float64}}, term :: LinearTerm)
	x_min = map(
		(x) -> (x[2]>=0) ? x[1][1] : x[1][2],
		zip(bounds, term.coefficients)
	)
	x_max = map(
		(x) -> (x[2]>=0) ? x[1][2] : x[1][1],
		zip(bounds, term.coefficients)
	)
	# TODO(steuber): Apparently this line costs a lot of memory allocation?
	return ((dot(x_min, term.coefficients) + term.bias),x_min), ((dot(x_max, term.coefficients) + term.bias),x_max)

end

function resolve_or_approx(op :: AST.Operation, bounds :: Vector{Tuple{Float64,Float64}}, term1 :: LinearTerm, term2 :: LinearTerm, bound_direction :: BoundType)
	split_hyperplane = term1.coefficients-term2.coefficients
	split_bias = term1.bias-term2.bias
	# max {term1-term2} <= 0 => max(term1,term2) = term2
	# min {term1-term2} >= 0 => max(term1,term2) = term1
	# else: approximation necessary
	split_term = LinearTerm(split_hyperplane, split_bias)
	(split_min, xg), (split_max, xf) = optimize_term(bounds, split_term)
	#@debug "Bounds:"
	#@debug bounds
	if split_max <= 0.0
		#@debug "No need for approximation, returning "
		#@debug term2
		return term2
	elseif split_min >= 0.0
		#@debug "No need for approximation, returning "
		#@debug term1
		return term1
	else
		# Do approximation
		if bound_direction == AST.Lower
			#@debug "Generating lower bound"
			return LinearTerm(0.5*term1.coefficients + 0.5*term2.coefficients, 0.5*term1.bias + 0.5*term2.bias)
		else
			#@debug "Generating upper bound"
			fxf = dot(xf, term1.coefficients) + term1.bias
			fxg = dot(xg, term1.coefficients) + term1.bias
			gxf = dot(xf, term2.coefficients) + term2.bias
			gxg = dot(xg, term2.coefficients) + term2.bias
			mu = rationalize(Int128,-(gxf - fxf)/(fxf-fxg-gxf+gxg))
			c = rationalize(Int128,-(fxf-gxf)*(fxg-gxg)/(fxf-fxg-gxf+gxg))
			#@debug "C: ",c
			#@debug "Bias: ",mu*term1.bias + (1-mu)*term2.bias+c
			return LinearTerm(mu*term1.coefficients + (1-mu)*term2.coefficients, mu*term1.bias + (1-mu)*term2.bias+c)
		end
	end
end

function resolve_multivariate_minmax(approximation :: IncompleteApproximation, bound_direction_overall :: BoundType)
	for (i, cur_bounds) in enumerate(bounds_iterator(approximation.bounds))
		next_minmax = find_multivariate_minmax(approximation.constraints[i], length(approximation.bounds))
		while !isnothing(next_minmax)
			bound_direction = bound_direction_overall
			term1, term2, res, doflip = next_minmax
			if doflip
				bound_direction = flip(bound_direction)
			end
			function_symbol = res.operation
			if function_symbol == AST.Min
				bound_direction = flip(bound_direction)
			end
			new_term = resolve_or_approx(function_symbol, cur_bounds, term1, term2, bound_direction)
			# TODO(steuber): Actually produce term
			if function_symbol == AST.Min
				new_term.coefficients .*= -1.0
				new_term = LinearTerm(new_term.coefficients, -new_term.bias)
			end
			#@debug "Results in new term: "
			#@debug new_term
			approximation.constraints[i] = substitute(approximation.constraints[i], Dict(res => new_term),fold=false)
			#@debug "After substitution"
			#@debug AST.term_to_string(simplify(approximation.constraints[i]))
			next_minmax = find_multivariate_minmax(approximation.constraints[i],length(approximation.bounds))
		end
	end
	for i in 1:length(approximation.constraints)
		linear = make_linear(simplify(approximation.constraints[i]), TermNumber(0.0), AST.LessEq, length(approximation.bounds))
		approximation.constraints[i] = LinearTerm(linear.coefficients, -linear.bias)
	end
	return approximation
end

function resolve_approximation(approximation :: IncompleteApproximation, bound_direction :: BoundType)
	#@info "Simplifying"
	approximation.constraints[1] = simplify(approximation.constraints[1])
	#@info "Resolving univariate"
	approx_step_1 = resolve_univariate_minmax(approximation)
	#@info "Simplifying"
	#for i in 1:length(approximation.constraints)
	#	approximation.constraints[i] = simplify(approximation.constraints[i])
	#end
	#@info "Resolving multivariate"
	approx_step_2 = resolve_multivariate_minmax(approx_step_1, bound_direction)
	return Approximation(approx_step_2.bounds, convert(Vector{LinearTerm},approx_step_2.constraints))
end

# For each set of intervals I_0, I_1, ..., I_n
# Overapproximate the corresponding term and safe it as array of coefficients