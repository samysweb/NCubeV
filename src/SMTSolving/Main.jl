module SMTSolving

using MLStyle
using TimerOutputs

using ..Util
using ..AST
using ..VerifierInterface
using ..Config

# SMT Solver Registry
include("Registry.jl")

# SMT Solver Interface
include("SMTInterface.jl")
using .SMTInterface

# AST 2 SMT Routines
include("AST2SMT.jl")

# Register SMT Solvers
include("Z3/Main.jl")

export nl_feasible, lin_feasible, get_star_filter, smt_context, set_use_cores, SMTSolver

function preprocess_constraints(constraints, ctx, slv, solver)
    actx = solver.get_ast_context(ctx)
    @timeit Config.TIMER "SMTprep" begin
        for (i,c) in enumerate(constraints)
            translated = ast2smt(c, actx, solver)
            solver.solve.add_constraint(slv, translated; idx=i)
        end
    end
    solver.solve.process_ast_context(slv, actx)
end

function smt_check_feasible(slv, solver, conflicts;print_model=false)
    @timeit Config.TIMER "SMTcheck" begin
        res = solver.solve.check_sat(slv)
        if solver.solve.is_sat(res)
            if print_model
                solver.solve.get_model(slv, res) do m
                    solver.solve.print_model(m)
                end
            end
        elseif !solver.solve.is_unsat(res)
            print_msg("[SMT] SMT returned unknown")
        else # unsat
            #print_msg("[SMT] Conflict:")
            for c in solver.solve.get_core(slv)
                push!(conflicts, c)
            end
        end
        return !solver.solve.is_unsat(res)
    end
end

function nl_feasible(constraints :: Vector{Formula}, ctx,conflicts;print_model=false)
    solver = Registry.SMT_SOLVERS[Config.SMT_SOLVER]
    return solver.get_solver(ctx,"qfnra") do slv
        preprocess_constraints(constraints, ctx, slv, solver)
        return smt_check_feasible(slv, solver, conflicts;print_model=print_model)        
    end
end

function lin_feasible(constraints :: Vector{LinearConstraint}, ctx,conflicts;print_model=false)
    solver = Registry.SMT_SOLVERS[Config.SMT_SOLVER]
    return solver.get_solver(ctx,"qflra") do slv
        preprocess_constraints(constraints, ctx, slv, solver)
        return smt_check_feasible(slv, solver, conflicts;print_model=print_model)        
    end
end

function get_star_filter(ctx, variables, disjunction_nonlinear, smt_timeout)
	return function(result :: OlnnvResult)
        return result
    end
end

function smt_context(f, varnum :: Int64)
    print_msg("[SMT] Starting ", Config.SMT_SOLVER, " context...")
    solver = Registry.SMT_SOLVERS[Config.SMT_SOLVER]
    # Setup of SMT Context
    return solver.get_context(f, varnum)
end

end