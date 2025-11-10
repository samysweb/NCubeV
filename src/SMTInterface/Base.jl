"""
	smt_context(f, varnum::Int64; timeout=1000)

Allocate an SMT context with `varnum` real variables named `x1..xN` and invoke
`f((ctx, variables))`. The context is destroyed afterwards. Timeout is in ms.
"""
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
	smt_solver(f, ctx; stars=false, theory="qfnra")

Create a solver for the given theory and execute `f(solver)`, returning its
result. When `stars=true`, apply preprocessing tactics tuned for star filtering.
"""
function smt_solver(f, ctx;stars=false, theory="qfnra")
	return smt_internal_solver(f, ctx, theory;stars=stars)
end