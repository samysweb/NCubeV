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

function nl_feasible(constraints :: Vector{Union{Formula}}, ctx, variables,conflicts;print_model=false)
    return true
end

function lin_feasible(constraints :: Vector{LinearConstraint}, ctx, variables,conflicts;print_model=false)
    return true
end

function get_star_filter(ctx, variables, disjunction_nonlinear, smt_timeout)
	return function(result :: OlnnvResult)
        return result
    end
end

function smt_context(f, varnum :: Int64)
    res = nothing
    begin
        print_msg("[SMT] Starting ", Config.SMT_SOLVER, " context...")
        solver = SMT_SOLVERS[Config.SMT_SOLVER]
        # Setup of SMT Context
        ctx = solver.get_context(varnum)
        # Run program
        res = GC.@preserve ctx f(ctx)
    end
    # Cleanup SMT Context
    GC.gc(true)
    return res
end

end