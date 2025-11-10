#using Distributed
"""
Low-level Z3 helpers
--------------------

Utility functions for constructing Z3 contexts, variables, solvers, and
performing checks. Provides configurable tactics for QF_NRA and QF_LRA and
exposes convenience wrappers used by `SMTInterface`.
"""
# function get_wid()
# 	workers = Distributed.workers()
# 	if length(workers) <= 1
# 		new_proc = Distributed.addprocs(1,exeflags=["--project=$(Base.active_project())"])
# 		@eval @everywhere using Z3
# 		workers = new_proc
# 	end
# 	return workers[end]
# end
# function sendto(p::Int; args...)
#     for (nm, val) in args
#         remotecall_fetch(Main.eval,p, Expr(:(=), nm, val))
#     end
# end
	

"""
	smt_internal_context() -> Z3.Context

Create a fresh Z3 context.
"""
function smt_internal_context()
	ctx = Context()
	return ctx
end
"""
	smt_internal_variable(ctx, name::AbstractString)

Create a real-valued Z3 variable of given name in `ctx`.
"""
function smt_internal_variable(ctx, name)
	var = real_const(ctx, name)
	return var
end
"""
	smt_internal_set_timeout(ctx, timeout_ms::Integer)

Set a per-query timeout (milliseconds) on the Z3 context.
"""
function smt_internal_set_timeout(ctx, timeout)
	#set_param("timeout", timeout)
	set(ctx, "timeout", timeout)
end
"""
	smt_internal_solver(f, ctx, theory; stars=false)

Build a solver for `theory` ("qfnra" or "qflra"). Optionally apply additional
preprocessing tactics for star filtering (`stars=true`). Executes `f(solver)`
and returns its result.
"""
function smt_internal_solver(f, ctx, theory;stars=false)
	# Unfortunately, this is broken with the new Z3 version
	# It seems one step inside the and_then does not work; possibly solve-eqs
	# if stars
	# 	t_solve = Tactic(ctx,"solve-eqs")
	# 	t_purify = Tactic(ctx,"purify-arith")
	# 	pre_step = par_and_then(t_solve,t_purify)
	# else
		
	# end
	res = nothing
	begin
		s = nothing
		#solver_tactic = nothing
		if theory=="qfnra"
			#s = Solver(ctx,"QF_NRA")
			if stars
				s = mk_solver( Tactic(ctx, "solve-eqs") & Tactic(ctx, "purify-arith") & Tactic(ctx, "qfnra"))
			elseif !USE_CORES
				s = mk_solver(Tactic(ctx, "purify-arith") & Tactic(ctx, "qfnra"))
			else
				s = Solver(ctx,"QF_NRA")
			end
		elseif theory=="qflra"
			if stars
				s = mk_solver( Tactic(ctx, "solve-eqs") & Tactic(ctx, "purify-arith") & Tactic(ctx, "qflra"))
			elseif !USE_CORES
				s = mk_solver(Tactic(ctx, "purify-arith") & Tactic(ctx, "qflra"))
			else
				s = Solver(ctx,"QF_LRA")
			end
			#set(s,"smt.arith.solver",convert(Int32,2))
		else
			s = Solver(ctx,theory)
		end
		
		res =  GC.@preserve s f(s)
	end
	return res
end
"""
	smt_internal_add(solver, formula)

Assert a formula into the solver.
"""
function smt_internal_add(solver, formula)
	add(solver, formula)
end
"""
	smt_internal_check(solver)

Check satisfiability of the current solver state.
"""
function smt_internal_check(solver)
	#println("[Z3] Checking...")
	@timeit TIMER "z3_check" begin
		res =  check(solver)
	end
	return res
end
"""
	smt_internal_check(solver, exprs)

Check satisfiability with activation literals `exprs` (for unsat cores).
"""
function smt_internal_check(solver, exprs)
	#println("[Z3] Checking...")
	@timeit TIMER "z3_check" begin
		res =  check(solver, exprs)
	end
	return res
end
function smt_internal_is_sat(res)
	return res == Z3.sat
end
function smt_internal_is_unsat(res)
	return res == Z3.unsat
end
function smt_internal_push(solver)
	push(solver)
end
function smt_internal_pop(solver)
	pop(solver,1)
end

"""
	smt_internal_debug(solver, res)

Print SMT2 and reason for unknowns to help debugging.
"""
function smt_internal_debug(solver, res)
	print_msg("[Z3] Found unsolved SMT: ")
	print_msg(to_smt2(solver,"unknown"))
	print_msg(reason_unknown(solver))
	# params = get_param_descrs(solver)
	# for i in 0:(size(params)-1)
	# 	pname = name(params,i)
	# 	print_msg(pname,": ",documentation(params,pname))
	# end
end

"""
	smt_print_model(solver)

Pretty-print the current Z3 model.
"""
function smt_print_model(solver)
	model = get_model(solver)
	print_msg("[Z3] Model: ")
	print_msg(model)
end

function smt_internal_get_model(solver)
	model = get_model(solver)
	return model
end

"""
	smt_internal_formula_dict(solver, full_ctx)

Create a dictionary structure for on-demand boolean abstraction mapping.
"""
function smt_internal_formula_dict(solver, full_ctx)
	res = Dict{Int64, Any}()
	return (solver, full_ctx, res)
end

function smt_internal_get_var_dict(dict)
	(solver, full_ctx, res) = dict
	return copy(res)
end

"""
	smt_internal_add_to_dict(dict, i, formula, additional, dict_copy)

Map a skeleton variable id `i` to either a fresh boolean in the solver or the
translated formula, and assert the implication into the solver. Used for
unsat-core extraction.
"""
function smt_internal_add_to_dict(dict, i, formula, additional, dict_copy)
	(solver, full_ctx, res) = dict
	ctx, variables = full_ctx
	if i == 0
		return ast2smt(formula, variables, additional)
	elseif haskey(res, i)
		delete!(dict_copy, i)
		return res[i]
	else
		v = Z3.bool_const(ctx, "b$i")
		res[i] = v
		additional = []
		smt_internal_add(solver, Z3.implies(v,ast2smt(formula, variables,additional)))
		for a in additional
			smt_internal_add(solver, a)
		end
		return v
	end
end
function smt_internal_set(solver, name, value)
	if name == "unsat-core"
		if USE_CORES || !value
			set(solver, "unsat-core", value)
		end
	else
		set(solver, name, value)
	end
end