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

EPSILON=1e-3

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

function find_minmax_internal(cur_term, i)
	if istree(cur_term)
		vars = true
		for arg in arguments(cur_term)
			argvars, argres = find_minmax_internal(arg, i)
			vars = vars && argvars
			if !isnothing(argres)
				return (vars, argres)
			end
		end
		if vars && (operation(cur_term) == min || operation(cur_term) == max)
			return (true, cur_term)
		else
			return (vars, nothing)
		end
	elseif cur_term isa Variable 
		if cur_term.position == i
			return true, nothing
		else
			return false, nothing
		end
	else
		return true,nothing
	end
end

function get_split(atom :: Atom)
	@assert atom.comparator == AST.LessEq
	@assert atom.right isa TermNumber
	if atom.left isa Variable
		return atom.right.value
	else
		bias = atom.right.value
		if operation(atom.left) == (*)
			@assert length(atom.left.args) == 2
			a = atom.left.args[1]
			b = atom.left.args[2]
			if a isa Variable
				return bias/b.value
			else
				@assert b isa Variable
				return bias/a.value
			end
		else
			@assert istree(atom) && operation(atom.left) == (+)
			@assert length(atom.left.args) == 2
			a = atom.left.args[1]
			b = atom.left.args[2]
			x = nothing
			if a isa TermNumber
				bias = bias - a.value
				x = b
			else
				@assert b isa TermNumber
				bias = bias - b.value
				x=a
			end
			if x isa Variable
				return bias
			else
				@assert istree(x) && operation(x) == (*) && length(x.args) == 2
				a = x.args[1]
				b = x.args[2]
				if a isa Variable
					return bias/b.value
				else
					@assert b isa Variable
					return bias/a.value
				end
			end
		end
	end
end


function find_minmax(cur_term, i)
	_, res = find_minmax_internal(cur_term, i)
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


function resolve_univariate_minmax(approximation :: IncompleteApproximation)
	N = 1
	bounds = approximation.bounds
	# TODO(steuber): Comment out expensive sanity check (i.e. everything related to old)
	for i in length(bounds):-1:1
		cur_term = approximation.constraints[1]
		next_minmax = find_minmax(cur_term, i)
		while !isnothing(next_minmax)
			old = deepcopy(approximation)
			term1, term2, split_point, original_term = next_minmax
			#@debug term2
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
			next_minmax = find_minmax(cur_term, i)
		end
		N *= (length(bounds[i])-1)
	end
	return approximation
end

function resolve_multivariate_minmax(approximation :: IncompleteApproximation, bound_direction :: BoundType)

end

function resolve_approximation(approximation :: IncompleteApproximation, bound_direction :: BoundType)
	approx_step_1 = resolve_univariate_minmax(approximation)
	approx_step_2 = resolve_multivariate_minmax(approx_step_1, bound_direction)
	return approx_step_1
end

# For each set of intervals I_0, I_1, ..., I_n
# Overapproximate the corresponding term and safe it as array of coefficients