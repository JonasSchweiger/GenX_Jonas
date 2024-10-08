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

#run_genx_case!(dirname(@__FILE__), Gurobi.Optimizer)


case = dirname(@__FILE__)
optimizer =  Gurobi.Optimizer

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

println("Generating the Optimization Model")
time_elapsed = @elapsed EP = generate_model(mysetup, myinputs, OPTIMIZER)
println("Time elapsed for model building is")
println(time_elapsed)

T = myinputs["T"]
G = myinputs["G"]
gen = myinputs["RESOURCES"]
fuels = myinputs["fuels"]
fuel_costs = myinputs["fuel_costs"]
omega = myinputs["omega"]
END_SUBPERIODS = myinputs["START_SUBPERIODS"] .+ myinputs["hours_per_subperiod"] .-1
EMERGENCY_PURCHSASE_TIME = 1:24:T

no_purchases = Int64[]
for r in gen
    if r.backup_emergency_purchase == 0
        push!(no_purchases, r.id)
    end
end

@variable(EP, vBackup_fuel_capacity[y in myinputs["SINGLE_FUEL"]], lower_bound=0) #in MMBtu
@variable(EP, vBackup_fuel_level[t = 1:T, y in myinputs["SINGLE_FUEL"]]>=0) #in MMBtu
@variable(EP, vBackup_emergency_purchase[t = 1:T, y in myinputs["SINGLE_FUEL"]]>=0) #in MMBtu
@variable(EP, vBackup_top_up[t =1:T, y in myinputs["SINGLE_FUEL"]]>=0) #in MMBtu
#@variable(EP, VBackup_fuel_unused[t=1:T, y in myinputs["SINGLE_FUEL"]]>=0) #in MMBtu

@constraint(EP, [t = 1:T, y in myinputs["SINGLE_FUEL"]], vBackup_fuel_level[t,y] ≤ vBackup_fuel_capacity[y])
#@constraint(EP, [y in myinputs["SINGLE_FUEL"]], vBackup_fuel_capacity[y]>=1 )
@constraint(EP, [t in END_SUBPERIODS,y in myinputs["SINGLE_FUEL"]], vBackup_top_up[t,y]== vBackup_fuel_capacity[y]-vBackup_fuel_level[t,y])
@constraint(EP, [t in myinputs["START_SUBPERIODS"], y in myinputs["SINGLE_FUEL"]], vBackup_fuel_level[t,y]== vBackup_fuel_capacity[y])
@constraint(EP, [t in myinputs["INTERIOR_SUBPERIODS"], y in myinputs["SINGLE_FUEL"]], vBackup_fuel_level[t,y] == vBackup_fuel_level[t-1,y] - EP[:vFuel][y,t] + vBackup_emergency_purchase[t,y]) #vFuel is /billion BTU
@constraint(EP, [t in setdiff(1:T, EMERGENCY_PURCHSASE_TIME), y in myinputs["SINGLE_FUEL"]], vBackup_emergency_purchase[t,y] == 0)
@constraint(EP, [t in EMERGENCY_PURCHSASE_TIME, y in no_purchases], vBackup_emergency_purchase[t,y] == 0)

#@constraint(EP, myinputs["RESOURCES"]["MA_Methanol"][:Cap] >= 1) 


@expression(EP, eBackup_CFix[y in myinputs["SINGLE_FUEL"]], (GenX.backup_inv_cost_per_mwhyr(gen[y]) + GenX.backup_fixed_om_cost_per_mwhyr(gen[y])) * vBackup_fuel_capacity[y] * 0.293071) # 0.293071 MWh/MMBtu
@expression(EP, eBackup_CReplacement[y in myinputs["SINGLE_FUEL"]], GenX.backup_replacement_factor(gen[y]) * vBackup_fuel_capacity[y] * mean(fuel_costs[GenX.fuel(gen[y])]) - sum(myinputs["omega"][t] * (fuel_costs[GenX.fuel(gen[y])][t]) * vBackup_top_up[t,y] for t in 1:T))
@expression(EP, eBackup_CVar[y in myinputs["SINGLE_FUEL"]], sum(myinputs["omega"][t] * (fuel_costs[GenX.fuel(gen[y])][t]) * (5 * vBackup_emergency_purchase[t,y] + vBackup_top_up[t,y]) for t in 1:T))


@expression(EP, eBackup_Total_CFix, sum(EP[:eBackup_CFix][y] for y in 1:G))
@expression(EP, eBackup_Total_CReplacement, sum(EP[:eBackup_CReplacement][y] for y in 1:G))
@expression(EP, eBackup_Total_CVar, sum(EP[:eBackup_CVar][y] for y in 1:G))

#add expressions for volume occupied and weight of storage
@expression(EP, eBackup_m3[y in myinputs["SINGLE_FUEL"]], vBackup_fuel_capacity[y] / (GenX.energy_density_mj_per_m3(gen[y])) * 1055.055) # 1055.055 MJ/MMBtu
@expression(EP, eBackup_kg[y in myinputs["SINGLE_FUEL"]], vBackup_fuel_capacity[y] / (GenX.energy_density_mj_per_kg(gen[y])) * 1055.055) # 1055.055 MJ/MMBtu


#add_to_expression!(EP[:eObj], eBackup_Total_CFix)
#add_to_expression!(EP[:eObj], eBackup_Total_CReplacement)
#add_to_expression!(EP[:eObj], eBackup_Total_CVar)


EP[:eObj] += eBackup_Total_CFix
EP[:eObj] += eBackup_Total_CReplacement
EP[:eObj] += eBackup_Total_CVar

@objective(EP, Min, mysetup["ObjScale"]*EP[:eObj])

println("Solving Model")
EP, solve_time = solve_model(EP, mysetup)
myinputs["solve_time"] = solve_time # Store the model solve time in myinputs

#println(typeof(vBackup_fuel_capacity))
println(size(vBackup_top_up))

if has_values(EP)
    println("Writing Output")
    println(value(EP[:eObj]))
    outputs_path = GenX.get_default_output_folder(case)
    elapsed_time = @elapsed outputs_path = write_outputs(EP,
        outputs_path,
        mysetup,
        myinputs)
    println("Time elapsed for writing is")
    println(elapsed_time)

    dfBackupOverview = DataFrame(
        Technology = myinputs["RESOURCE_NAMES"][myinputs["SINGLE_FUEL"]],
        Backup_fuel_capacity_MMBtu = Vector(value.(vBackup_fuel_capacity)[axes(vBackup_fuel_capacity)[1]]),
        Space_used_m3 = Vector(value.(eBackup_m3)[axes(eBackup_m3)[1]]),
        Weight_kg = Vector(value.(eBackup_kg)[axes(eBackup_kg)[1]])
 
    )

    dfBackupCost = DataFrame(
        CFix = value.(EP[:eBackup_Total_CFix]),
        CReplacement = value.(EP[:eBackup_Total_CReplacement]),
        CVar = value.(EP[:eBackup_Total_CVar]) 
    )


    dfBackupEvolution = DataFrame(Timestep = 1:T)
    for y in myinputs["SINGLE_FUEL"]
        dfBackupEvolution[!, Symbol("Backup_fuel_level_$(myinputs["RESOURCE_NAMES"][y])_MMBtu")] = value.(vBackup_fuel_level[:, y])
        dfBackupEvolution[!, Symbol("Backup_emergency_purchase_$(myinputs["RESOURCE_NAMES"][y])_MMBtu")] = value.(vBackup_emergency_purchase[:, y])
        dfBackupEvolution[!, Symbol("Backup_top_up_$(myinputs["RESOURCE_NAMES"][y])_MMBtu")] = value.(vBackup_top_up[:, y])
    end
    # println(dfBackupEvolution)
    # # println(EP[:vBackup_fuel_level])
    # error("stop")

    
    CSV.write(joinpath(outputs_path, "backup_overview.csv"), dfBackupOverview)
    CSV.write(joinpath(outputs_path, "backup_cost.csv"), dfBackupCost)
    CSV.write(joinpath(outputs_path, "backup_evolution.csv"), dfBackupEvolution)
end