function add_constraint(solver :: Z3SolverContainer, constraint :: Z3ExprContainer; idx=nothing)
	if !isnothing(idx)
		ctx = solver.ctx.ctx.ctx
		assert_var = Z3.Z3_mk_const(
			ctx,
			Z3.Z3_mk_string_symbol(ctx, "nvAssert$idx"), 
			Z3.Z3_mk_bool_sort(ctx))
		Z3.Z3_inc_ref(ctx, assert_var)
	end
	if isnothing(idx) || !Config.SMT_USE_CORES
		Z3.Z3_solver_assert(
			solver.ctx.ctx.ctx,
			_get_solver(solver),
			Z3.as_ast(constraint.expr))
	else
		Z3.Z3_solver_assert_and_track(
			solver.ctx.ctx.ctx,
			_get_solver(solver),
			Z3.as_ast(constraint.expr),
			assert_var)
	end
	for a in constraint.additional
		Z3.Z3_solver_assert(
			solver.ctx.ctx.ctx,
			_get_solver(solver),
			Z3.as_ast(a))
	end
	if !isnothing(idx)
		solver.named_assertions[assert_var] = idx
	end
end

function process_ast_context(solver :: Z3SolverContainer, ast_context :: ASTZ3Context)
	# Nothing to do here
end

function check_sat(solver :: Z3SolverContainer)
	#print("-----------------------------------")
	#print(unsafe_string(Z3.Z3_solver_to_string(solver.ctx.ctx.ctx, solver.solver)))
	return Z3.Z3_solver_check(solver.ctx.ctx.ctx, _get_solver(solver))
end

function is_sat(res)
	return res == Z3.Z3_L_TRUE
end

function is_unsat(res)
	return res == Z3.Z3_L_FALSE
end

function get_model(f, solver :: Z3SolverContainer, res)
	z3_model = Z3.Z3_solver_get_model(solver.ctx.ctx.ctx, _get_solver(solver))
	Z3.Z3_model_inc_ref(solver.ctx.ctx.ctx, z3_model)
	model = Z3ModelContainer(solver.ctx, z3_model)
	result = GC.@preserve z3_model f(model)
	Z3.Z3_model_dec_ref(solver.ctx.ctx.ctx, z3_model)
	return result
end

function evaluate_model(m :: Z3ModelContainer, expr :: Z3ExprContainer)
	res = Ref{Z3.Libz3.Z3_ast}()
	Z3.Z3_model_eval(
		m.ctx.ctx.ctx,
		m.model,
		Z3.as_ast(expr.expr),
		true,
		res)
	sort = Z3.Z3_sort_to_string(
		m.ctx.ctx.ctx,
		Z3Solver.Z3.Z3_get_sort(
			m.ctx.ctx.ctx,
			res[])
		)
	sort_str = unsafe_string(sort)
	if sort_str == "Real"
		num = convert(BigFloat,Z3.Z3_get_numeral_double(m.ctx.ctx.ctx,Z3.Z3_get_numerator(m.ctx.ctx.ctx,res[])))
		den = convert(BigFloat,Z3.Z3_get_numeral_double(m.ctx.ctx.ctx,Z3.Z3_get_denominator(m.ctx.ctx.ctx,res[])))
		return rationalize(BigInt, num/den)
	elseif sort_str == "Bool"
		return Z3.Z3_get_bool_value(m.ctx.ctx.ctx,res[]) == Z3.Z3_L_TRUE
	else
		@assert false "Unknown sort: $sort_str"
	end
end

function print_model(m :: Z3ModelContainer)
	println(unsafe_string(Z3.Z3_model_to_string(m.ctx.ctx.ctx, m.model)))
end

function push(solver :: Z3SolverContainer)
	Z3.Z3_solver_push(solver.ctx.ctx.ctx, _get_solver(solver))
end

function pop(solver :: Z3SolverContainer)
	Z3.Z3_solver_pop(solver.ctx.ctx.ctx, _get_solver(solver), 1)
end

function get_core(solver :: Z3SolverContainer)
	# Get core from Z3
	if !Config.SMT_USE_CORES
		return collect(Int, values(solver.named_assertions))
	else
		coreVec = Z3.Z3_solver_get_unsat_core(solver.ctx.ctx.ctx, _get_solver(solver))
		len = Z3.Z3_ast_vector_size(solver.ctx.ctx.ctx, coreVec)
		core = Vector{Int}()
		for i in 0:len-1
			ast = Z3.Z3_ast_vector_get(solver.ctx.ctx.ctx, coreVec, i)
			push!(core, solver.named_assertions[ast])
		end
		return core
	end
end