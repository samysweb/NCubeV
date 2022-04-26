function evaluate(x :: Vector{Float64}, approximation :: IncompleteApproximation)
	pos = 0
	subst = Dict{Term,Term}()
	for (i,x_i) in enumerate(x)
		pos *= length(approximation.bounds[i])-1
		@assert approximation.bounds[i][1] <= x_i && x_i <= approximation.bounds[i][length(approximation.bounds[i])]
		j = get_position(approximation.bounds[i], x_i)
		pos += j-1
		subst[Variable("x"*string(i))] = TermNumber(x_i)
	end
	try
		return simplify(substitute(approximation.constraints[pos+1], subst, fold=false)).value
	catch e
		@assert false
	end
end

function get_position(bounds :: Vector{Float64}, x :: Float64)
	j = searchsortedlast(bounds, x)
	if j == length(bounds) && x <= bounds[j]
		return j-1
	else
		return j
	end
end

function check_approx_equiv_internal(bounds, old, new, x :: Vector{Float64})
	if length(x) == length(new.bounds)
		if !(abs(Float64(evaluate(x,old))-Float64(evaluate(x,new))) < 1e-1)
			@error "Approximation is not equivalent"
			@error "Old: ", Float64(evaluate(x,old))
			@error "New: ", Float64(evaluate(x,new))
			@error "Old: ", old
			@error "New: ", new
			@error "X: ", x
			@assert false
		end
	else
		for (x_i1,x_i2) in zip(bounds[1], bounds[1][2:end])
			check_approx_equiv_internal(bounds[2:end], old, new, [x;(Float64(x_i1)+Float64(x_i2))/2.0])
		end
	end
end

function check_approx_equiv(old :: IncompleteApproximation, new :: IncompleteApproximation)
	# Note that this is not a full equivalence check, but only checks on certain points...
	check_approx_equiv_internal(deepcopy(new.bounds),old,new,Float64[])
end