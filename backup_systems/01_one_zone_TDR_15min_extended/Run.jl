using GenX
using Gurobi
using CSV
using DataFrames
using VegaLite
using PyPlot
using Plots
pyplot()

run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)

#15min timesteps
#one Zone
#only for testing!