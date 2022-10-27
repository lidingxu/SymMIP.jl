# SymMIP.jl : Symmetry analysis for MIPs


## Installation

Add the package:
```julia
pkg.add("https://github.com/lidingxu/Traces.jl.git")
```


## Example usage


Read a JuMP MIP model and analysis its symmetry
```julia
using JuMP
using SymMIP
model = model()
#add variables, constraints, and objective
sym_analysis!(model)
```


## API

Data structures
* `sym_analysis` :  display orbits, and generators of the formulation symmetry group of a transformed model.
