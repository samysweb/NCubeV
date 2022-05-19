module SMTInterface
	using MLStyle

	using ..AST
	using ..VerifierInterface
	using ..Config

	export smt_context, nl_feasible

	if Config.SMT_SOLVER == "Z3"
		include("Z3/Main.jl")
	elseif Config.SMT_SOLVER == "CVC5"
		include("CVC5/Main.jl")
	else
		error("Unknown SMT solver: " + Config.SMT_SOLVER)
	end


	include("Base.jl")
	include("StarFilter.jl")


	function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables)
		res = smt_solver(ctx) do s
			for c in constraints
				additional = []
				translated = ast2smt(c, variables, additional)
				#println(translated)
				smt_internal_add(s, translated)
				for a in additional
					smt_internal_add(s, a)
				end
			end
			
			return smt_internal_check(s)
		end
		
		if !smt_internal_is_sat(res) && !smt_internal_is_unsat(res)
			@info "SMT returned status: ", res
		end
		return !smt_internal_is_unsat(res)
	end
end