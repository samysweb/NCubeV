function get_context(f, var_num :: Int)
	res = nothing
	begin
		ctx_internal = Context()
		variables = Z3.Expr[]
		for i in 1:var_num
			push!(variables, RealVar("x$i", ctx_internal))
		end
		ctx = Z3Context(ctx_internal, variables)
		res = GC.@preserve ctx ctx_internal variables f(ctx)
	end
	return res
end

@inline function get_ctx_variable(ctx :: Z3Context, i :: Int)
	return ctx.variables[i]
end

function get_ast_context(context :: Z3Context)
	additional = Z3.Expr[]
	smt_cache = Dict{ParsedNode,Z3.Expr}()
	return ASTZ3Context(context, additional, smt_cache)
end

function is_cached(ast_context :: ASTZ3Context, f :: ParsedNode)
	return haskey(ast_context.smt_cache, f)
end

function get_cached(ast_context :: ASTZ3Context, f :: ParsedNode)
	return ast_context.smt_cache[f]
end

function cache(ast_context :: ASTZ3Context, f :: ParsedNode, smt :: Z3.Expr)
	ast_context.smt_cache[f] = smt
end

function get_ast_ctx_variable(ast_context :: ASTZ3Context, i :: Int)
	return get_ctx_variable(ast_context.ctx, i)
end

function get_solver(f, ctx :: Z3Context, theory)
	res = nothing
	begin
		z3_solver = nothing
		#solver_tactic = nothing
		if theory=="qfnra"
			logic = Z3.to_symbol("QF_NRA", ctx.ctx)
			z3_solver = Z3.Z3_mk_solver_for_logic(ctx.ctx.ctx, logic)
		elseif theory=="qflra"
			logic = Z3.to_symbol("QF_LRA", ctx.ctx)
			z3_solver = Z3.Z3_mk_solver_for_logic(ctx.ctx.ctx, logic)
		else
			@assert false "Unknown theory: $theory"
		end
        Z3.Z3_solver_inc_ref(ctx.ctx.ctx, z3_solver)
		s = Z3SolverContainer(ctx, z3_solver)
		res =  GC.@preserve s z3_solver ctx f(s)
		Z3.Z3_solver_dec_ref(ctx.ctx.ctx, z3_solver)
	end
	return res
end

function _get_solver(solver :: Z3SolverContainer)
	return solver.solver
end

