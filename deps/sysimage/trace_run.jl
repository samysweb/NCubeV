dep_dir = @__DIR__
args = [
	joinpath(@__DIR__,"../../test/parsing/examples/acc/formula")
	joinpath(@__DIR__,"../../test/parsing/examples/acc/fixed")
	joinpath(@__DIR__,"../../test/parsing/examples/acc/mapping")
	joinpath(@__DIR__,"../../test/networks/acc-3000000-64-64.onnx")
	"/tmp/results.jld"
]
using NCubeV
NCubeV.run_cmd(args)

NCubeV.run_cmd([["--rigorous"];args])
NCubeV.run_cmd([["--no-normalization","--no-cores"];args])
