function not_division(x :: Term)
	return !(x isa CompositeTerm) || operation(x) != (/) && (!istree(x) || all(y->not_division(y), arguments(x)))
end

function _isone(x :: Term)
	return x isa TermNumber && isone(x.value)
end

function _iszero(x :: Term)
	return x isa TermNumber && iszero(x.value)
end

function _istwo(x :: Term)
	return x isa TermNumber && x.value == 2
end

function _isnotzero(x :: Term)
	return !_iszero(x)
end

function _istrue(x :: Formula)
	return x isa TrueAtom
end

function _isfalse(x :: Formula)
	return x isa FalseAtom
end

function is_literal_number(x :: Term)
	return x isa TermNumber
end

function is_linear(f :: Atom)
	return f.right isa TermNumber && is_linear(f.left)
end
function is_linear(f :: Term)
	if f isa TermNumber || f isa Variable
		return true
	elseif f.operation == AST.Mul && length(f.args) == 2
		return f.args[1] isa TermNumber && f.args[2] isa Variable
	elseif f.operation == AST.Add
		return all(is_linear, f.args)
	else
		return false
	end
end

function get_num_cases(bounds :: AbstractArray{Vector{Float64}})
	return reduce(*, map(x -> length(x)-1, bounds))
end

function get_bounds_by_id(id :: Int64, bounds :: AbstractArray{Vector{Float64}})
	num_remaining = get_num_cases(bounds)
	@assert 1 <= id && id <= num_remaining
	id = id-1
	bound_res = Vector{Tuple{Float64, Float64}}()
	for (i,cur_bound) in enumerate(bounds)
		num_remaining = div(num_remaining, length(cur_bound)-1)
		cur_i = div(id, num_remaining)+1
		push!(bound_res, (cur_bound[cur_i], cur_bound[cur_i+1]))
		id = mod(id, num_remaining)
	end
	return bound_res
end

function get_position(bounds :: Vector{Float64}, x :: Float64)
	j = searchsortedlast(bounds, x)
	if j == length(bounds) && x <= bounds[j]
		return j-1
	else
		return j
	end
end

function get_linear_term(bounds :: Vector{Tuple{Float64,Float64}}, approx :: Approximation)
	pos = get_linear_term_position(approx, bounds)
	return approx.linear_constraints[pos]
end

function get_linear_term_position(approximation :: ApproximationPrototype, bounds :: Vector{Tuple{Float64, Float64}})
	pos = 0
	for (i, b) in enumerate(bounds)
		pos*= length(approximation.bounds[i])-1
		@assert approximation.bounds[i][1]-Config.EPSILON <= b[1] && b[2] <= approximation.bounds[i][length(approximation.bounds[i])]+Config.EPSILON ("Mismatch between searched bound "*string(b)*" and approximation bound "*string(approximation.bounds[i])*" for dimension "*string(i))
		j = get_position(approximation.bounds[i], b[1])
		@assert b[2] <= approximation.bounds[i][j+1]+Config.EPSILON
		pos += j-1
	end
	return pos+1
end