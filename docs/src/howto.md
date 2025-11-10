# How to use NCubeV

This guide shows the end-to-end flow and how the modules connect:

Cmd → Control → QueryGeneration → SMTInterface → Verifiers

## CLI usage (recommended)

After building the tool (see README), run:

```bash
./deps/NCubeV/bin/NCubeV <formula> <fixed> <mapping> <onnx> <result-prefix>
```

Useful flags:
- `--smt Z3`
- `--approx N` controls approximation density
- `--rigorous` enables SMT-based validation of approximations
- `--no-cores` disables activation literals for unsat cores (helps for high-degree polynomials)

## Programmatic usage

Below is a minimal sketch connecting the core modules. It mirrors the CLI and highlights the responsibilities of each stage.

```julia
using NCubeV
using NCubeV: Cmd, Control, SMTInterface, Verifiers

# 1) Parse/prepare a query
initial = Control.load_query(formula_path, fixed_dict, mapping_dict)
prepared = Control.prepare_for_olnnv(initial)

# 2) Create an SMT context (Z3 by default; see Config.set_smt_solver)
smttimeout_s = 10  # seconds for the star-filter queries
result = SMTInterface.smt_context(prepared.num_input_vars + prepared.num_output_vars; timeout = smttimeout_s*1000) do (ctx, variables)
    # 3) Run Mosaic iteration and verification with a chosen verifier
    Control.run_query(prepared, ctx, smttimeout_s, variables; backup="/tmp/ncubev", backup_meta=Dict()) do (linear_term, SMTFilter)
        Verifiers.VERIFIER_CALLBACKS["NNEnum"](onnx_path, SMTFilter, linear_term)
    end
end
```

What happens in the callback?
- `Control.run_query` iterates over the Mosaic tiles (QueryGeneration)
- For each tile, it yields `(linear_term, SMTFilter)`
- The verifier (e.g. `NNEnum`) uses `linear_term` to search for counterexamples
- Each candidate region is checked or filtered via `SMTFilter` (SMTInterface StarFilter)

## Advanced knobs

- `Config.set_smt_solver("Z3")` or `Config.set_smt_solver("CVC5")`
- `Approx.set_approx_density(N)` to increase/decrease piecewise linear detail
- `Config.set_rigorous_approximations(true)` to validate approximations
- `SMTInterface.USE_CORES = false` to disable unsat-core extraction

See the API page for more functions and details.
