
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

export PicoPtr,  picosat_init, picosat_reset, add_clause, add_clauses

export next_var, push, pop, solve, picosat_set_more_important_lit

next_var(p::PicoPtr) = ccall((:picosat_inc_max_var, libpicosat), Cint, (PicoPtr,), p)
push(p::PicoPtr) = ccall((:picosat_push, libpicosat), Cint, (PicoPtr,), p)
pop(p::PicoPtr) = ccall((:picosat_pop, libpicosat), Cint, (PicoPtr,), p)
# void picosat_set_more_important_lit (PicoSAT *, int lit);
picosat_set_more_important_lit(p::PicoPtr, lit::Int) = ccall(
    (:picosat_set_more_important_lit, libpicosat), Cvoid, (PicoPtr, Cint), p, lit
)

function solve(p::PicoPtr)
    @timeit Config.TIMER "PicoSAT_solve" begin
        res =  PicoSAT.picosat_sat(p, -1)
    end
    if res == PicoSAT.SATISFIABLE
        result = PicoSAT.get_solution(p)
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
