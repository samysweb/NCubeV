
# Some extensions and additional exports for the PicoSAT interface
module InternalPicoSAT
using PicoSAT
using ....Config
using TimerOutputs
#import PicoSAT : picosat_init, picosat_reset, add_clause, add_clauses, get_solution

PicoPtr = PicoSAT.PicoPtr
libpicosat = PicoSAT.libpicosat
picosat_init = PicoSAT.picosat_init
picosat_reset = PicoSAT.picosat_reset
add_clause = PicoSAT.add_clause
add_clauses = PicoSAT.add_clauses
get_solution = PicoSAT.get_solution
picosat_set_verbosity = PicoSAT.picosat_set_verbosity

export PicoPtr, picosat_init, save_original_clauses, picosat_reset, add_clause, add_clauses, get_partial_solution, picosat_set_verbosity

export next_var, push, pop, solve, picosat_set_more_important_lit

next_var(p::PicoPtr) = ccall((:picosat_inc_max_var, libpicosat), Cint, (PicoPtr,), p)
push(p::PicoPtr) = ccall((:picosat_push, libpicosat), Cint, (PicoPtr,), p)
pop(p::PicoPtr) = ccall((:picosat_pop, libpicosat), Cint, (PicoPtr,), p)
save_original_clauses(p::PicoPtr) = ccall((:picosat_save_original_clauses, libpicosat), Cvoid, (PicoPtr,), p)
picosat_deref_partial(p::PicoPtr, lit::Integer) =
    ccall((:picosat_deref_partial, libpicosat), Cint, (PicoPtr,Cint), p, lit)
# void picosat_set_more_important_lit (PicoSAT *, int lit);
picosat_set_more_important_lit(p::PicoPtr, lit::Int) = ccall(
    (:picosat_set_more_important_lit, libpicosat), Cvoid, (PicoPtr, Cint), p, lit
)

function get_partial_solution(p::PicoPtr)
    nvar = PicoSAT.picosat_variables(p)
    if nvar < 0
        PicoSAT.picosat_reset(p)
        throw(ErrorException("number of solution variables < 0"))
    end
    sol = zeros(Int, nvar)
    array_pos = 1
    for i = 1:nvar
        v = picosat_deref_partial(p, i)
        if v!=0
            sol[array_pos] = v * i
            array_pos+=1
        end
    end
    return sol[1:(array_pos-1)]
end

function solve(p::PicoPtr)
    @timeit Config.TIMER "PicoSAT_solve" begin
        res =  PicoSAT.picosat_sat(p, -1)
    end
    if res == PicoSAT.SATISFIABLE
        #result = PicoSAT.get_solution(p)
        # Use partial models to improve efficency -> no need to iterate "both sides"
        result = get_partial_solution(p)
    elseif res == PicoSAT.UNSATISFIABLE
        result = :unsatisfiable
    elseif res == PicoSAT.UNKNOWN
        result = :unknown
    else
        throw(ErrorException("PicoSAT Error: return value $res"))
    end
    return result
end

end

using .InternalPicoSAT
