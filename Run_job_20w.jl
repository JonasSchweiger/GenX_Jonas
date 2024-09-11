"""
DOLPHYN: Decision Optimization for Low-carbon Power and Hydrogen Networks
Copyright (C) 2022,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

cd(dirname(@__FILE__))

src_path = "./src/"
ex_path = "./Example_Systems/64Zones_PH_20w_CO2_SD/"

# environment_path = "../../install_packages.jl"
# include(environment_path) #Run this line to activate the Julia virtual environment for GenX; skip it, if the appropriate package versions are installed

println("Loading packages")
push!(LOAD_PATH, src_path)

using Dolphyn
using YAML
using Gurobi

# The directory containing your settings folder and files
# settings_path = joinpath(@__DIR__, "./Examples/Settings")
settings_path = joinpath(ex_path, "Settings")

# The directory containing your input data
# inputs_path = @__DIR__
inputs_path = ex_path

# Load settings
mysetup = load_settings(settings_path)

# Setup logging 
global_logger = setup_logging(mysetup)

### Load DOLPHYN
println("Loading packages")
# push!(LOAD_PATH, src_path)

# Setup time domain reduction and cluster inputs if necessary
setup_TDR(inputs_path, settings_path, mysetup)

# ### Configure solver
print_and_log("Configuring Solver")

OPTIMIZER = configure_solver(mysetup["Solver"], settings_path, Gurobi.Optimizer)

# #### Running a case

# ### Load inputs
# print_and_log("Loading Inputs")
 myinputs = load_inputs(mysetup, inputs_path)

# ### Load H2 inputs if modeling the hydrogen supply chain
if mysetup["ModelH2"] == 1
    myinputs = load_h2_inputs(myinputs, mysetup, inputs_path)
end

# ### Generate model
# print_and_log("Generating the Optimization Model")
EP = generate_Distributed_model(mysetup, myinputs, OPTIMIZER)

### Solve model
print_and_log("Solving Model")
EP, solve_time = solve_model(EP, mysetup)
myinputs["solve_time"] = solve_time # Store the model solve time in myinputs

### Write power system output

print_and_log("Writing Output")
outpath = joinpath(inputs_path, "Results")
outpath_GenX = write_outputs(EP, outpath, mysetup, myinputs)

# Write hydrogen supply chain outputs
# outpath_H2 = joinpath(outpath_GenX,"Results_HSC")
if mysetup["ModelH2"] == 1
    write_HSC_outputs(EP, outpath_GenX, mysetup, myinputs)
end

# compare_results(outpath_GenX, joinpath(inputs_path, "Results_Example"))
