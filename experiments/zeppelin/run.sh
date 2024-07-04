SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/zeppelin/${2}
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 ./deps/NCubeV/bin/NCubeV test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/formula-smaller-precise test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/fixed${1} test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/mapping test/networks/${2}.onnx experiments/zeppelin/${2}/result${1}-approx-1-RERUN --approx 1 --no-cores --no-normalization > experiments/zeppelin/${2}/result${1}-approx-1-RERUN.log 2>&1
}

run_ncubev "40" "zeppelin-1400000-8-8"
#run_ncubev "40" "zeppelin-1400000-retrain-1000000-0.5-8-8"
