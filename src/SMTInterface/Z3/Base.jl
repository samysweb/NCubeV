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
	s = Solver(ctx, theory)
	return s
end
function smt_internal_add(solver, formula)
	add(solver, formula)
end
function smt_internal_check(solver)
	res = check(solver)
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

function smt_internal_debug(solver, res)
	println("[Z3] Found unsolved SMT: ")
	println(to_smt2(solver,"unknown"))
	println(reason_unknown(solver))
	# params = get_param_descrs(solver)
	# for i in 0:(size(params)-1)
	# 	pname = name(params,i)
	# 	println(pname,": ",documentation(params,pname))
	# end
end