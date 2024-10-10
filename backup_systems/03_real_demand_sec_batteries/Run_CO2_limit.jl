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

# Sets all "Max_Cap_MW" entries to -1
function modify_thermal_csv_1()
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)

    # Set all "Max_Cap_MW" values to -1
    df[!, "Max_Cap_MW"] .= -1  

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end

# Sets the CO2 limit in the "CO2_cap.csv" file
function modify_co2_cap_csv(co2_limit)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/policies/CO2_cap.csv", DataFrame)

    # Set the CO2 limit in the specified column
    df[1, "CO_2_Max_tons_MWh_1"] = co2_limit

    # Set CO_2_Cap_Zone_1 to 1
    df[1, "CO_2_Cap_Zone_1"] = 1  

    CSV.write("backup_systems/03_real_demand_sec_batteries/policies/CO2_cap.csv", df)
end

# First modify the Thermal.csv to set all "Max_Cap_MW" to -1
modify_thermal_csv_1()



# Define the CO2 limit range and step size
co2_start = 1.3
co2_end = 0.05
n_steps = 4  # Adjust this value to change the number of steps

# Calculate the step size
step_size = (co2_start - co2_end) / (n_steps - 1)

# Run Julia multiple times with different CO2 limits
for i in 1:n_steps
    # Calculate the CO2 limit for the current iteration
    co2_limit = co2_start - (i - 1) * step_size

    # Set the CO2 limit in the CO2_cap.csv file
    modify_co2_cap_csv(co2_limit)

    include("Run.jl")

end
