# SymMIP.jl : Symmetry analysis for MIPs

Detect the formualtion symmetry group of a Mixed-Integer Linear Programming model, the group's orbits and generators are outputs.
To do: Mixed-Integer Conic Programming model (linear inequalites should be extended to conic inequalities).
## Installation

Add and install this package:
```julia
pkg.add("https://github.com/lidingxu/SymMIP.jl.git")
```


## Example usage


Read a JuMP MIP model and analyse its symmetry
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
