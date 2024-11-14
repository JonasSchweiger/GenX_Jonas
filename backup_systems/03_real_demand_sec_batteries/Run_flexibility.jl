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


#Optimal technology mix depending on flexibility allowance


# Allow all classic resources but not solar!
function initialize_resources_csv()
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)

    # Set all "Max_Cap_MW" values to -1
    df[!, "Max_Cap_MW"] .= -1

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)

    #now get rid of solar
    df2 = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Vre.csv", DataFrame)

    # Set all "Max_Cap_MW" values to -1
    df2[!, "Max_Cap_MW"] .= 0

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Vre.csv", df2)

end

# Sets all "Max_Cap_MW" entries to the specified value
function modify_flexibility_csv_value(cap_value)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Flex_demand.csv", DataFrame)

    # Set all "Max_Cap_MW" values to cap_value
    df[!, "Existing_Cap_MW"] .= cap_value

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Flex_demand.csv", df)
end


# Get CO2 emissions from backup_cost.csv
function get_co2_emissions()
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/results/backup_cost.csv", DataFrame)
    
    return df[1, "Backup_Emissions"]
end




dfCapacityFlexibility = DataFrame()
initialize_resources_csv()
# modify the flexibility value here!!
modify_flexibility_csv_value(0.2)

# Define capacity constraint values
flexibility_time_constraints = range(0.0, stop=0.5, length=6)

# Iterate over the capacity constraints
for flexibility_time_constraint in flexibility_time_constraints
    i = 2  # Initialize i to 2 since Column1 is already created
    # Modify Thermal.csv for the selected technology
    modify_flexibility_csv_value(flexibility_time_constraint)

    # Run the model
    include("Run.jl")

# Read the "backup_cost.csv" file
    dfCapacity = CSV.read("backup_systems/03_real_demand_sec_batteries/results/capacity.csv", DataFrame)

    # Read "costs.csv" and extract "cTotal" value
    dfCosts = CSV.read("backup_systems/03_real_demand_sec_batteries/results/costs.csv", DataFrame)
    cTotal = dfCosts[1, :Total]


    # Read "backup_cost.csv" and extract "Backup_Emissions" from the first row
    dfBackupCost_2 = CSV.read("backup_systems/03_real_demand_sec_batteries/results/backup_cost.csv", DataFrame)
    backupEmissions = dfBackupCost_2[1, "Backup_Emissions"] 

    # --- Create or update dfCapacityFlexibility ---

    if flexibility_time_constraint == 0
        # Extract the first two columns for the first iteration, renaming them
        global dfCapacityFlexibility = dfCapacity[:, [:Resource, :EndCap]]
        rename!(dfCapacityFlexibility, :Resource => :Column1, :EndCap => :Column2) 

        # Add 'Backup_Emissions' as the first row
        dfCapacityFlexibility = prepend!(dfCapacityFlexibility,  DataFrame(Symbol("Column1") => ["Backup_Emissions"], Symbol("Column2") => [backupEmissions]))

        # Add 'cTotal' as the last row
        dfCapacityFlexibility = append!(dfCapacityFlexibility, DataFrame(Symbol("Column1") => ["cTotal"], Symbol("Column2") => [cTotal]))

    else
        # Extract only the :EndCap column for subsequent iterations
        temp_df = dfCapacity[:, [:EndCap]] 

        # Rename the column to match dfCapacityFlexibility
        rename!(temp_df, :EndCap => Symbol("Column$i"))

        # Add 'Backup_Emissions' as the first row to temp_df
        temp_df = prepend!(temp_df, DataFrame(Symbol("Column$i") => [backupEmissions]))

        # Add 'cTotal' as the last row to temp_df
        temp_df = append!(temp_df, DataFrame(Symbol("Column$i") => [cTotal]))

        # Now you can concatenate (temp_df now has the correct number of rows)
        global dfCapacityFlexibility = hcat(dfCapacityFlexibility, temp_df, makeunique=true)
        i += 1  # Increment i for the next iteration
    end
        
end
# Write the combined DataFrame to CSV
CSV.write("backup_capacity_flexibility.csv", dfCapacityFlexibility)