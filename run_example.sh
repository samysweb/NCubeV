echo "Running example: ACC"
echo "BEWARE: Before running this you need to build NCubeV"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acc/${1}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 runlim ./deps/NCubeV/bin/NCubeV test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/${1}.onnx experiments/acc/${1}/results-approx-${2}-RERUN --approx ${2}
}

run_ncubev "acc-2000000-64-64-64-64" "1"