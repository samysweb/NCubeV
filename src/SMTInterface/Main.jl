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
	export ast2smt, pwl2term, secure_int

	#USE_CORES = true
	USE_CORES = false


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
		n = length(constraints)
		@satvariable(C[1:n], Bool) # conflict bools
		additional = []

		cons_trans = map(con -> ast2smt(con, variables, additional, Dict()), constraints)
		expr = Sat.and(cons_trans...)
		
		if !isempty(additional)
			expr = expr ∧ Sat.and(additional...)
		end
		
		# If expr simplified to a native Bool, wrap it back into an SMT expression
		if expr isa Bool
			expr = Satisfiability.__wrap_const(expr)
		end

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
		end
		return (res ≠ :UNSAT)
	end


	"""
		lin_feasible(constraints::Vector{LinearConstraint}, ctx, variables, conflicts; print_model=false) -> Bool

	Check feasibility of linear constraints under QF_LRA with activation literals
	for unsat core extraction. Returns `true` if satisfiable or unknown.
	"""
	function lin_feasible(constraints :: Vector{LinearConstraint}, ctx, variables, conflicts; print_model=false)
		n = length(constraints)
		@satvariable(C[1:n], Bool) # conflict bools
		additional = []

		cons_trans = map(con -> ast2smt(con, variables, additional, Dict()), constraints)
		expr = Sat.and(cons_trans...)
		if !isempty(additional)
			expr = expr ∧ Sat.and(additional...)
		end

		# If expr simplified to a native Bool, wrap it back into an SMT expression
		if expr isa Bool
			expr = Satisfiability.__wrap_const(expr)
		end
		# needs qf_nra since ast2smt(TermNumber) uses fractions with variables in the denominator
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
		end
		return (res ≠ :UNSAT)
	end
end