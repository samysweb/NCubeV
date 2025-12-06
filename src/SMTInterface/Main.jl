"""
SMTInterface
============

Abstractions over SMT solvers (Z3, CVC5, …) and AST translations used by the
Mosaic pipeline. Provides QF_LRA and QF_NRA contexts, translation helpers, and
the star-based counterexample filter per Lemma 12 (Appendix B.3).

Exports
- `smt_context`: Create and manage solver contexts
- `nl_feasible`, `lin_feasible`: Feasibility checks (with optional unsat cores)

See also: `SMTInterface.AST2SMT`, `SMTInterface.StarFilter`.
"""
module SMTInterface
	using MLStyle
	using TimerOutputs

	using ..Util
	using ..AST
	using ..VerifierInterface
	import ..Config.SMT_SOLVER
	import ..Config.TIMER

	using Satisfiability
	Sat = Satisfiability

	export smt_context, nl_feasible, nl_feasible_init
	export ast2smt, pwl2term

	#USE_CORES = true
	USE_CORES = false

	if SMT_SOLVER == "Z3"
		#include("Z3/Main.jl")
	elseif SMT_SOLVER == "CVC5"
		#include("CVC5/Main.jl")
	#elseif SMT_SOLVER == "dreal"
	#	include("dreal/Main.jl")
	else
		error("Unknown SMT solver: " + SMT_SOLVER)
	end


	include("AST2SMT.jl")
	include("AST2Satisfiability.jl")
	include("Base.jl")
	include("StarFilter.jl")

	"""
		nl_feasible(constraints::Vector{Union{Formula}}, ctx, variables, conflicts; print_model=false) -> Bool

	Check feasibility of a set of (possibly nonlinear) constraints under QF_NRA.
	Uses activation literals to optionally extract an unsat core into `conflicts`
	(indices of `constraints`). Returns `true` if satisfiable or unknown.
	"""
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


	"""
		lin_feasible(constraints::Vector{LinearConstraint}, ctx, variables, conflicts; print_model=false) -> Bool

	Check feasibility of linear constraints under QF_LRA with activation literals
	for unsat core extraction. Returns `true` if satisfiable or unknown.
	"""
	function lin_feasible(constraints :: Vector{LinearConstraint}, ctx, variables,conflicts;print_model=false)
		
		@show variables
		@show typeof(variables)

		expr = map(c -> ast2smt(c, variables, [], Dict()), constraints)
		expr = Sat.and(expr...)
		res, _ = sat!(expr)

		@timeit TIMER "SMTprep" begin
		#conflicts = []
		if res == :SAT
			if print_model
				smt_print_model(s)
			end
		elseif res != :UNSAT
			print_msg("[SMT] SMT returned status: ", res)
		else # unsat
			for (i,_) in enumerate(constraints)
				push!(conflicts,i)
			end
		end
		return (res == :SAT)
	end
	"""
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
	"""
	end
end