using GenX
using Gurobi
using CSV
using DataFrames
using VegaLite
using PyPlot
using Plots
using PlotlyJS
using GraphRecipes
using VegaLite
using StatsPlots
using JuMP
using Plots
using Statistics
pyplot()

case = dirname(@__FILE__)
optimizer =  Gurobi.Optimizer

for i in 1:n_steps

    genx_settings = GenX.get_settings_path(case, "genx_settings.yml") # Settings YAML file path
    writeoutput_settings = GenX.get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
    mysetup = configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters
    settings_path = GenX.get_settings_path(case)

    ### Cluster time series inputs if necessary and if specified by the user
    if mysetup["TimeDomainReduction"] == 1
        TDRpath = joinpath(case, mysetup["TimeDomainReductionFolder"])
        system_path = joinpath(case, mysetup["SystemFolder"])
        GenX.prevent_doubled_timedomainreduction(system_path)
        if !GenX.time_domain_reduced_files_exist(TDRpath)
            println("Clustering Time Series Data (Grouped)...")
            cluster_inputs(case, settings_path, mysetup)
        else
            println("Time Series Data Already Clustered.")
        end
    end

    ### Configure solver
    println("Configuring Solver")
    OPTIMIZER = configure_solver(settings_path, optimizer)

    #### Running a case

    ### Load inputs

    #mysetup["MinCapReq"] = 1
    println("Loading Inputs")
    myinputs = load_inputs(mysetup, case)

end


