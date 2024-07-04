SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acc/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 ./deps/NCubeV/bin/NCubeV test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/${1}.onnx experiments/acc/${1}/results-approx-${2}-RERUN --approx ${2} > experiments/acc/${1}/results-approx-${2}-RERUN.log 2>&1
}

run_ncubev_fallback () {
  mkdir -p experiments/acc/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 ./deps/NCubeV/bin/NCubeV test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/${1}.onnx experiments/acc/${1}/results-approx-${2}-RERUN --approx ${2} > experiments/acc/${1}/results-approx-${2}-RERUN.log 2>&1
}

run_ncubev_fallback () {
  mkdir -p experiments/acc/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 ./deps/NCubeV/bin/NCubeV test/parsing/examples/acc/formula-fallback test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/${1}.onnx experiments/acc/${1}/fallback-approx-${2}-RERUN --approx ${2} > experiments/acc/${1}/fallback-approx-${2}-RERUN.log 2>&1
}

run_ncubev_linear () {
  mkdir -p experiments/acc/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 ./deps/NCubeV/bin/NCubeV test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/${1}.onnx experiments/acc/${1}/results-linear-RERUN --linear > experiments/acc/${1}/results-linear-RERUN.log 2>&1
}

run_ncubev_fallback_linear () {
  mkdir -p experiments/acc/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 ./deps/NCubeV/bin/NCubeV test/parsing/examples/acc/formula-fallback test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/${1}.onnx experiments/acc/${1}/fallback-linear-RERUN --approx 1 --linear > experiments/acc/${1}/fallback-linear-RERUN.log 2>&1
}

run_ncubev_linear "acc-2000000-64-64-64-64"
run_ncubev "acc-2000000-64-64-64-64" "1"
run_ncubev "acc-2000000-64-64-64-64" "2"
run_ncubev "acc-2000000-64-64-64-64" "3"

run_ncubev_linear "acc-2000000-64-64-64-64-retrain-100000-200000-0.9"
run_ncubev "acc-2000000-64-64-64-64-retrain-100000-200000-0.9" "1"
run_ncubev "acc-2000000-64-64-64-64-retrain-100000-200000-0.9" "2"
run_ncubev "acc-2000000-64-64-64-64-retrain-100000-200000-0.9" "3"
run_ncubev_fallback "acc-2000000-64-64-64-64-retrain-100000-200000-0.9" "1"
run_ncubev_fallback "acc-2000000-64-64-64-64-retrain-100000-200000-0.9" "2"
run_ncubev_fallback "acc-2000000-64-64-64-64-retrain-100000-200000-0.9" "3"

run_ncubev_linear "acc-improved-2000000-64-64"
run_ncubev "acc-improved-2000000-64-64" "1"
run_ncubev "acc-improved-2000000-64-64" "2"
run_ncubev "acc-improved-2000000-64-64" "3"

run_ncubev_fallback_linear "acc-2000000-64-64-64-64-retrain-100000-200000-0.9"


