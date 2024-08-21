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
# Update PyCall build so that it knows that we run on Python 3.8
pkg"build PyCall"
#Conda.pip_interop(true)
Conda.add("numpy")
Conda.add("scipy==1.7")
Conda.add("threadpoolctl==3.5")
Conda.add("onnx==1.9.0")
Conda.add("onnxruntime==1.8.0")
Conda.add("skl2onnx==1.7.0")
Conda.add("swiglpk")
Conda.add("termcolor")
Conda.add("packaging")
Conda.add("cvc5")

@info "Building Sysimage..."
using PackageCompiler
deps_dir = @__DIR__
create_app("$deps_dir/../", "NCubeV", precompile_execution_file="$deps_dir/sysimage/trace_run.jl",executables= ["NCubeV" => "main_NCubeV"],incremental=true,force=true)

@info "SNNT can be found in the bin directory"