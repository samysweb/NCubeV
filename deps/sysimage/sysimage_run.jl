Base.reinit_stdio()
# set up depot & load paths to be able to find stdlib packages
Base.init_load_path()
Base.init_depot_path()

println(homedir())
println(Base.load_path())
@show LOAD_PATH
@show DEPOT_PATH
using SNNT

println("SNNT loaded, beginning precompilation...")
@eval Module() begin
    for (pkgid, mod) in Base.loaded_modules
        if !(pkgid.name in ("Main", "Core", "Base"))
			try
            	eval(@__MODULE__, :(const $(Symbol(mod)) = $mod))
			catch
				println("Failed to load module: $mod")
			end
        end
    end
    for statement in readlines("/tmp/snnt_trace.jl")
        try
            Base.include_string(@__MODULE__, statement)
        catch
            # See julia issue #28808
            println("failed to compile statement: $statement")
        end
    end
end # module

empty!(LOAD_PATH)
empty!(DEPOT_PATH)