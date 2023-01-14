#using Distributed

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
	

function smt_internal_context()
	ctx = Context()
	return ctx
end
function smt_internal_variable(ctx, name)
	var = real_const(ctx, name)
	return var
end
function smt_internal_set_timeout(ctx, timeout)
	set_param("timeout", timeout)
end
function smt_internal_solver(ctx, theory)
	t_solve = Tactic(ctx,"solve-eqs")

	#t_split = Tactic(ctx,"split-clause")
	#t_skip = Tactic(ctx,"skip")
	#t_split_all = Z3.repeat(t_split | t_skip, 15)

	#t_degree_shift = Tactic(ctx,"degree-shift")

	#t_simplify = Tactic(ctx,"simplify")
	#t_propagate = Tactic(ctx,"propagate-ineqs")

	qfnra_tactic = Tactic(ctx,"qfnra")
	
	t_overall = par_and_then(
		t_solve,
		qfnra_tactic
	)

	#t_both = par_and_then(t_solve, qfnra_tactic)
	
	s = mk_solver(t_overall)
	#s = Solver(ctx, theory)
	#set(s,"smt.arith.solver",convert(Int32,2))
	return s
end
function smt_internal_add(solver, formula)
	add(solver, formula)
end
function smt_internal_check(solver)
	#if timeout==0
	@timeit Config.TIMER "z3_check" begin
		res =  check(solver)
	end
	return res
	# else
	# 	wid = get_wid()
	# 	print_msg("[SMT] timeout of ", timeout/1000, " seconds")
	# 	result = RemoteChannel(()->Channel{Any}(0))
	# 	#remotecall(process_check, wid, result, solver)
	# 	sendto(wid; result=result, solver=solver)
	# 	call_future = remotecall(Main.eval, wid, quote
	# 		print_msg("[SMT] Test!!!!", solver, result)
	# 		res = Z3.check(solver)
	# 		print("[SMT] Worker found result: ", res)
	# 		put!(result, res)
	# 	end)
	# 	# call_future = @spawnat wid eval(Main,quote
	# 	# 	print_msg("[SMT] Starting check...")
	# 	# 	# res = Z3.check(solver)
	# 	# 	# print("[SMT] Worker found result: ", res)
	# 	# 	# put!(result, res)
	# 	# end)
	# 	timedwait(()->begin
	# 		res = isready(result)
	# 		return res
	# 	end, timeout/1000;pollint=1)
	# 	if !isready(result)
	# 		print_msg("Computation at $wid will be terminated")
	# 		print_msg("Result: ", fetch(call_future))
	# 		try
	# 			rmprocs(wid;waitfor=1)
	# 		catch e
	# 			print("When terminating worker $wid:", e)
	# 		end
	# 		return Z3.unknown
	# 	else
	# 		print_msg("Result: ", fetch(call_future))
	# 		return take!(result)
	# 	end
	# end
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

function smt_print_model(solver)
	model = get_model(solver)
	print_msg("[Z3] Model: ")
	print_msg(model)
end

function smt_internal_formula_dict(solver, full_ctx)
	res = Dict{Int64, Any}()
	return (solver, full_ctx, res)
end

function smt_internal_get_var_dict(dict)
	(solver, full_ctx, res) = dict
	return copy(res)
end

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