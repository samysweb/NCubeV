module SMTInterface
	using MLStyle

	using ..Util
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


	function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables;print_model=false)
		res = smt_solver(ctx) do s
			for c in constraints
				additional = []
				translated = ast2smt(c, variables, additional)
				#print_msg(translated)
				smt_internal_add(s, translated)
				for a in additional
					smt_internal_add(s, a)
				end
			end
			
			res = smt_internal_check(s)
			if smt_internal_is_sat(res)
				if print_model
					smt_print_model(s)
				end
			elseif !smt_internal_is_unsat(res)
				print_msg("[SMT] SMT returned status: ", res)
			end

			return res
		end
		return !smt_internal_is_unsat(res)
	end
end