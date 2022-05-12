function z3_context(f, varnum :: Int64; timeout=100)
	res = nothing
	begin
		# Setup of Z3 Context
		ctx = Context()
		variables = []
		for i in 1:varnum
			push!(variables, real_const(ctx, "x"*string(i)))
		end
		set_param("timeout", timeout)
		# Run program
		res = f((ctx, variables))
	end
	# Cleanup Z3 Context
	GC.gc(true)
	return res
end

function z3_solver(f, ctx)
	res = nothing
	s = Solver(ctx, "QF_NRA")
	res = f(s)
	return res
end