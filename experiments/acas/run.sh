SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acas/vertcas-pra$2
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 runlim ./deps/NCubeV/bin/NCubeV test/parsing/examples/acas/property-$1-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping test/networks/VertCAS_pra${2}_v4_45HU_200.onnx experiments/acas/vertcas-pra$2/vertcas-full-compressed-pra$2-RERUN --approx 1 > experiments/acas/vertcas-pra$2/vertcas-full-compressed-pra$2-RERUN.log 2>&1
}

run_ncubev "dnc" "02"
run_ncubev "dnd" "03"
run_ncubev "des1500" "04"
run_ncubev "cl1500" "05"
run_ncubev "sdes1500" "06"
run_ncubev "scl1500" "07"
run_ncubev "sdes2500" "08"
run_ncubev "scl2500" "09"
