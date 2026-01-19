"""
	smt_context(f, varnum::Int64; timeout=1000)

Allocate an SMT context with `varnum` real variables named `x1..xN` and invoke
`f((ctx, variables))`. The context is destroyed afterwards. Timeout is in ms.
"""

function smt_context(f, varnum :: Int64; timeout=1000)
	@satvariable(variables[1:varnum], Real)
    return f((nothing, variables))
end

"""
	smt_context(f, varnum::Int64; timeout=1000)
function smt_context(f, varnum :: Int64; timeout=1000)
	res = nothing
	begin
		# Setup of SMT Context
		ctx = smt_internal_context()
		variables = []
		for i in 1:varnum
			push!(variables, smt_internal_variable(ctx, "x"*string(i)))
		end
		smt_internal_set_timeout(ctx, timeout)
		# Run program
		res = GC.@preserve ctx variables f((ctx, variables))
	end
	# Cleanup SMT Context
	GC.gc(true)
	return res
end
"""

"""
	smt_solver(f, ctx; stars=false, theory="qfnra")

Create a solver for the given theory and execute `f(solver)`, returning its
result. When `stars=true`, apply preprocessing tactics tuned for star filtering.
"""
function smt_solver(f, ctx; stars=false, theory="qfnra")
	return smt_internal_solver(f, ctx, theory;stars=stars)

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
