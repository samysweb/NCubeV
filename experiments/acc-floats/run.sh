SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acc-floats/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 julia --project=. ./src/cli.jl test/parsing/examples/acc-floats/formula test/parsing/examples/acc-floats/fixed test/parsing/examples/acc-floats/mapping test/networks/${1}.onnx experiments/acc-floats/${1}/results-approx-${2}-RERUN --approx ${2} > experiments/acc-floats/${1}/results-approx-${2}-RERUN.log 2>&1
}

run_ncubev_fallback () {
  mkdir -p experiments/acc-floats/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 julia --project=. ./src/cli.jl test/parsing/examples/acc-floats/formula-fallback test/parsing/examples/acc-floats/fixed test/parsing/examples/acc-floats/mapping test/networks/${1}.onnx experiments/acc-floats/${1}/results-fallback-approx-${2}-RERUN --approx ${2} > experiments/acc-floats/${1}/results-fallback-approx-${2}-RERUN.log 2>&1
}

run_ncubev_fallback_epsilon () {
  mkdir -p experiments/acc-floats/${1}-$3
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 julia --project=. ./src/cli.jl test/parsing/examples/acc-floats/formula-fallback test/parsing/examples/acc-floats/fixed-$3 test/parsing/examples/acc-floats/mapping test/networks/${1}.onnx experiments/acc-floats/${1}-$3/results-fallback-approx-${2}-RERUN --approx ${2} > experiments/acc-floats/${1}-$3/results-fallback-approx-${2}-RERUN.log 2>&1
}

#run_ncubev "acc-2000000-64-64-64-64-retrain-100000-200000-0.9" "1"
#run_ncubev_fallback "acc-2000000-64-64-64-64-retrain-100000-200000-0.9_FLOAT" "1"

#run_ncubev_fallback_epsilon "acc-2000000-64-64-64-64-retrain-100000-200000-0.9_FLOAT" "1" "0.1"
#run_ncubev_fallback_epsilon "acc-2000000-64-64-64-64-retrain-100000-200000-0.9_FLOAT" "1" "0.01"
#run_ncubev_fallback_epsilon "acc-2000000-64-64-64-64-retrain-100000-200000-0.9_FLOAT" "1" "0.0015"
run_ncubev_fallback_epsilon "acc-2000000-64-64-64-64-retrain-100000-200000-0.9_FLOAT" "1" "1"

