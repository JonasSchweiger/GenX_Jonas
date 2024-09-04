using GenX
using Gurobi
using CSV
using DataFrames
using VegaLite
using PyPlot
using Plots
pyplot()

#run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)

case = dirname(@__FILE__)
optimizer =  Gurobi.Optimizer

genx_settings = get_settings_path(case, "genx_settings.yml") # Settings YAML file path
writeoutput_settings = get_settings_path(case, "output_settings.yml") # Write-output settings YAML file path
mysetup = configure_settings(genx_settings, writeoutput_settings) # mysetup dictionary stores settings and GenX-specific parameters
settings_path = get_settings_path(case)

### Cluster time series inputs if necessary and if specified by the user
if mysetup["TimeDomainReduction"] == 1
    TDRpath = joinpath(case, mysetup["TimeDomainReductionFolder"])
    system_path = joinpath(case, mysetup["SystemFolder"])
    prevent_doubled_timedomainreduction(system_path)
    if !time_domain_reduced_files_exist(TDRpath)
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
println("Loading Inputs")
myinputs = load_inputs(mysetup, case)

println("Generating the Optimization Model")
time_elapsed = @elapsed EP = generate_model(mysetup, myinputs, OPTIMIZER)
println("Time elapsed for model building is")
println(time_elapsed)

T = inputs["T"]

@variable(EP, vBackup_fuel_capacity[y in myinputs["SINGLE_FUEL"]], lower_bound=0)
@variable(EP, vBackup_fuel_level[t = 1:T, y in myinputs["SINGLE_FUEL"]]>=0)
@variable(EP, vBackup_emergency_purchase[t = 1:T, y in myinputs["SINGLE_FUEL"]]>=0)
@variable(EP, vBackup_top_up[y in myinputs["SINGLE_FUEL"]]>=0)

@constraint(EP, [t = 1:T, y in myinputs["SINGLE_FUEL"]], vBackup_fuel_level[t,y]≤ vBackup_fuel_capacity[y])
@constraint(EP, [y in myinputs["SINGLE_FUEL"]], vBackup_top_up[y]== vBackup_fuel_capacity[y]-vBackup_fuel_level[T,y])
@constraint(EP, [y in myinputs["SINGLE_FUEL"]], vBackup_fuel_level[1,y]== vBackup_fuel_capacity[y])
@constraint(EP, [t = 2:T, y in myinputs["SINGLE_FUEL"]], vBackup_fuel_level[t,y] == vBackup_fuel_level[t-1,y] - EP[:vFuel][y,t] + vBackup_emergency_purchase[t,y])

@expression(EP, eBackup_cfix[y in myinputs["SINGLE_FUEL"]], 100 * vBackup_fuel_capacity[y])





println("Solving Model")
EP, solve_time = solve_model(EP, mysetup)
myinputs["solve_time"] = solve_time # Store the model solve time in myinputs

# Run MGA if the MGA flag is set to 1 else only save the least cost solution
if has_values(EP)
    println("Writing Output")
    outputs_path = get_default_output_folder(case)
    elapsed_time = @elapsed outputs_path = write_outputs(EP,
        outputs_path,
        mysetup,
        myinputs)
    println("Time elapsed for writing is")
    println(elapsed_time)
end