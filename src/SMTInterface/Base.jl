"""
	smt_context(f, varnum::Int64; timeout=1000)

Allocate an SMT context with `varnum` real variables named `x1..xN` and invoke
`f((ctx, variables))`. The context is destroyed afterwards. Timeout is in ms.
"""

function smt_context(f, varnum :: Int64; timeout=1000)
	@satvariable(variables[1:varnum], Real)
    return f((nothing, variables))
end