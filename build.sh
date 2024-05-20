#!/bin/bash
if [ -z $1 ]; then
    echo "Usage: ./build.sh <path-to-julia-executable>"
    exit 1
fi
echo "Building NCubeV with $1"

bash -c "OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 $1 -E 'using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.build();'"