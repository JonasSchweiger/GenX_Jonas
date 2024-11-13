using CSV
using DataFrames
using GenX
using Gurobi
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

# solar cost savings
# set investment cost of one technology to zero, specify the name of this technology in the script below and run it

# Function to modify Thermal.csv with a given capacity constraint and technology
function modify_thermal_csv_all(capacity_constraint)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Vre.csv", DataFrame)
    df[!, "Max_Cap_MW"] .= capacity_constraint  # Reset all "Max_Cap_MW" values
    #df[df.Resource .== technology, "Max_Cap_MW"] .= capacity_constraint # Set for the specified technology
    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Vre.csv", df)
end


function read_capacity_csv(filename)
    df = CSV.read(filename, DataFrame)
    # Remove leading/trailing whitespace and non-numeric characters
    df[!, :CapacityConstraintDual] = tryparse.(Float64, replace.(df[!, :CapacityConstraintDual], r"[^0-9\.\-]" => "")) 
    return df
end

# -----------------------------------

# Create a DataFrame to store the results
dfResults_solar = DataFrame(Capacity_Constraint = Float64[], Overall_Cost = Float64[])

# Define capacity constraint values
capacity_constraints = range(0.0, stop=10, length=2)

# Iterate over the capacity constraints
for capacity_constraint in capacity_constraints
    # Modify Thermal.csv for the selected technology
    modify_thermal_csv_all(capacity_constraint)

    # Run the model
    include("Run.jl")

    # Read the Capacity_Constraint_Dual value from capacity.csv
    dfCost = CSV.read("backup_systems/03_real_demand_sec_batteries/results/costs.csv")
    
    # Extract dual value using filter and column selection
    associated_cost = dfCost[1][1] 

    # Add the results to the DataFrame
    push!(dfResults_solar, [capacity_constraint, associated_cost])
end

# Write the results to a CSV file
CSV.write("cost_solar.csv", dfResults_solar)