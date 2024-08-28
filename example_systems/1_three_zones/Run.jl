using GenX
using Gurobi
using CSV
using DataFrames
using VegaLite
using PyPlot
using Plots
pyplot()

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)

#power =  CSV.read("example_systems/1_three_zones/results_4/power.csv",DataFrame,missingstring="NA")
