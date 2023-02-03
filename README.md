# $N^3V$ - A Non-linear Neural Network Verifier
This repository contains the non-linear neural network verifier $N^3V$ and its evaluation in the course of my Master's thesis.

## Running $N^3V$
>*Note:*
Due to legacy reasons the code currently still uses the name "SNNT" for this project, this will be updated in the future.
### Prerequisites
In order to install this tool you need to have `julia` and `gcc` installed.
This tool will install a number of julia and python packages upon installation

### Installation
In order to run $N^3V$ you have to clone the git repository.
Afterwards you will have to initialize the NNEnum neural network verifier:
```
git submodule init
git submodule sync
```
Following up on this, we need to install the tool.
Due to its use of submodules this currently only possible in Julia's development mode.
To this end run the following commands in the repository folder:
```
julia
> ] develop .
> ] activate .
> ] add https://github.com/sisl/OVERT.jl.git#d598d6c
> ] pin OVERT
> ] add SymbolicUtils@0.19.11
> ] pin SymbolicUtils
> ] activate
> ] add https://github.com/sisl/OVERT.jl.git#d598d6c
> ] pin OVERT
> ] add SymbolicUtils@0.19.11
> ] pin SymbolicUtils
...
> ] build SNNT
...
```
We currently require the precise version of OVERT and SymbolicUtils.
Note that it currently seems to be necessary to add and pin the two packages for the package *as well as for the surrounding environment!*
The `build` step will take approximately twenty minutes and precompile the tool.
> *This did not work as expected!* 
> First check the log in `deps/build.log` if the run of `deps/sysimage/trace_run.jl` failed, this may contain an error message explaining the problem.
> First, please ensure that you have `gcc` installed.  
> Usually the python package installation should have run through fine, however the build script might have failed.  
> To debug this manually run `julia deps/sysimage/build_sysimage.jl`. This should either succeed or the log might contain some helpful information for debugging.

### Running a verification task
Following up on this you should be able to run a first verification task from the repository directory (takes < 2min):
```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 ./bin/SNNT --smtfilter-timeout=10000 "test/parsing/examples/acc/formula" "test/parsing/examples/acc/fixed" "test/parsing/examples/acc/mapping" "test/networks/acc-3000000-64-64.onnx" myresult.jld
```
This runs `./bin/SNNT` with the provided `formula`, `fixed` variables and variable to NN in/out `mapping` and checks whether there is an assignment satisfying the negation of `formula` using the network `acc-3000000-64-64.onnx`.
The tool creates a file `myresult.jld` which contains the analysis results.
The tool should return something like this:
```
 59.728373 seconds (92.84 M allocations: 4.626 GiB, 8.70% gc time, 42.90% compilation time)
 62.642351 seconds (96.18 M allocations: 4.800 GiB, 9.81% gc time, 44.40% compilation time)
----------------------------------------------------------
Status: Unsafe
# Unsafe Stars: 82
Saving result in myresult.jld... Done
```
Note, that the environment variable settings are necessary for NNEnum to run without error.
>*This did not work as expected!*  
>In some newer instatllations there may be an incompatibility of packages, in this case it may help to include the following environment variable: `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` (append this before `OPENBLAS_NUM_THREADS`)

## Experiments
This repository also contains a number of experiments which were run in the course of my Master's Thesis.
The experiments can be found in the `experiments` folder.
All further information can be found in the Readme there.

## Naming
$N^3V$ (pronounced "N Cube V") stands for **N**on-linear **N**eural **N**etwork **V**erifier.  
Incidentally, interpreted as a unit $N^3V$ corresponds to $m^5kg^4A^{-1}s^{-9}$ which signifies the CPS mission of the tool: "**m**a**k**in**g** **a**utonomy **s**afer (which in turn has $5+4+1+9=19$ letters).

## Citation
This work is not published (yet).  
If you want to cite this work in your research, please reach out so we can figure something out.