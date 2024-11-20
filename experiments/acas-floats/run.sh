SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acas-floats/vertcas-pra$2
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 julia --project=. ./src/cli.jl test/parsing/examples/acas-floats/property-$1-compressed test/parsing/examples/acas-floats/fixed test/parsing/examples/acas-floats/mapping test/networks/VertCAS_pra${2}_v4_45HU_200_FLOAT.onnx experiments/acas-floats/vertcas-pra$2/vertcas-full-compressed-pra$2-FLOAT --approx 1 > experiments/acas-floats/vertcas-pra$2/vertcas-full-compressed-pra$2-FLOAT.log 2>&1
}

run_ncubev_fixed () {
  mkdir -p experiments/acas-floats/vertcas-pra$2-$3
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 julia --project=. ./src/cli.jl test/parsing/examples/acas-floats/property-$1-compressed test/parsing/examples/acas-floats/fixed-$3 test/parsing/examples/acas-floats/mapping test/networks/VertCAS_pra${2}_v4_45HU_200_FLOAT.onnx experiments/acas-floats/vertcas-pra$2-$3/vertcas-full-compressed-pra$2-FLOAT --approx 1 > experiments/acas-floats/vertcas-pra$2-$3/vertcas-full-compressed-pra$2-FLOAT.log 2>&1
}

#run_ncubev "dnc" "02"
#run_ncubev "dnd" "03"
#run_ncubev_fixed "dnd" "03" "0.1"
run_ncubev_fixed "dnc" "02" "0.0025"
run_ncubev_fixed "dnd" "03" "0.0025"
