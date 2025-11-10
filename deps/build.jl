@info "Initiating build of NCubeV"
using Pkg

@info "Loading Conda"
using Conda

_pip() = Sys.iswindows() ? "pip.exe" : "pip"

# Conda's pip check is broken (`pip_interop_enabled` vs. `prefix_data_interoperability`)
function _pip(env::Conda.Environment)
    "pip" ∉ Conda._installed_packages(env) && Conda.add("pip", env)
    joinpath(Conda.script_dir(env), _pip())
end

function pip(cmd::AbstractString, pkgs::Conda.PkgOrPkgs, env::Conda.Environment=Conda.ROOTENV)
    # parse the pip command
    _cmd = String[split(cmd, " ")...]
    @info("Running $(`pip $_cmd $pkgs`) in $(env==Conda.ROOTENV ? "root" : env) environment")
    run(Conda._set_conda_env(`$(_pip(env)) $_cmd $pkgs`, env))
    nothing
end

@info "Installing packages necessary for NNEnum"
Conda.add("python=3.8", :nnenum)
Conda.add("certifi", :nnenum)
Conda.pip_interop(true, :nnenum)
pip("install", [
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

@info "NCubeV can be found in the bin directory"