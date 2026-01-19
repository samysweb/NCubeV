"""
SMTInterface
=============

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

	export smt_context, lin_feasible, nl_feasible, nl_feasible_init, check_star
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
	function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables, conflicts; print_model=false)
		
		println("checking nl feasibility")
		#@show constraints
		#@show variables

		n = length(constraints)
		@satvariable(C[1:n], Bool) # conflict bools
		additional = []

		cons_trans = map(con -> ast2smt(con, variables, additional, Dict()), constraints)
		expr = Sat.and(cons_trans...) ∧
			Sat.and([c ⟹ con for (c,con) in zip(C, cons_trans)])
		
		!isempty(additional) && (expr = expr ∧ Sat.and(additional...)) 
		
		res = sat!(expr, solver=Z3(), logic="QF_NRA")

		@timeit TIMER "SMTprep" begin
		if res == :SAT
			if print_model
				smt_print_model(s)
			end
		elseif res != :UNSAT
			print_msg("[SMT] SMT returned status: ", res)
		else # res == :UNSAT
			if USE_CORES
				# TODO
			else
				for (i,_) in enumerate(constraints)
					push!(conflicts,i)
				end
			end
		end
		
		return (res ≠ :UNSAT)
		end
	end


	"""
		lin_feasible(constraints::Vector{LinearConstraint}, ctx, variables, conflicts; print_model=false) -> Bool

	Check feasibility of linear constraints under QF_LRA with activation literals
	for unsat core extraction. Returns `true` if satisfiable or unknown.
	"""
	function lin_feasible(constraints :: Vector{LinearConstraint}, ctx, variables, conflicts; print_model=false)
		
		println("checking lin feasibility")
		#@show constraints
		#@show variables

		n = length(constraints)
		@satvariable(C[1:n], Bool) # conflict bools
		additional = []

		cons_trans = map(con -> ast2smt(con, variables, additional, Dict()), constraints)
		expr = Sat.and(cons_trans...) ∧
			Sat.and([c ⟹ con for (c,con) in zip(C, cons_trans)])

		
		!isempty(additional) && (expr = expr ∧ Sat.and(additional...)) 

		res = sat!(expr, solver=Z3(), logic="QF_LRA")
		@show res
		@show expr

		@timeit TIMER "SMTprep" begin
		if res == :SAT
			if print_model
				smt_print_model(s)
			end
		elseif res != :UNSAT
			print_msg("[SMT] SMT returned status: ", res)
		else # res == :UNSAT
			if USE_CORES
				# TODO
			else
				for (i,_) in enumerate(constraints)
					push!(conflicts,i)
				end
			end
		end

		return (res ≠ :UNSAT)
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