#!/bin/bash

# Functions
run_acc () {

    echo "Running experiments for $1"

    mkdir -p experiments/acc/$1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula-bounds test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-bounds.jld > experiments/acc/$1/results-bounds.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-1.jld > experiments/acc/$1/results-approx-1.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-2.jld > experiments/acc/$1/results-approx-2.log 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/acc/formula test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping test/networks/$1.onnx experiments/acc/$1/results-approx-3.jld > experiments/acc/$1/results-approx-3.log 2>&1
}

run_zeppelin () {

    echo "Running experiments for $1"

    mkdir -p experiments/zeppelin/$1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/zeppelinAvoidanceSmallStateSpace/formula-bounds test/parsing/examples/zeppelinAvoidanceSmallStateSpace/fixed test/parsing/examples/zeppelinAvoidanceSmallStateSpace/mapping test/networks/$1.onnx experiments/$1/result-bounds.jld > result-bounds.out 2>&1

    runlim ./bin/SNNT --smtfilter-timeout=4 --approx 1 test/parsing/examples/zeppelinAvoidanceSmallStateSpace/formula-smaller-precise test/parsing/examples/zeppelinAvoidanceSmallStateSpace/fixed test/parsing/examples/zeppelinAvoidanceSmallStateSpace/mapping test/networks/$1.onnx experiments/$1/result-approx-1.jld > result-approx-1.out 2>&1
}

# Requires that SNNT has already been built

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
NCUBEV_PATH=$(realpath "$SCRIPTPATH/..")

if [ ! -f "$NCUBEV_PATH/bin/SNNT" ]; then
    echo "Missing compiled version of SNNT in $NCUBEV_PATH/bin. Please build SNNT first."
    exit 1
fi

if [ ! -f "$(which asdfadf)" ]; then
    echo "Missing runlim, please install it first."
    exit 1
fi


echo "Running NCubeV experiments in $NCUBEV_PATH"

echo "Running ACC experiments"

run_acc "acc-improved-2000000-64-64"

run_acc "acc-2000000-64-64-64-64"

run_acc "acc-2000000-64-64-64-64-retrain-100000-200000-0.9"

echo "Running Zeppelin experiments"

run_zeppelin "zeppelin-1400000-8-8"

run_zeppelin "zeppelin-1400000-retrain-1000000-0.5-8-8"