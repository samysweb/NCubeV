SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acas/vertcas-pra$2-vI
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 runlim -r 14000 ./deps/NCubeV/bin/NCubeV test/parsing/examples/acas/property-$1-compressed-vI test/parsing/examples/acas/fixed-vI test/parsing/examples/acas/mapping test/networks/VertCAS_pra${2}_v4_45HU_200.onnx experiments/acas/vertcas-pra$2-vI/vertcas-full-compressed-pra$2-vI-RERUN --approx 1 > experiments/acas/vertcas-pra$2-vI/vertcas-full-compressed-pra$2-vI-RERUN.log 2>&1
}


run_ncubev "dnc" "02"
run_ncubev "dnd" "03"
