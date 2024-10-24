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

function smt_solver(f, ctx;stars=false, theory="qfnra")
	return smt_internal_solver(f, ctx, theory;stars=stars)
end