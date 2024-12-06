using GenX
using Gurobi
using CSV
using DataFrames
using VegaLite
using PyPlot
using Plots
pyplot()

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)

#only for testing!