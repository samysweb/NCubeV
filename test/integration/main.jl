
@testset verbose = true "Integration Tests" begin
    @testset verbose = true "SAT" begin
        dep_dir = @__DIR__
        cmd_args = [
            joinpath(@__DIR__,"../../test/parsing/examples/acc/formula")
            joinpath(@__DIR__,"../../test/parsing/examples/acc/fixed")
            joinpath(@__DIR__,"../../test/parsing/examples/acc/mapping")
            joinpath(@__DIR__,"../../test/networks/acc-3000000-64-64.onnx")
            "/tmp/results.jld"
        ]
        args = NCubeV.Cmd.parse_commandline(cmd_args)
        result, cex_count = NCubeV.Cmd.run_internal(args)
        @test (cex_count == 88)
    end
    @testset verbose = true "UNSAT" begin
        dep_dir = @__DIR__
        cmd_args = [
            joinpath(@__DIR__,"../../test/parsing/examples/acc/formula-fallback")
            joinpath(@__DIR__,"../../test/parsing/examples/acc/fixed")
            joinpath(@__DIR__,"../../test/parsing/examples/acc/mapping")
            joinpath(@__DIR__,"../../test/networks/acc-2000000-64-64-64-64-retrain-100000-200000-0.9.onnx")
            "/tmp/results.jld"
        ]
        args = NCubeV.Cmd.parse_commandline(cmd_args)
        result, cex_count = NCubeV.Cmd.run_internal(args)
        @test (cex_count == 0)
    end
end
