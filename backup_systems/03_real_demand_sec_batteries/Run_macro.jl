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


# First sets all "Max_Cap_MW" entries to 0, then sets one to -1
function modify_thermal_csv(row_index)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)

    # Reset all "Max_Cap_MW" values to 0
    df[!, "Max_Cap_MW"] .= 0  

    # Set the specific row in "Max_Cap_MW" to -1
    df[row_index, "Max_Cap_MW"] = -1  
    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end

# Create an empty DataFrame to store the results
dfBackupCostOverview_2 = DataFrame()

# Run Julia multiple times
for i in 1:nrow(CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame))
    modify_thermal_csv(i) 
    include("Run.jl")

    # Read the "backup_cost.csv" file
    dfCost = CSV.read("backup_systems/03_real_demand_sec_batteries/results/costs.csv", DataFrame)

    if i == 1
        # Extract the first two columns for the first iteration
        global dfBackupCostOverview_2 = dfCost[:, 1:2] 
        rename!(dfBackupCostOverview_2, :Total => :Iteration1)  # Rename the second column
    else
        # Extract only the "Total" column for subsequent iterations, rename it before concatenating
        rename!(dfCost, :Total => Symbol("Iteration$i"))  # Rename the column in dfCost
        dfBackupCostOverview = hcat(dfBackupCostOverview, dfCost[:, Symbol("Iteration$i")]) 
    end
end

# Write the combined DataFrame to CSV
CSV.write("backup_cost_overview.csv", dfBackupCostOverview_2) 