# Within Julia

There is currently a problem with the package management and I'm still trying to figure out the exact reason.
In the meantime, in order to run SNNT, begin by running this:

```
] dev .
] activate .
] add https://github.com/sisl/OVERT.jl.git#master
] pin OVERT
] add SymbolicUtils@0.19.11
] pin SymbolicUtils
] activate
] add https://github.com/sisl/OVERT.jl.git#master
] pin OVERT
] add SymbolicUtils@0.19.11
] pin SymbolicUtils
```