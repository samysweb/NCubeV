function run_cmd(cmd)
	cmd = detach(cmd)
	err_io = IOBuffer(append=true)
	cmd =pipeline(cmd,stderr=err_io)
	open(cmd) do std_out
		for cur_line in eachline(std_out)
			@info "[OUT]", cur_line
			err_cache = readchomp(err_io)
			if length(err_cache) > 0
				@info "[ERR]", err_cache
			end
		end
	end
	if !isnothing(err_io)
		err_cache = readchomp(err_io)
		if length(err_cache) > 0
			@info "[ERR]", err_cache
		end
		close(err_io)
	end
end

function build_sysimage()
	# Based on information here: https://julialang.github.io/PackageCompiler.jl/dev/devdocs/sysimages_part_1.html
	# Execute a trace run of the software
	dep_dir = @__DIR__
	cmd_trace = `julia --startup-file=no --compile=all --trace-compile=/tmp/snnt_trace.jl $dep_dir/trace_run.jl`
	@info "Running ", cmd_trace
	cmd_trace = addenv(cmd_trace,"OPENBLAS_NUM_THREADS" => "1","OMP_NUM_THREADS" => "1","JULIA_DEPOT_PATH" => join(DEPOT_PATH,":"), "JULIA_LOAD_PATH" => join(Base.load_path(),":"))
	run_cmd(cmd_trace)
	# Now /tmp/snnt_trace.jl should contain all the necessary precompiles...
	base_sys_image = unsafe_string(Base.JLOptions().image_file)
	cmd_build = `julia --startup-file=no --optimize=3 --output-o $dep_dir/snnt_sys.o -J"$base_sys_image" $dep_dir/sysimage_run.jl`
	@info "Running ", cmd_build
	cmd_build = addenv(cmd_build,"JULIA_DEPOT_PATH" => join(DEPOT_PATH,":"), "JULIA_LOAD_PATH" => join(Base.load_path(),":"))
	run_cmd(cmd_build)
	rm("/tmp/snnt_trace.jl")
	# Now we need to do the linking...
	gcc_lib_path = abspath(Sys.BINDIR, Base.LIBDIR)
	cmd_gcc = `gcc -shared -o $dep_dir/../../bin/sys.so -Wl,--whole-archive $dep_dir/snnt_sys.o -Wl,--no-whole-archive -L"$gcc_lib_path" -ljulia`
	run_cmd(cmd_gcc)
	rm("$dep_dir/snnt_sys.o")
end

function create_callable()
	dep_dir = @__DIR__
	sysimg_path = joinpath(dep_dir,"../../bin/sys.so")
	try
		rm(joinpath(dep_dir,"../../bin"), recursive=true)
	catch e
		@info "Failed to remove bin directory: ", e
	end
	mkdir(joinpath(dep_dir,"../../bin"))
	open(joinpath(dep_dir,"../../bin/SNNT"), "w") do f
		println(f, "#!/usr/bin/julia -J$sysimg_path")
		println(f, "using SNNT")
		println(f, "SNNT.run_cmd(ARGS)")
	end
	chmod(joinpath(dep_dir,"../../bin/SNNT"), 0o755)
end

build_sysimage()
create_callable()