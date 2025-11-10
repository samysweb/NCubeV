#
# NCubeV OVERT integration — extracting PWL bounds (Appendix B.1)
#
"""
    get_val_ranges(offset::Int, bounds::Vector{Vector{Float64}}) -> Dict{Symbol,Vector{Float64}}

Construct value ranges for OVERT variables `x1, x2, …` with `offset` applied to
the index base. Used when building OVERT approximation problems for given grids.
"""
function get_val_ranges(offset :: Int64, bounds :: Vector{Vector{Float64}})
	val_ranges = Dict{Symbol, Array{Float64, 1}}()
	for (i, bound) in enumerate(bounds)
		val_ranges[Symbol("x"*string(offset+i))] = bound
	end
	return val_ranges
end

"""
    construct_approx(approx_queries, bounds) -> Dict{ApproxQuery,IncompleteApproximation}

Build initial piece-wise linear expressions for each `ApproxQuery` using OVERT,
then wrap them as `IncompleteApproximation`s to be further resolved by
`resolve_approximation`.

Implements the approximation backbone for Definition 5 (Appendix B.1).
"""
function construct_approx(approx_queries :: Dict{Term, Vector{BoundType}}, bounds :: Vector{Vector{Float64}})
	approximations = Dict{ApproxQuery, IncompleteApproximation}()
	for (approx_term, bound_types) in approx_queries
		print_msg("[APPROX] Generating expression for ", approx_term,"...")
		approx_expr = to_expr(approx_term)
		val_ranges = get_val_ranges(0, bounds)
		print_msg("Val Ranges: ",val_ranges)
		for (cur_symbol, cur_bounds) in val_ranges
			if cur_bounds[1]==cur_bounds[2]
				println(cur_symbol)
				println(cur_bounds[1])
				approx_expr = substitute(approx_expr,Dict(cur_symbol => cur_bounds[1]),fold=false)
				println(approx_expr)
			end
		end
		@timeit Config.TIMER "OVERT" begin
			overapprox_result =  overapprox(approx_expr, Dict(val_ranges), N=N, ϵ=0.0)#epsilon)
		end
		for cur_bound in bound_types
			output = overapprox_result.output
			if output isa Number
				formula = output
			else
				formula = generate_bound_from_overapprox(output,overapprox_result, cur_bound)
			end
			approximations[ApproxQuery(cur_bound, approx_term)] = IncompleteApproximation(deepcopy(bounds), from_expr(formula))
		end
	end
	return approximations
end

function construct_approx(nonlinear_query :: NormalizedQuery) :: Dict{ApproxQuery, IncompleteApproximation}
	bounds = [nonlinear_query.input_bounds;nonlinear_query.output_bounds]
	return construct_approx(nonlinear_query.approx_queries, bounds)
end

"""
    generate_bound_from_overapprox(output_var, overapprox_result, bound) -> Any

Extract the bound expression (upper or lower) for a given OVERT `output_var` from
an `OverApproximation` result. Falls back to scanning inequalities if no equality
definition is present. Returned expression is still symbolic in OVERT variables.
"""
function generate_bound_from_overapprox(
	output_var::Symbol,
	overapprox_result::OverApproximation,
	bound :: BoundType) :: Any
	result = output_var
	for equation in overapprox_result.approx_eq
		if equation.head == :call && equation.args[1] == :(==) && equation.args[2] == output_var
			result = equation.args[3]
		end
	end
	if result == output_var
		for inequality in overapprox_result.approx_ineq
			if inequality.head == :call && inequality.args[1] == :(≦)
				if bound == Lower && inequality.args[3] == output_var
					result = inequality.args[2]
				end
				if bound == Upper && inequality.args[2] == output_var
					result = inequality.args[3]
				end
			end
		end
	end
	if result != output_var
		result = substitute_vars(result, overapprox_result, bound)
	end
	return result
end

"""
    substitute_vars(term, overapprox_result, bound) -> Any

Recursively substitute intermediate OVERT variables in `term` with their corresponding
upper or lower bound expressions, honoring sign flips for subtraction and division.

This produces a fully expanded symbolic expression in arithmetic, min, and max that
can later be translated to NCubeV `Term`s.
"""
function substitute_vars(
	term :: Any,
	overapprox_result :: OverApproximation,
	bound :: BoundType) :: Any
	if typeof(term) == Symbol
		#print("Generating bound", bound, "for variable", term, "\n")
		result = generate_bound_from_overapprox(term, overapprox_result, bound)
		return result
	elseif typeof(term) == Expr && term.head == :call
		if term.args[1] == :+
			new_args_add :: Vector{Any} = []
			for arg in term.args[2:end]
				push!(new_args_add, substitute_vars(arg, overapprox_result, bound))
			end
			result = Expr(
				:call,
				:+,
				new_args_add...
			)
			return result
		elseif term.args[1] == :-
			new_args_sub :: Vector{Any} = [substitute_vars(term.args[2], overapprox_result, bound)]
			for arg in (@view term.args[3:end])
				push!(new_args_sub, substitute_vars(arg, overapprox_result, flip(bound)))
			end
			return Expr(
				:call,
				:-,
				new_args_sub...
			)
		elseif term.args[1] == :*
			if length(term.args) != 3
				error("Unknown operator argument lenth in ",term,", cannot approximate")
			end
			factor = term.args[2]
			symbolic = term.args[3]
			if !isa(factor, Number)
				factor = term.args[3]
				symbolic = term.args[2]
			end
			if !isa(factor, Number)
				error("Encountered non-linear term in ",term)
			end
			if factor >= 0.0
				return Expr(
					:call,
					:*,
					factor,
					substitute_vars(symbolic, overapprox_result, bound)
				)
			else
				return Expr(
					:call,
					:*,
					term.args[2],
					substitute_vars(term.args[3], overapprox_result, flip(bound))
				)
			end
		elseif term.args[1] == :/
			# Dividend should be static
			if !isa(term.args[3], Number)
				error("Encountered non-linear term in ",term)
			end
			if term.args[3] >= 0.0
				return Expr(
					:call,
					:/,
					substitute_vars(term.args[2], overapprox_result, bound),
					term.args[3]
				)
			else
				return Expr(
					:call,
					:/,
					substitute_vars(term.args[2], overapprox_result, flip(bound)),
					term.args[3]
				)
			end
		elseif term.args[1] == :min
			return Expr(
				:call,
				:min,
				substitute_vars(term.args[2], overapprox_result, bound),
				substitute_vars(term.args[3], overapprox_result, bound)
			)
		elseif term.args[1] == :max
			return Expr(
				:call,
				:max,
				substitute_vars(term.args[2], overapprox_result, bound),
				substitute_vars(term.args[3], overapprox_result, bound)
			)
		else
			error("Unknown operator in ",term,", cannot generate bound")
			return term
		end
	elseif typeof(term) == Expr && (
		term.head == :(<=) ||
		term.head == :(<) || 
		term.head == :(>=) || 
		term.head == :(>) ||
		term.head == :(&&) ||
		term.head == :(||))
		error("There should be no boolean operators in the term, cannot generate bound")
	else
		return term
	end
end