#
# NCubeV SMT Star Filter — Counterexample region filtering (Appendix B.3)
#
# This file implements the SMT-based filtering of counterexample regions (stars)
# following Lemma 12. Each star represents an azulejo-region with an affine output map,
# and we check satisfiability of the nonlinear constraints restricted to that region.
#
using TimerOutputs

"""
    SmtFilterMeta

Metadata returned by the SMT filter summarizing how many star regions were filtered
out and preserving original backend metadata.
"""
struct SmtFilterMeta
	original_meta :: Any
	filtered_out :: Int64
	#formula :: Formula
end

"""
    add_to_solver(solver, variables, star, smt_cache)

Assert the linear constraints of a `star` region into the given SMT solver, along with
its input bounds and affine output mapping (x⁺ = ω(z)).

Used by `check_star` to assemble both linear and nonlinear checks.
"""


function ast2smt(star :: Star, variables, additional, smt_cache)
	input_vars = size(star.constraint_matrix)[2]
	exprs = []
	for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
		push!(exprs, ast2smt(LinearConstraint(c,b,true), variables, additional, smt_cache))
	end
	for (i, b) in enumerate(star.bounds)
		push!(exprs, ast2smt(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)),variables, additional, smt_cache))
		push!(exprs, ast2smt(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])),variables, additional, smt_cache))
	end
	for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
		push!(exprs, ast2smt(Atom(AST.Eq, Variable("x"*string(input_vars+i), nothing, input_vars+i), LinearTerm(c,b)), variables, additional, smt_cache))
	end
	
	
	return Sat.and(exprs...)
end

"""
    check_star(ctx, variables, disjunction_nonlinear, star, smt_cache)
        -> (status::Int, star::Star)

SMT-check a single `star` against the nonlinear disjunction. Builds a linear pre-filter
and short-circuits obviously irrelevant regions. If the nonlinear check is SAT, attempts
to extract a concrete model to refine the counterexample point.

Returns 1 for confirmed counterexample, 2 for unknown/timeout, 0 for spurious.

Implements Lemma 12 from Appendix B.3.
"""
function check_star(ctx, variables, disjunction_nonlinear, star :: Star, smt_cache)
	disjunction = []
	@satvariable(x[1:length(variables)], Real)
	additional = []
	star_expr = ast2smt(star, x, additional, smt_cache)
	!isempty(additional) && (star_expr = star_expr ∧ Sat.and(additional...)) 
	
	# filter out pairs where the linear part is unsatisfiable
	for (linear, nonlinear) ∈ disjunction_nonlinear
		additional = []
		lin_expr = ast2smt(linear, x, additional, smt_cache)
		expr = Sat.and(star_expr, lin_expr)
		!isempty(additional) && (expr = expr ∧ Sat.and(additional...)) 
		# If expr simplified to a native Bool, wrap it back into an SMT expression
		if expr isa Bool
			expr = Satisfiability.__wrap_const(expr)
		end
		# needs qf_nra since ast2smt(TermNumber) uses fractions with variables in the denominator
		res = sat!(expr, solver=Z3(), logic="QF_NRA")
		if res ≠ :UNSAT
			push!(disjunction,
				CompositeFormula(AST.And,[
					linear,
					nonlinear
				])
			)
		end
	end
	if length(disjunction) > 0
		additional = []
		disj_expr = Sat.or(
			(map(c -> ast2smt(c, x, additional, smt_cache), disjunction))...
		)
		expr = Sat.and(star_expr, disj_expr)
		if !isempty(additional)
			expr = expr ∧ Sat.and(additional...)
		end				
		# If expr simplified to a native Bool, wrap it back into an SMT expression
		if expr isa Bool
			expr = Satisfiability.__wrap_const(expr)
		end
		res = nothing
		try 
			res = sat!(expr, solver=Z3(), logic="QF_NRA")
		catch e
			# Satisfiability may throw OverflowError when trying to parse Model
			# In this case a Model was found, therefore :SAT
			if e isa OverflowError
				print_msg("[SMT] Reusing original (linear) counter-example due to error in SMT model extraction")
				return 1, star
			else
				rethrow(e)
			end
		end

		#println("nl $(res)")
		#@show expr

		@match res begin
			:SAT => begin
				try
					num_input_vars = length(star.counter_example[1])
					for (var_index, var) in enumerate(x)
						if var_index <= num_input_vars
							star.counter_example[1][var_index] = var.value
						else
							star.counter_example[2][var_index-num_input_vars] = var.value
						end
					end
				catch
					print_msg("[SMT] Reusing original (linear) counter-example due to error in SMT model extraction")
				end
				return 1, star
			end
			:UNSAT => return 0, star
			:ERROR => return 2, star 
		end
	end
	return 0, star
end

"""
	get_star_filter(ctx, variables, disjunction_nonlinear, smt_timeout)
		-> (OlnnvResult -> OlnnvResult)

Construct a star-filtering callback that post-processes backend results:
- If status is `safe`, returns unchanged.
- Otherwise, runs `check_star` on each star and keeps only confirmed or unknown ones.

This function realizes the “Filter” step in Algorithm 1 (Appendix B.3).

Example
```julia
using NCubeV

# Assume `prepared_query::Query` and a disjunction of (linear, nonlinear) pairs
result = SMTInterface.smt_context(prepared_query.num_input_vars + prepared_query.num_output_vars; timeout=10_000) do (ctx, vars)
	# Build a filter bound to current SMT context
	SMTFilter = SMTInterface.get_star_filter(ctx, vars, disjunction_nonlinear, 10)
	# Run a verifier and then filter its result
	Verifiers.VERIFIER_CALLBACKS["NNEnum"](network_path, SMTFilter, olnnv_query)
end
```
"""
function get_star_filter(ctx, variables, disjunction_nonlinear, smt_timeout)
	return function(result :: OlnnvResult)
		smt_cache = Dict()
		@timeit TIMER "star_filter" begin
			if result.status == "safe"
				return result
			else
				filtered_stars = []
				for s in result.stars
					res, s = check_star(ctx,variables, disjunction_nonlinear, s, smt_cache)
					if res > 0
						push!(filtered_stars, Star(s,res==1))
					end
				end
				filtered_out = length(result.stars)-length(filtered_stars)
				num_timeout = count(s->!s.certain,filtered_stars)
				if length(result.stars) > 1
					print_msg("[SMT] SMT filtered out ",filtered_out," stars (out of ",length(result.stars),"; TO: ",num_timeout,").")
				end
				if length(filtered_stars) == 0
					return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
					#return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
				else
					return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
					#return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
				end
			end
		end
	end
end

# function get_star_filter(ctx, variables, formula, smt_timeout)
# 	return smt_solver(ctx;stars=true) do solver
# 		#set(solver,"ctrl_c",  true)
# 		set(solver,"unsat-core",false)
# 		additional = []
# 		smt_cache = Dict()
# 		translated = ast2smt(formula, variables, additional, smt_cache)
# 		smt_internal_add(solver, translated)
# 		for a in additional
# 			smt_internal_add(solver, a)
# 		end
# 		solverres = smt_internal_check(solver)
# 		if !smt_internal_is_sat(solverres)
# 			smt_internal_debug(solver, solverres)
# 			@assert !smt_internal_is_unsat(solverres) "Solver result was unsat but should be sat"
# 		end
# 		return function(result :: OlnnvResult)
# 			@timeit TIMER "star_filter" begin
# 				if result.status == "safe"
# 					return result
# 				else
# 					filtered_stars = filter(!=(nothing),map(star_concrete_filter(solver, variables, smt_timeout),result.stars))
# 					filtered_out = length(result.stars)-length(filtered_stars)
# 					print_msg("[SMT] SMT filtered out ",filtered_out," stars (out of ",length(result.stars),").")
# 					if length(filtered_stars) == 0
# 						return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
# 						#return OlnnvResult(Safe, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
# 					else
# 						return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out), filtered_stars)
# 						#return OlnnvResult(result.status, SmtFilterMeta(result.metadata,filtered_out, formula), filtered_stars)
# 					end
# 				end
# 			end
# 		end
# 	end
# end
# function star_concrete_filter(solver, variables, smt_timeout)
# 	return function(star :: Star)
# 		@timeit TIMER "star_filter_concrete" begin
# 			# @info "BEFORE:"
# 			# print(solver)
# 			smt_cache = Dict()
# 			smt_internal_push(solver)
# 			input_vars = size(star.constraint_matrix)[2]
# 			additional = []
# 			for (c,b) in zip(eachrow(star.constraint_matrix),star.constraint_bias)
# 				smt_internal_add(solver, ast2smt(LinearConstraint(c,b,true), variables, additional, smt_cache))
# 			end
# 			for (i, b) in enumerate(star.bounds)
# 				smt_internal_add(solver, ast2smt(Atom(AST.LessEq, TermNumber(b[1]),Variable("x"*string(i), nothing, i)),variables, additional, smt_cache))
# 				smt_internal_add(solver, ast2smt(Atom(AST.LessEq, Variable("x"*string(i), nothing, i), TermNumber(b[2])),variables, additional, smt_cache))
# 			end
# 			for a in additional
# 				smt_internal_add(solver, a)
# 			end
# 			# Check if input even relevant
# 			additional = []
# 			result = nothing
# 			smt_time=0
# 			smt_time = @elapsed begin
# 				try
# 					result = smt_internal_check(solver)
# 				catch e
# 					print_msg("[SMT] solver threw error: ",e)
# 				end
# 			end
# 			#TODO(steuber): SMT time Statistics
# 			if !isnothing(result) && smt_internal_is_unsat(result)
# 				#print_msg("[SMT] Filter took ",smt_time," seconds (pre).")
# 				smt_internal_pop(solver)
# 				return nothing
# 			elseif smt_time > smt_timeout
# 				print_msg("[SMT] Filter took ",smt_time," seconds (pre TO).")
# 				smt_internal_debug(solver, result)
# 				smt_internal_pop(solver)
# 				return Star(star,false)
# 			end
# 			# If input is relevant, then we need to check if there exists a counter-example for the current output mapping...
# 			for (i,(c,b)) in enumerate(zip(eachrow(star.output_map_matrix),star.output_map_bias))
# 				smt_internal_add(solver, ast2smt(Atom(AST.Eq, Variable("x"*string(input_vars+i), nothing, input_vars+i), LinearTerm(c,b)), variables, additional, smt_cache))
# 			end
# 			@assert length(additional) == 0
# 			result = nothing
# 			smt_time += @elapsed begin
# 				try
# 					result = smt_internal_check(solver)
# 				catch e
# 					print_msg("[SMT] solver threw error: ",e)
# 				end
# 			end
# 			not_known = isnothing(result) || (!smt_internal_is_unsat(result) && !smt_internal_is_sat(result))
# 			#print_msg("[SMT] Filter took ",smt_time," seconds (",((not_known) ? "post TO" : "full"),").")
# 			# @info "AFTER:"
# 			# print(solver)
# 			#@info "SMT Result: ", result
# 			if not_known
# 				print_msg("[SMT] Filter took ",smt_time," seconds (post TO).")
# 				smt_internal_debug(solver, result)
# 			end
# 			smt_internal_pop(solver)
# 			# @info "AFTER POP:"
# 			# print(solver)
# 			if !isnothing(result) && smt_internal_is_unsat(result)
# 				return nothing
# 			elseif !isnothing(result) && smt_internal_is_sat(result)
# 				return Star(star,true)
# 			else
# 				return Star(star,false)
# 			end
# 		end
# 	end
# end