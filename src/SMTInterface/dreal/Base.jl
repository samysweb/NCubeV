SMT_LOG=0

function smt_internal_context()
	#options = Dict{String,Any}()
	#options["revert-arith-models-on-unsat"] = true
	#return (options,PY_CVC5.Context())
	ctx = PY_DREAL.Context()
    ctx.SetLogic(Logic.QF_NRA)
	return ctx
end
function smt_internal_variable(ctx, name)
	v = PY_DREAL.Variable(name)
	ctx.DeclareVariable(v)
	return v
end
function smt_internal_set_timeout(ctx, timeout)
	#ctx[1]["tlimit-per"] = timeout
	@warn "smt_internal_set_timeout not implemented"
end
function smt_internal_solver(ctx, theory)
	return ctx
end
function smt_internal_add(ctx, formula)
	ctx.Assert(formula)
end
function smt_internal_check(ctx)
	return ctx.CheckSat()
end
function smt_internal_is_sat(res)
	return res == true
end
function smt_internal_is_unsat(res)
	return res == false
end
function smt_internal_push(ctx)
	ctx.Push()
end
function smt_internal_pop(ctx)
	ctx.Pop()
end

function smt_internal_debug(solver, res)
	print_msg("[CVC5] Found unsolved SMT")
	#print_msg(to_smt2(solver,"unknown"))
	#print_msg(reasonunknown(solver))
	# params = get_param_descrs(solver)
	# for i in 0:(size(params)-1)
	# 	pname = name(params,i)
	# 	print_msg(pname,": ",documentation(params,pname))
	# end
end