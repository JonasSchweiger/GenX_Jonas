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

# Function to modify Thermal.csv with a given capacity constraint and technology
function modify_thermal_csv_all(capacity_constraint, technology)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)
    df[!, "Max_Cap_MW"] .= -1.0  # Reset all "Max_Cap_MW" values
    df[df.Resource .== technology, "Max_Cap_MW"] .= capacity_constraint # Set for the specified technology
    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end


function read_capacity_csv(filename)
    df = CSV.read(filename, DataFrame)
    # Remove leading/trailing whitespace and non-numeric characters
    df[!, :CapacityConstraintDual] = tryparse.(Float64, replace.(df[!, :CapacityConstraintDual], r"[^0-9\.\-]" => "")) 
    return df
end

# ---  Specify the technology here ---
technology = "MA_Methanol_FC" 
# -----------------------------------

# Create a DataFrame to store the results
dfResults = DataFrame(Capacity_Constraint = Float64[], Capacity_Constraint_Dual = Float64[])

# Define capacity constraint values
capacity_constraints = range(0.1, stop=2, length=15)

# Iterate over the capacity constraints
for capacity_constraint in capacity_constraints
    # Modify Thermal.csv for the selected technology
    modify_thermal_csv_all(capacity_constraint, technology)

    # Run the model
    include("Run.jl")

    # Read the Capacity_Constraint_Dual value from capacity.csv
    dfCapacity = read_capacity_csv("backup_systems/03_real_demand_sec_batteries/results/capacity.csv")
    
    # Extract dual value using filter and column selection
    capacity_dual_value = filter(:Resource => ==(technology), dfCapacity)[:, :CapacityConstraintDual][1] 

    # Add the results to the DataFrame
    push!(dfResults, [capacity_constraint, capacity_dual_value])
end

# Write the results to a CSV file
CSV.write("sensitivity_analysis.csv", dfResults)