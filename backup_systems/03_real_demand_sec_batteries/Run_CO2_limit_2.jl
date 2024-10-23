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

# Sets all "Max_Cap_MW" entries to 0, except for the specified row
function modify_thermal_csv(exception_row)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)

    # Set all "Max_Cap_MW" values to 0
    df[!, "Max_Cap_MW"] .= 0

    # Set the exception row to -1
    row_index = findfirst(df.Resource .== exception_row)
    if !isnothing(row_index)
        df[row_index, "Max_Cap_MW"] = -1
    else
        @warn "Row with Technology '$exception_row' not found in Thermal.csv"
    end

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end

# Sets all "Max_Cap_MW" entries to the specified value
function modify_thermal_csv_value(cap_value)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)

    # Set all "Max_Cap_MW" values to cap_value
    df[!, "Max_Cap_MW"] .= cap_value

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end

# Sets the CO2 limit in the "CO2_cap.csv" file
function modify_co2_cap_csv(co2_limit)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/policies/CO2_cap.csv", DataFrame)

    # Set the CO2 limit in the specified column
    df[1, "CO_2_Max_Mtons_1"] = co2_limit

    # Set CO_2_Cap_Zone_1 to 1
    df[1, "CO_2_Cap_Zone_1"] = 1 

    CSV.write("backup_systems/03_real_demand_sec_batteries/policies/CO2_cap.csv", df)
end

# Get CO2 emissions from emissions.csv
function get_co2_emissions()
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/results/emissions.csv", DataFrame)
    row_index = findfirst(df.Zone .== "AnnualSum")
    if !isnothing(row_index)
        return df[row_index, 2]
    else
        @warn "Row 'AnnualSum' not found in emissions.csv"
        return nothing
    end
end

# --- Find co2_start ---
# Set all "Max_Cap_MW" to 0 except for "MA_Diesel_Gen"
modify_thermal_csv("MA_Diesel_Gen") 

# Run the model
include("Run.jl")

# Get co2_start from emissions.csv
co2_start = get_co2_emissions() * 10^(-6) * 1.001 # account for rounding errors

# --- Find co2_end ---
# Set all "Max_Cap_MW" to 0 except for "MA_Secondary_Li_Ion_BESS"
modify_thermal_csv("MA_Secondary_Li_Ion_BESS") 

# Run the model
include("Run.jl")

# Get co2_end from emissions.csv
co2_end = get_co2_emissions() * 10^(-6) * 1.001 #account for rounding errors
dfBackupCapacityOverview = DataFrame()
modify_thermal_csv_value(-1) 

print(co2_start)
print(co2_end)
# --- Run the main loop with calculated CO2 limits ---
if !isnothing(co2_start) && !isnothing(co2_end)
    n_steps = 20  # Adjust this value to change the number of steps

    # Calculate the step size
    step_size = (co2_start - co2_end) / (n_steps - 1)

    # Run Julia multiple times with different CO2 limits
    for i in 1:n_steps
        # Calculate the CO2 limit for the current iterationd
        co2_limit = co2_start - (i - 1) * step_size

        # Set the CO2 limit in the CO2_cap.csv file
        modify_co2_cap_csv(co2_limit)

        include("Run.jl")


        # Read the "backup_cost.csv" file
    dfCapacity = CSV.read("backup_systems/03_real_demand_sec_batteries/results/capacity.csv", DataFrame)

        if i == 1
            # Extract the first two columns for the first iteration
            global dfBackupCapacityOverview = dfCapacity[:, [1,8]] 
            #rename!(dfBackupCapacityOverview, :Total => :Iteration1)  # Rename the second column
        else
            # Extract only the eigth column for subsequent iterations
            global dfBackupCapacityOverview = hcat(dfBackupCapacityOverview, dfCapacity[:, 8], makeunique=true)
            #rename!(dfBackupCostOverview_2, :Total => Symbol("Iteration$i")) # Rename the new column
        end
    end
else
    @error "Could not determine co2_start or co2_end. Check the emissions.csv file and Thermal.csv file."
end

# Write the combined DataFrame to CSV
CSV.write("backup_capacity_overview.csv", dfBackupCapacityOverview) 