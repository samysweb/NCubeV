#!/bin/bash

# Functions
run_acc () {

    echo "Running experiments for $1"

    mkdir -p experiments/acc/$1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula-bounds test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-bounds.jld > experiments/acc/$1/results-bounds.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-1.jld > experiments/acc/$1/results-approx-1.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 2 test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-2.jld > experiments/acc/$1/results-approx-2.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 3 test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-3.jld > experiments/acc/$1/results-approx-3.log 2>&1
}

run_acc_two () {

    echo "Running experiments for $1"

    mkdir -p experiments/acc/$1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula-bounds2 test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-bounds.jld > experiments/acc/$1/results-bounds.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula2 test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-1.jld > experiments/acc/$1/results-approx-1.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 2 test/parsing/examples/acc/formula2 test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-2.jld > experiments/acc/$1/results-approx-2.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 3 test/parsing/examples/acc/formula2 test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-3.jld > experiments/acc/$1/results-approx-3.log 2>&1
}

run_acc_fallback () {

    echo "Running experiments for $1"

    mkdir -p experiments/acc/$1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula-fallback test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/fallback-approx-1.jld > experiments/acc/$1/fallback-approx-1.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 2 test/parsing/examples/acc/formula-fallback test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/fallback-approx-2.jld > experiments/acc/$1/fallback-approx-2.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 3 test/parsing/examples/acc/formula-fallback test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/fallback-approx-3.jld > experiments/acc/$1/fallback-approx-3.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula-fallback2 test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/fallback2-approx-1.jld > experiments/acc/$1/fallback2-approx-1.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 2 test/parsing/examples/acc/formula-fallback2 test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/fallback2-approx-2.jld > experiments/acc/$1/fallback2-approx-2.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 3 test/parsing/examples/acc/formula-fallback2 test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/fallback2-approx-3.jld > experiments/acc/$1/fallback2-approx-3.log 2>&1
}

run_zeppelin () {

    echo "Running experiments for $1"

    mkdir -p experiments/zeppelin/$1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/formula-bounds test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/fixed40 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/mapping test/networks/$1.onnx experiments/zeppelin/$1/result40-bounds.jld > experiments/zeppelin/$1/result40-bounds.out 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/formula-smaller-precise test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/fixed40 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/mapping test/networks/$1.onnx experiments/zeppelin/$1/result40-approx-1.jld > experiments/zeppelin/$1/result40-approx-1.out 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/formula-bounds test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/fixed80 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/mapping test/networks/$1.onnx experiments/zeppelin/$1/result80-bounds.jld > experiments/zeppelin/$1/result80-bounds.out 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/formula-smaller-precise test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/fixed80 test/parsing/examples/zeppelinAvoidanceSmallStateSpace-fixedC/mapping test/networks/$1.onnx experiments/zeppelin/$1/result80-approx-1.jld > experiments/zeppelin/$1/result80-approx-1.out 2>&1
}

# Requires that SNNT has already been built

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
NCUBEV_PATH=$(realpath "$SCRIPTPATH/..")

if [ ! -f "$NCUBEV_PATH/bin/SNNT" ]; then
    echo "Missing compiled version of SNNT in $NCUBEV_PATH/bin. Please build SNNT first."
    exit 1
fi

if [ ! -f "$(which runlim)" ]; then
    echo "Missing runlim, please install it first."
    exit 1
fi


echo "Running NCubeV experiments in $NCUBEV_PATH"

echo "Running ACC experiments"

run_acc "acc-improved-2000000-64-64"

run_acc "acc-2000000-64-64-64-64"

run_acc_two "acc-2000000-64-64-64-64-retrain-100000-200000-0.9"

echo "Running ACC fallback experiments"

run_acc_fallback "acc-2000000-64-64-64-64-retrain-100000-200000-0.9"

echo "Running Zeppelin experiments"

run_zeppelin "zeppelin-1400000-8-8"

run_zeppelin "zeppelin-1400000-retrain-1000000-0.5-8-8"