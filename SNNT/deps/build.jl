@info "Initiating build of SNNT"
using Pkg

@info "Building PyCall"
ENV["PYTHON"] = ""
pkg"build PyCall"
@info "Loading Conda"
using Conda
@info "Installing packages necessary for NNEnum"
Conda.pip("install",["numpy","scipy","threadpoolctl","onnx==1.9.0","onnxruntime==1.8.0","skl2onnx==1.7.0","swiglpk","termcolor"])