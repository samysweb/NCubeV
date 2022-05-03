# ACC: Preliminary results
## Utility of Approximation
How many star sets returned with or without (approximated) nonlinear constraints?  
First number: star sets visited; second number: star sets returned as potentially unsafe
```
julia>using SNNT
julia>SNNT.Config.set_include_approximations(true)
julia>@time include("test.jl") # 2x for compilation
....
83.021697 seconds (195.93 M allocations: 9.579 GiB, 5.52% gc time, 39.64% compilation time)
julia> print(collect(zip(map(x->(isnothing(x)) ? 0 : x[2],results),map(x->(isnothing(x)) ? 0 : length(x[3][2]),results))))
[(2, 2), (6, 6), (9, 9), (6, 6), (491, 491), (0, 0), (0, 0), (0, 0), (36, 0), (382, 4), (162, 0), (0, 0), (0, 0), (0, 0), (0, 0)]
julia> print(sum(map(x->(isnothing(x)) ? 0 : length(x[3][2]),results)))
518
julia>SNNT.Config.set_include_approximations(false)
julia>include("test.jl") # 2x for compilation
....
106.741297 seconds (195.28 M allocations: 9.546 GiB, 4.57% gc time, 31.39% compilation time)
julia> print(collect(zip(map(x->(isnothing(x)) ? 0 : x[2],results),map(x->(isnothing(x)) ? 0 : length(x[3][2]),results))))
[(13, 13), (16, 16), (38, 38), (41, 41), (833, 830), (0, 0), (0, 0), (0, 0), (41, 0), (833, 11), (1107, 3), (0, 0), (0, 0), (0, 0), (0, 0)]
julia> print(sum(map(x->(isnothing(x)) ? 0 : length(x[3][2]),results)))
952
```