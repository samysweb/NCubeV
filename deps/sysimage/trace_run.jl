dep_dir = @__DIR__
args = [
	joinpath(@__DIR__,"../../test/parsing/examples/acc/formula")
	joinpath(@__DIR__,"../../test/parsing/examples/acc/fixed")
	joinpath(@__DIR__,"../../test/parsing/examples/acc/mapping")
	joinpath(@__DIR__,"../../test/networks/acc-3000000-64-64.onnx")
	"/tmp/results.jld"
]
using SNNT
SNNT.run_cmd(args)

SNNT.run_cmd([["--rigorous"];args])

SNNT.run_cmd([["--linear"];args])

rm("/tmp/results.jld")
