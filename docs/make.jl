using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "..")))
Pkg.instantiate()

using Documenter
using NCubeV

# Note: We deliberately do not load NCubeV here to avoid precompilation issues
# (e.g., macro-generated structs with attached docstrings and Z3 JLL setup).
# To enable API docs, add `using NCubeV` and set `modules=[NCubeV]`, then
# include "api.md" in the pages list.

makedocs(
    sitename = "NCubeV.jl",
    modules = [NCubeV],
    format = Documenter.HTML(prettyurls = get(ENV, "CI", "false") == "true"),
    warnonly = true,
    pages = [
        "Home" => "index.md",
        "How to use" => "howto.md",
        "API" => [
            "Overview" => "api.md",
            "NCubeV (top-level)" => "api/ncubev.md",
            "AST" => "api/ast.md",
            "Approx" => "api/approx.md",
            "Parsing" => "api/parsing.md",
            "Analysis" => "api/analysis.md",
            "LP" => "api/lp.md",
            "QueryGeneration" => "api/querygeneration.md",
            "SMTInterface" => "api/smtinterface.md",
            "Verifiers" => "api/verifiers.md",
            "VerifierInterface" => "api/verifierinterface.md",
            "Control" => "api/control.md",
            "Cmd" => "api/cmd.md",
            "Util" => "api/util.md",
            "Config" => "api/config.md",
        ],
    ],
)

# Optional: deploy via GitHub Actions (disabled by default)
deploydocs(
    repo = "github.com/samysweb/NCubeV.git",
    devbranch="cleanup-0.10",
    branch = "gh-pages"
)
