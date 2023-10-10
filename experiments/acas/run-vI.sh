SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../../

run_ncubev () {
  mkdir -p experiments/acas/vertcas-pra$2-vI
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 runlim julia --project=./ cli.jl test/parsing/examples/acas/property-$1-compressed-vI test/parsing/examples/acas/fixed-vI test/parsing/examples/acas/mapping test/networks/VertCAS_pra${2}_v4_45HU_200.onnx experiments/acas/vertcas-pra$2-vI/vertcas-full-compressed-pra$2-vI --approx 1 > experiments/acas/vertcas-pra$2-vI/vertcas-full-compressed-pra$2-vI.log 2>&1
}

echo "Sleeping..."
sleep 19000

echo "Killing SMT tasks..."

kill -9 17832
kill -9 41673
kill -9 17831
kill -9 41672
kill -9 58365
kill -9 58364
kill -9 58393
kill -9 58392

echo "Sleeping a little more..."
sleep 20

echo "Starting NNV..."

run_ncubev "dnc" "02"
run_ncubev "dnd" "03"
run_ncubev "des1500" "04"
run_ncubev "cl1500" "05"
run_ncubev "sdes1500" "06"
run_ncubev "scl1500" "07"
run_ncubev "sdes2500" "08"
run_ncubev "scl2500" "09"
