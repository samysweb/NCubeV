module Z3Interface
	using Z3
	using MLStyle

	using ..AST

	export z3_context, nl_feasible

	include("AST2Z3.jl")

	function z3_context(varnum :: Int64)
		ctx = Context()
		variables = []
		for i in 1:varnum
			push!(variables, real_const(ctx, "x"*string(i)))
		end
		set_param("timeout", 100)
		return ctx, variables
	end

	function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables)
		# ctx = Context()
		# variables = []
		# for i in 1:varnum
		# 	push!(variables, real_const(ctx, "x"*string(i)))
		# end

		s = Solver(ctx, "QF_NRA")
		for c in constraints
			translated = ast2z3(c, variables)
			#println(translated)
			add(s, translated)
		end
		
		res = check(s)
		# if first(constraints) isa LinearConstraint
			# print("------------------------------------------------------")
			# print(s)
			# print(res == Z3.unsat)
			# print("------------------------------------------------------")
			# sleep(5)
		# end
		
		
		return res != Z3.unsat
	end
end