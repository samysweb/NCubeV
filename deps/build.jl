@info "Initiating build of SNNT"
using Pkg

@info "Loading Conda"
using Conda
@info "Installing packages necessary for NNEnum"
Conda.add("python=3.8", :nnenum)
Conda.add("certifi", :nnenum)
Conda.pip_interop(true, :nnenum)
Conda.pip("install", [
    "numpy",
    "scipy==1.7",
    "threadpoolctl==3.5",
    "onnx==1.9.0",
    "onnxruntime==1.8.0",
    "skl2onnx==1.7.0",
    "swiglpk",
    "termcolor",
    "packaging",
    "cvc5"
], :nnenum)

ENV["PYTHON"] = joinpath(Conda.bin_dir(:nnenum),"python")
pkg"build PyCall"

@info "Building Sysimage..."
using PackageCompiler
deps_dir = @__DIR__
create_app("$deps_dir/../", "NCubeV", precompile_execution_file="$deps_dir/sysimage/trace_run.jl",executables= ["NCubeV" => "main_NCubeV"],incremental=true,force=true)

@info "SNNT can be found in the bin directory"