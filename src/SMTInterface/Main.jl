module SMTInterface
	using MLStyle
	using TimerOutputs

	using ..Util
	using ..AST
	using ..VerifierInterface
	using ..Config

	export smt_context, nl_feasible, nl_feasible_init

	if Config.SMT_SOLVER == "Z3"
		include("Z3/Main.jl")
	elseif Config.SMT_SOLVER == "CVC5"
		include("CVC5/Main.jl")
	#elseif Config.SMT_SOLVER == "dreal"
	#	include("dreal/Main.jl")
	else
		error("Unknown SMT solver: " + Config.SMT_SOLVER)
	end


	include("AST2SMT.jl")
	include("Base.jl")
	include("StarFilter.jl")

	function nl_feasible_init(full_ctx)
		ctx, _ = full_ctx
		s = smt_internal_solver(ctx, "qfnra")
		d = smt_internal_formula_dict(s,full_ctx)
		return (s,d)
	end

	function nl_feasible(constraints, feasibility_solver)
		@timeit Config.TIMER "SMTprep" begin
			s,d = feasibility_solver
			all_vars = smt_internal_get_var_dict(d)
			smt_formulas = []
			additional = []
			for c in constraints
				i, f = c
				var = smt_internal_add_to_dict(d, i, f, additional, all_vars)
				push!(smt_formulas, var)
			end
			smt_internal_push(s)
			for a in additional
				smt_internal_add(s, a)
			end
			for f in smt_formulas
				smt_internal_add(s, f)
			end
			for f in values(all_vars)
				smt_internal_add(s, Z3.not(f))
			end
		end
		res = smt_internal_check(s)
		@timeit Config.TIMER "SMTprep" begin
			smt_internal_pop(s)
		end
		return !smt_internal_is_unsat(res)
	end


	function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables,conflicts;print_model=false)
		res = smt_solver(ctx) do s
			set(s,"unsat-core",true)
			conflict_clauses = Dict()
			vars = ExprVector(ctx)
			@timeit Config.TIMER "SMTprep" begin
				for (i,c) in enumerate(constraints)
					additional = []
					translated = ast2smt(c, variables, additional)
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
			@timeit Config.TIMER "SMTprep" begin
			#conflicts = []
			if smt_internal_is_sat(res)
				if print_model
					smt_print_model(s)
				end
			elseif !smt_internal_is_unsat(res)
				print_msg("[SMT] SMT returned status: ", res)
			else # unsat
				#print_msg("[SMT] Conflict:")
				for c in unsat_core(s)
					#print_msg("[SMT] ", c)
					#print_msg("[SMT] ", constraints[conflict_clauses[string(c)]])
					push!(conflicts,conflict_clauses[string(c)])
				end
			end
			end

			return res
		end
		return !smt_internal_is_unsat(res)
	end


	function lin_feasible(constraints :: Vector{LinearConstraint}, ctx, variables,conflicts;print_model=false)
		res = smt_solver(ctx;theory="qflra") do s
			set(s,"unsat-core",true)
			conflict_clauses = Dict()
			vars = ExprVector(ctx)
			@timeit Config.TIMER "SMTprep" begin
				for (i,c) in enumerate(constraints)
					additional = []
					translated = ast2smt(c, variables, additional)
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
			@timeit Config.TIMER "SMTprep" begin
			#conflicts = []
			if smt_internal_is_sat(res)
				if print_model
					smt_print_model(s)
				end
			elseif !smt_internal_is_unsat(res)
				print_msg("[SMT] SMT returned status: ", res)
			else # unsat
				#print_msg("[SMT] Conflict:")
				for c in unsat_core(s)
					#print_msg("[SMT] ", c)
					#print_msg("[SMT] ", constraints[conflict_clauses[string(c)]])
					push!(conflicts,conflict_clauses[string(c)])
				end
			end
			end

			return res
		end
		return !smt_internal_is_unsat(res)
	end
end