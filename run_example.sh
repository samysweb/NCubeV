echo "Running example: ACC"
echo "BEWARE: Before running this you need to build NCubeV"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acc/${1}
  # We are now running an experiment.
  # To this end, we call ./deps/NCubeV/bin/NCubeV with the following arguments:
  # test/parsing/examples/acc/formula   -> Formula to verify
  # test/parsing/examples/acc/fixed     -> Fixed variables in the formula
  # test/parsing/examples/acc/mapping   -> Mapping of the variables to the network inputs/outputs
  # test/networks/${1}.onnx             -> ONNX file of the network
  # experiments/acc/${1}/results-approx-${2} -> Prefix of the output files (long runs store intermediate results to save RAM)
  # --approx ${2}                       -> Approximation level \in {1,2,3}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 runlim ./deps/NCubeV/bin/NCubeV test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/${1}.onnx experiments/acc/${1}/results-approx-${2}-RERUN --approx ${2}
}

run_ncubev "acc-2000000-64-64-64-64" "1"