module Z3Interface
	using Z3
	using MLStyle

	using ..AST

	export z3_context, nl_feasible

	include("Base.jl")
	include("AST2Z3.jl")


	function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables)
		res = z3_solver(ctx) do s
			for c in constraints
				translated = ast2z3(c, variables)
				#println(translated)
				add(s, translated)
			end
			
			return check(s)
		end
		
		if res!=Z3.sat && res!=Z3.unsat
			@info "Z3 returned status: "*string(res)
		end
		return res != Z3.unsat
	end
end