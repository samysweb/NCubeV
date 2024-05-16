module SMTInterface
	using MLStyle
	using TimerOutputs

	using ..Util
	using ..AST
	using ..VerifierInterface
	import ..Config.SMT_SOLVER
	import ..Config.TIMER

	export smt_context, nl_feasible, nl_feasible_init

	USE_CORES = true

	if SMT_SOLVER == "Z3"
		include("Z3/Main.jl")
	elseif SMT_SOLVER == "CVC5"
		include("CVC5/Main.jl")
	#elseif SMT_SOLVER == "dreal"
	#	include("dreal/Main.jl")
	else
		error("Unknown SMT solver: " + SMT_SOLVER)
	end


	include("AST2SMT.jl")
	include("Base.jl")
	include("StarFilter.jl")

	function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables,conflicts;print_model=false)
		res = smt_solver(ctx) do s
			smt_internal_set(s,"unsat-core",true)
			conflict_clauses = Dict()
			vars = ExprVector(ctx)
			@timeit TIMER "SMTprep" begin
				for (i,c) in enumerate(constraints)
					additional = []
					smt_cache = Dict()
					translated = ast2smt(c, variables, additional, smt_cache)
					#print_msg(translated)
					conflict_var = bool_const(ctx, "c" * string(i))
					smt_internal_add(s, Z3.implies(conflict_var,translated))
					conflict_clauses[string(conflict_var)] = i
					push!(vars, conflict_var)
					for a in additional
						smt_internal_add(s, a)
					end
				end
			end
			
			res = smt_internal_check(s, vars)
			@timeit TIMER "SMTprep" begin
			#conflicts = []
			if smt_internal_is_sat(res)
				if print_model
					smt_print_model(s)
				end
			elseif !smt_internal_is_unsat(res)
				print_msg("[SMT] SMT returned status: ", res)
			else # unsat
				#print_msg("[SMT] Conflict:")
				if USE_CORES
					for c in unsat_core(s)
						#print_msg("[SMT] ", c)
						#print_msg("[SMT] ", constraints[conflict_clauses[string(c)]])
						push!(conflicts,conflict_clauses[string(c)])
					end
				else
					for (i,_) in enumerate(constraints)
						push!(conflicts,i)
					end
				end
			end
			end

			return res
		end
		return !smt_internal_is_unsat(res)
	end


	function lin_feasible(constraints :: Vector{LinearConstraint}, ctx, variables,conflicts;print_model=false)
		res = smt_solver(ctx;theory="qflra") do s
			smt_internal_set(s,"unsat-core",true)
			conflict_clauses = Dict()
			vars = ExprVector(ctx)
			@timeit TIMER "SMTprep" begin
				for (i,c) in enumerate(constraints)
					additional = []
					smt_cache = Dict()
					translated = ast2smt(c, variables, additional, smt_cache)
					#print_msg(translated)
					conflict_var = bool_const(ctx, "c" * string(i))
					smt_internal_add(s, Z3.implies(conflict_var,translated))
					conflict_clauses[string(conflict_var)] = i
					push!(vars, conflict_var)
					for a in additional
						smt_internal_add(s, a)
					end
				end
			end
			
			res = smt_internal_check(s, vars)
			@timeit TIMER "SMTprep" begin
			#conflicts = []
			if smt_internal_is_sat(res)
				if print_model
					smt_print_model(s)
				end
			elseif !smt_internal_is_unsat(res)
				print_msg("[SMT] SMT returned status: ", res)
			else # unsat
				#print_msg("[SMT] Conflict:")
				if USE_CORES
					for c in unsat_core(s)
						#print_msg("[SMT] ", c)
						#print_msg("[SMT] ", constraints[conflict_clauses[string(c)]])
						push!(conflicts,conflict_clauses[string(c)])
					end
				else
					for (i,_) in enumerate(constraints)
						push!(conflicts,i)
					end
				end
			end
			end

			return res
		end
		return !smt_internal_is_unsat(res)
	end
end