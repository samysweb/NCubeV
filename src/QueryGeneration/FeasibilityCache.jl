# struct FeasibilityCache
#     sat_instance :: PicoPtr
#     free_var :: Ref{Int64}
#     function FeasibilityCache(max_used_var :: Int64)
#         sat_instance = picosat_init()
#         for i in 1:max_used_var
#             j = next_var(sat_instance)
#             @assert i==j
#         end
#         free_var = next_var(sat_instance)
#         add_clause(sat_instance, [-free_var])
#         cache = new(sat_instance, Ref{Int64}(free_var))
#         finalizer(x -> picosat_reset(x.sat_instance), cache)
#         return cache
#     end
# end

struct FeasibilityCache
    combinations :: Vector{Vector{Int64}}
    function FeasibilityCache(max_used_var :: Int64)
        combinations = Vector{Vector{Int64}}()
        cache = new(combinations)
        return cache
    end
end

struct MultiFeasibilityCache
    linear :: FeasibilityCache
    bound_linear :: FeasibilityCache
    approx :: FeasibilityCache
    nonlinear :: FeasibilityCache
    bound_nonlinear :: FeasibilityCache
    no_approx :: FeasibilityCache
    all :: FeasibilityCache
    function MultiFeasibilityCache(max_used_var :: Int64)
        linear = FeasibilityCache(max_used_var)
        bound_linear = FeasibilityCache(max_used_var)
        approx = FeasibilityCache(max_used_var)
        nonlinear = FeasibilityCache(max_used_var)
        bound_nonlinear = FeasibilityCache(max_used_var)
        no_approx = FeasibilityCache(max_used_var)
        all = FeasibilityCache(max_used_var)
        return new(linear, bound_linear, approx, nonlinear, bound_nonlinear, no_approx, all)
    end
end

# function add_feasible(cache :: FeasibilityCache, combination :: Vector{Int64})
#     @timeit Config.TIMER "feasibility_cache_add" begin
#         conjunction_var = next_var(cache.sat_instance)
#         for literal in combination
#             #print_msg([-conjunction_var, literal])
#             add_clause(cache.sat_instance, [-conjunction_var, literal])
#         end
#         #print_msg([map(x->-x, combination);[conjunction_var]])
#         add_clause(cache.sat_instance, [map(x->-x, combination);[conjunction_var]])
#         new_free_var = next_var(cache.sat_instance)
#         #print_msg([cache.free_var[], conjunction_var, -new_free_var[]])
#         add_clause(cache.sat_instance, [cache.free_var[], conjunction_var, -new_free_var[]])
#         cache.free_var[] = new_free_var
#     end
# end
function add_feasible(cache :: FeasibilityCache, combination :: Vector{Int64})
    @timeit Config.TIMER "feasibility_cache_add" begin
        push!(cache.combinations, sort(combination))
    end
end

# function check_feasible(cache :: FeasibilityCache, combination :: Vector{Int64})
#     return @timeit Config.TIMER "feasibility_cache_check" begin
#         push(cache.sat_instance)
#         add_clause(cache.sat_instance,cache.free_var)
#         for literal in combination
#             add_clause(cache.sat_instance, [literal])
#         end
#         result = solve(cache.sat_instance)
#         pop(cache.sat_instance)
#         return result != :unsatisfiable
#     end
# end

function check_feasible(cache :: FeasibilityCache, combination :: Vector{Int64})
    return @timeit Config.TIMER "feasibility_cache_check" begin
        sort!(combination)
        c_len = length(combination)
        for c in cache.combinations
            index = 1
            for i in c
                if @inbounds i > combination[index]
                    break
                elseif @inbounds i == combination[index]
                    index += 1
                    if index > c_len
                        return true
                    end
                end
            end
        end
        return false
    end
end