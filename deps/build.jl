@info "Initiating build of SNNT"
using Pkg, Conda

const ENVNAME = :ncubev
# # Single solve, separate env – root env stays untouched
# Conda.add(["python=3.8", "pip", "certifi", "numpy==1.21", "scipy=1.7",
#            "threadpoolctl=3.5", "onnx=1.9.0"], ENVNAME; channel="conda-forge")

# pip = joinpath(Conda.bin_dir(ENVNAME), "pip")
# run(`$pip install onnxruntime==1.8.0 skl2onnx==1.7.0 swiglpk termcolor packaging cvc5 protobuf==3.20.2 numpy==1.21`)

ENV["PYTHON"] = joinpath(Conda.bin_dir(ENVNAME), "python")
# Pkg.build("PyCall")   # functional API, no REPL-mode warning

@info "Building Sysimage..."
using PackageCompiler
deps_dir = @__DIR__
create_app("$deps_dir/../", "NCubeV", precompile_execution_file="$deps_dir/sysimage/trace_run.jl",executables= ["NCubeV" => "main_NCubeV"],incremental=true,force=true)

@info "SNNT can be found in the bin directory"