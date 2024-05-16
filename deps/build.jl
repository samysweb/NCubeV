@info "Initiating build of SNNT"
using Pkg

@info "Building PyCall"
ENV["PYTHON"] = ""
pkg"build PyCall"
@info "Loading Conda"
using Conda
@info "Installing packages necessary for NNEnum"
Conda.add("certifi")
Conda.add("python=3.8")
Conda.pip_interop(true)
Conda.pip("install",["numpy","scipy==1.7","threadpoolctl==3.5","onnx==1.9.0","onnxruntime==1.8.0","skl2onnx==1.7.0","swiglpk","termcolor","packaging"])
Conda.pip("install",["cvc5"])

@info "Building Sysimage..."
using PackageCompiler
deps_dir = @__DIR__
create_app("$deps_dir/../", "NCubeV", precompile_execution_file="$deps_dir/sysimage/trace_run.jl",executables= ["NCubeV" => "main_NCubeV"],incremental=true,force=true)

@info "SNNT can be found in the bin directory"