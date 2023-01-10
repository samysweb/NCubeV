function get_approx_nodes(formula :: Formula, approx_requests :: Set{ApproxQuery}, num_vars :: Int64)
	@match formula begin
		CompositeFormula(_, args, _) => begin
			new_args = Formula[]
			for arg in args
				push!(new_args,get_approx_nodes(arg, approx_requests, num_vars))
			end
			return CompositeFormula(formula.connective, new_args)
		end
		LinearConstraint(_, _, _) => return formula
		OverApprox(f,_,_) || UnderApprox(f,_,_) => begin
			@assert f.comparator == AST.Less || f.comparator == AST.LessEq
			@assert AST._iszero(f.right)
			queries, under_approx = handle_nonlinearity(AST.Upper, f.left)
			under_approx_f = make_linear(under_approx, f.right, f.comparator, num_vars)
			union!(approx_requests, queries)
			queries, over_approx = handle_nonlinearity(AST.Lower, f.left)
			over_approx_f = make_linear(over_approx, f.right, f.comparator, num_vars)
			union!(approx_requests, queries)
			@assert !isnothing(under_approx_f) && !isnothing(over_approx_f)
			return (typeof(formula))(f, under_approx_f, over_approx_f)
		end
		_ => error("Unknown formula type ", typeof(formula))
	end
end

function get_approx_query(initial_query :: Query)
	return @timeit Config.TIMER "get_approx_query" begin
		@assert initial_query.formula.connective == AST.And
		print_msg("[APPROX] Trying to build approximation...")
		linear_constraints = Vector{LinearConstraint}()
		for arg in initial_query.formula.args
			if arg isa LinearConstraint
				push!(linear_constraints, arg)
			end
		end
		num_vars = initial_query.num_input_vars + initial_query.num_output_vars
		query_approximations = Dict{ApproxQuery, Approximation}()
		query_bounds = Vector{Vector{Float64}}()
		model = get_model(linear_constraints)
		for i in 1:num_vars
			low = optimize_dim(i, -1.0, model)
			high = optimize_dim(i, 1.0, model)
			push!(query_bounds, [low, high])
		end
		approx_queries = Set{ApproxQuery}()
		# TODO(steuber): approx_node treatment
		new_formula = get_approx_nodes(initial_query.formula,approx_queries, num_vars)
		approxs_by_term = Dict{Term, Vector{BoundType}}()
		for approx_query in approx_queries
			if !haskey(approxs_by_term, approx_query.term)
				approxs_by_term[approx_query.term] = Vector{BoundType}()
			end
			push!(approxs_by_term[approx_query.term], approx_query.bound)
		end
		incomplete_approximations = construct_approx(approxs_by_term, query_bounds)
		for (approx_query, incomplete_approx) in incomplete_approximations
			new_approx = resolve_approximation(incomplete_approx, approx_query.bound)
			if Config.RIGOROUS_APPROXIMATIONS
				verify_approximation(approx_query, new_approx)
			else
				print_msg("[APPROX] Skipping verification of approximation (switch on using SNNT.Config.set_rigorous_approximations(true))")
			end
			query_approximations[approx_query] = new_approx
			for i in 1:num_vars
				query_bounds[i] = union(query_bounds[i], new_approx.bounds[i])
			end
		end
		map(x->sort!(x),query_bounds)
		filter_bounds_inplace(query_bounds)
		print_msg("[APPROX] Approximation Bounds: ", initial_query.bounds)
		print_msg("[APPROX] Approximations: ", initial_query.approximations)
		print_msg("[APPROX] Approximation is ready")
		return Query(
				new_formula,
				initial_query.variables,
				query_approximations,
				query_bounds)
	end
end

function get_approx_normalized_query(initial_query :: NormalizedQuery, approx_cache :: ApproxCache)
	bounds = map(x->(x[1],x[end]), initial_query.input_bounds)
	append!(bounds, map(x->(x[1],x[end]), initial_query.output_bounds))
	ready_approximations = Dict{ApproxQuery, Approximation}()
	print_msg("[APPROX] Checking cache: ",[k for (k,v) in approx_cache])
	for (approx_term,all_bound_types) in initial_query.approx_queries
		cur_bounds = generate_bounds(approx_term, bounds)
		needed_bound_types = []
		for bound_type in all_bound_types
			cache_needle = ApproxCacheObject(ApproxQuery(bound_type, approx_term), cur_bounds)
			if haskey(approx_cache,cache_needle)
				print_msg("[APPROX] Reusing approximation for query: ", cache_needle)
				update_bounds(approx_term, bounds, approx_cache[cache_needle].bounds)
				ready_approximations[cache_needle.query] = approx_cache[cache_needle]
				delete!(initial_query.approx_queries, approx_term)
			else
				print_msg("[APPROX] Not found: ", cache_needle)
				push!(needed_bound_types, bound_type)
			end
		end
		if length(needed_bound_types) == 0
			delete!(initial_query.approx_queries, approx_term)
		else
			initial_query.approx_queries[approx_term] = needed_bound_types
		end
	end
	print_msg("[APPROX] Constructing Approximation")
	incomplete_query=ApproxNormalizedQueryPrototype{IncompleteApproximation}(initial_query)
	print_msg("[APPROX] Resolving approximation")
	for (approx_query, incomplete_approx) in incomplete_query.approximations
		new_approx = resolve_approximation(incomplete_approx, approx_query.bound)
		if Config.RIGOROUS_APPROXIMATIONS
			verify_approximation(approx_query, new_approx)
		else
			print_msg("[APPROX] Skipping verification of approximation (switch on using SNNT.Config.set_rigorous_approximations(true))")
		end
		ready_approximations[approx_query] = new_approx
		cur_bounds = generate_bounds(approx_query.term, bounds)
		cache_needle = ApproxCacheObject(approx_query, cur_bounds)
		approx_cache[cache_needle] = new_approx
	end
	return ApproxNormalizedQueryPrototype{Approximation}(incomplete_query, ready_approximations)
end

function generate_bounds(term :: Term, bounds :: Vector{Tuple{Float64,Float64}})
	variables = sort!(get_variable_positions(term))
	return bounds[variables]
end

function get_variable_positions(term :: Term)
	@match term begin
		Variable(_,_,pos) => return [pos]
		TermNumber(_) => return []
		CompositeTerm(op, args,_) => begin
			positions = []
			for arg in args
				append!(positions, get_variable_positions(arg))
			end
			return positions
		end
		_ => throw("Unexpected term type"*string(typeof(term)))
	end
end

function update_bounds(term :: Term, given_bounds :: Vector{Tuple{Float64,Float64}}, bounds :: Vector{Vector{Float64}})
	variables = sort!(get_variable_positions(term))
	for (i,b) in enumerate(given_bounds)
		if !(i in variables)
			bounds[i] = Float64[b[1],b[2]]
		end
	end
end