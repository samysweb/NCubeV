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
Conda.pip("install",["numpy","scipy==1.7","threadpoolctl","onnx==1.9.0","onnxruntime==1.8.0","skl2onnx==1.7.0","swiglpk","termcolor","packaging"])
Conda.pip("install",["cvc5"])
@info "Building Sysimage..."
include("sysimage/build_sysimage.jl")

@info "SNNT can be found in the bin directory"