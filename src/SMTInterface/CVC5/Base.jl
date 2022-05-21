SMT_LOG=0

function smt_internal_context()
	options = Dict{String,Any}()
	options["revert-arith-models-on-unsat"] = true
	return (options,PY_CVC5.Context())
end
function smt_internal_variable(ctx, name)
	return PY_CVC5.Real(name,ctx=ctx[2])
end
function smt_internal_set_timeout(ctx, timeout)
	ctx[1]["tlimit-per"] = timeout
end
function smt_internal_solver(ctx, theory)
	global SMT_LOG+=1
	s = PY_CVC5. SolverFor(theory, ctx=ctx[2], logFile="/tmp/smtlog"*string(SMT_LOG)*".smt2")
	for (k,v) in ctx[1]
		current = s.getOption(k)
		if string(current) != string(v)
			println("[CVC5] Setting SMT solver option: ",k," = ",v, " (current value: ",current,")")
			s.setOption(k,v)
		end
	end
	return s
end
function smt_internal_add(solver, formula)
	solver.add(formula)
end
function smt_internal_check(solver)
	return solver.check()
end
function smt_internal_is_sat(res)
	return res == PY_CVC5.sat
end
function smt_internal_is_unsat(res)
	return res == PY_CVC5.unsat
end
function smt_internal_push(solver)
	solver.push()
end
function smt_internal_pop(solver)
	solver.pop()
end

function smt_internal_debug(solver, res)
	println("[CVC5] Found unsolved SMT")
	#println(to_smt2(solver,"unknown"))
	#println(reasonunknown(solver))
	# params = get_param_descrs(solver)
	# for i in 0:(size(params)-1)
	# 	pname = name(params,i)
	# 	println(pname,": ",documentation(params,pname))
	# end
end