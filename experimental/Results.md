# ACC: Preliminary results
## Utility of Approximation
How many star sets returned with or without (approximated) nonlinear constraints?  
First number: star sets visited; second number: star sets returned as potentially unsafe
```
julia>using SNNT
julia>SNNT.Config.set_include_approximations(true)
julia>@time include("test.jl") # 2x for compilation
....
63.149900 seconds (110.34 M allocations: 5.329 GiB, 6.19% gc time, 27.01% compilation time)
julia> print(collect(zip(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results),map(x->(isnothing(x)) ? -1 : length(x.stars),results))))
[(2, 0), (6, 4), (9, 7), (6, 1), (491, 74), (0, 0), (36, 0), (382, 0), (162, 0), (0, 0), (0, 0), (0, 0)]
julia> print(sum(map(x->(isnothing(x)) ? 0 : length(x.stars),results)))
86
julia> print(sum(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results)))
1094
julia>SNNT.Config.set_include_approximations(false)
julia>include("test.jl") # 2x for compilation
....
36.320003 seconds (19.87 M allocations: 884.033 MiB, 5.49% gc time, 0.29% compilation time)
julia> print(collect(zip(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results),map(x->(isnothing(x)) ? -1 : length(x.stars),results))))
[(847, 80), (1126, 1)]
julia> print(sum(map(x->(isnothing(x)) ? 0 : length(x.stars),results)))
81
julia> print(sum(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results)))
1973
```
# Model of twice the size (i.e. 4 layers with 64 nodes instead of 2 layers with 64 nodes)
```
julia>using SNNT
julia>SNNT.Config.set_include_approximations(true)
julia>@time include("test2.jl") # 2x for compilation
763.385032 seconds (125.12 M allocations: 5.813 GiB, 0.79% gc time, 3.18% compilation time)
julia> print(collect(zip(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results),map(x->(isnothing(x)) ? -1 : length(x.stars),results))))
[(1, 0), (0, 0), (33, 5), (36, 1), (5893, 136), (57, 0), (86, 0), (274, 0), (459, 0), (69, 0), (61, 0), (0, 0)]
julia> print(sum(map(x->(isnothing(x)) ? 0 : length(x.stars),results)))
142
julia> print(sum(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results)))
6969
julia>SNNT.Config.set_include_approximations(false)
julia>@time include("test2.jl") # 2x for compilation
....
1002.231934 seconds (77.07 M allocations: 2.737 GiB, 0.45% gc time, 0.01% compilation time)
julia> print(collect(zip(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results),map(x->(isnothing(x)) ? -1 : length(x.stars),results))))
[(6069, 142), (17051, 11)]
julia> print(sum(map(x->(isnothing(x)) ? 0 : length(x.stars),results)))
153
julia> print(sum(map(x->(isnothing(x.metadata)) ? 0 : x.metadata,results)))
23120
```
With Approximation:
Z3 filters 5878 stars
Without Approximation:
Z3 filters 22826 stars