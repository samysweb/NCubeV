struct FeasibilityCache
    sat_instance :: PicoPtr
    free_var :: Ref{Int64}
    function FeasibilityCache(max_used_var :: Int64)
        sat_instance = picosat_init()
        for i in 1:max_used_var
            j = next_var(sat_instance)
            @assert i==j
        end
        free_var = next_var(sat_instance)
        add_clause(sat_instance, [-free_var])
        return new(sat_instance, Ref{Int64}(free_var))
    end
end

function add_feasible(cache :: FeasibilityCache, combination :: Vector{Int64})
    @timeit Config.TIMER "feasibility_cache_add" begin
        conjunction_var = next_var(cache.sat_instance)
        for literal in combination
            #print_msg([-conjunction_var, literal])
            add_clause(cache.sat_instance, [-conjunction_var, literal])
        end
        #print_msg([map(x->-x, combination);[conjunction_var]])
        add_clause(cache.sat_instance, [map(x->-x, combination);[conjunction_var]])
        new_free_var = next_var(cache.sat_instance)
        #print_msg([cache.free_var[], conjunction_var, -new_free_var[]])
        add_clause(cache.sat_instance, [cache.free_var[], conjunction_var, -new_free_var[]])
        cache.free_var[] = new_free_var
    end
end

function check_feasible(cache :: FeasibilityCache, combination :: Vector{Int64})
    return @timeit Config.TIMER "feasibility_cache_check" begin
        push(cache.sat_instance)
        add_clause(cache.sat_instance,cache.free_var)
        for literal in combination
            add_clause(cache.sat_instance, [literal])
        end
        result = solve(cache.sat_instance)
        pop(cache.sat_instance)
        return result != :unsatisfiable
    end
end