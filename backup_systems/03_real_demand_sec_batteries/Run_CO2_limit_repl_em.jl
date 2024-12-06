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


#Optimal technology mix depending on thightening CO2 limits (based on operating emissions!)
#takes Diesel and Li-Ion battery as extreme CO2 values and does n steps in between


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
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)

    # Set the CO2 limit in the specified column
    #df[!, "CO_2_Max_Mtons_1"] = Float64.(df[!, "CO_2_Max_Mtons_1"])
    df[8, "emergency_quantity_mmbtu"] = co2_limit

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end

# Get CO2 emissions from backup_cost.csv
function get_co2_emissions()
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/results/backup_cost.csv", DataFrame)
    
    return df[1, "Backup_Emissions"]
end

function initialize_co2_emissions()
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)
    df[8, "emergency_quantity_mmbtu"] = 20000

end


# --- Find co2_start ---
# Set all "Max_Cap_MW" to 0 except for "MA_Diesel_Gen"
initialize_co2_emissions()
#modify_thermal_csv("MA_Diesel_Gen") 

# Run the model
#include("Run.jl")

# Get co2_start from emissions.csv
co2_start = 210.6065358 #get_co2_emissions()

# --- Find co2_end ---
# Set all "Max_Cap_MW" to 0 except for "MA_Secondary_Li_Ion_BESS"
#modify_thermal_csv("MA_Secondary_Li_Ion_BESS") 

# Run the model
#include("Run.jl")

# Get co2_end from emissions.csv
co2_end = 0.832298926 #get_co2_emissions()
dfBackupCapacityOverviewReplacement = DataFrame()
modify_thermal_csv_value(-1) 

print(co2_start)
print(co2_end)
# --- Run the main loop with calculated CO2 limits ---
if !isnothing(co2_start) && !isnothing(co2_end)
    n_steps = 20     # Adjust this value to change the number of steps

    # Calculate the step size
    #step_size = (co2_start - co2_end) / (n_steps - 1)
    #predifined_co2_limits = [210.6065, 199.5658, 188.525, 177.4643, 166.4435, 155.4026, 144.362, 133.3313, 122.2005, 111.2398, 100.199, 89.15829, 78.11754, 67.07679, 56.03605, 44.9953, 33.95455, 22.9138, 11.87305, 9.112661, 6.311205, 6.352674, 3.592486, 1.361944, 0.832299]
    #predifined_co2_limits = [210.6065, 199.5658, 188.525, 177.4643, 166.4435, 155.4026, 144.362, 133.3313, 122.2005, 111.2398, 100.199, 89.15829, 78.11754]
    #predifined_co2_limits = [67.07679, 56.03605, 44.9953, 33.95455, 22.9138, 11.87305, 9.112661, 6.311205, 6.352674, 3.592486, 1.361944, 0.832299]
    #predifined_co2_limits = [13.1687847447678, 10.7014277958143, 8.23407084686073, 5.76671389790715, 3.29935694895358, 2.47690463263572, 1.82520045523619, 1.65445231631786, 1.24322615815893, 0.8266]
    #predifined_co2_limits = [47.71178203, 45.24442508, 42.77706813, 40.30971118, 37.84235423, 35.37499729, 32.90764034, 30.44028339, 27.97292644, 25.50556949, 23.03821254, 20.57085559] 
    predifined_co2_limits = [18.10349864, 15.63614169, 13.16878474, 10.7014278, 8.234070847, 5.766713898, 3.299356949, 2.476904633, 1.825200455, 1.654452316, 1.361943698, 0.832298926]
    # Run Julia multiple times with different CO2 limits
    for (i,co2_limit) in enumerate(predifined_co2_limits)
        #for i in 1:n_steps
        # Calculate the CO2 limit for the current iteration
        #co2_limit = co2_start - (i - 1) * step_size

        # Set the CO2 limit in the CO2_cap.csv file
        modify_co2_cap_csv(co2_limit)

        include("Run.jl")

        # --- Read data for dfBackupCapacityOverviewReplacement ---

        # Read the "backup_cost.csv" file
        dfCapacity = CSV.read("backup_systems/03_real_demand_sec_batteries/results/capacity.csv", DataFrame)

        # Read "costs.csv" and extract "cTotal" value
        dfCosts = CSV.read("backup_systems/03_real_demand_sec_batteries/results/costs.csv", DataFrame)
        cTotal = dfCosts[1, :Total]
    

        # Read "backup_cost.csv" and extract "Backup_Emissions" from the first row
        dfBackupCost_2 = CSV.read("backup_systems/03_real_demand_sec_batteries/results/backup_cost.csv", DataFrame)
        backupEmissions = dfBackupCost_2[1, "Backup_Emissions"] 

        # --- Create or update dfBackupCapacityOverviewReplacement ---

        if i == 1
            # Extract the first two columns for the first iteration, renaming them
            global dfBackupCapacityOverviewReplacement = dfCapacity[:, [:Resource, :EndCap]]
            rename!(dfBackupCapacityOverviewReplacement, :Resource => :Column1, :EndCap => :Column2) 

            # Add 'Backup_Emissions' as the first row
            dfBackupCapacityOverviewReplacement = prepend!(dfBackupCapacityOverviewReplacement,  DataFrame(Symbol("Column1") => ["Backup_Emissions"], Symbol("Column2") => [backupEmissions]))

            # Add 'cTotal' as the last row
            dfBackupCapacityOverviewReplacement = append!(dfBackupCapacityOverviewReplacement, DataFrame(Symbol("Column1") => ["cTotal"], Symbol("Column2") => [cTotal]))

        else
            # Extract only the :EndCap column for subsequent iterations
            temp_df = dfCapacity[:, [:EndCap]] 

            # Rename the column to match dfBackupCapacityOverviewReplacement
            rename!(temp_df, :EndCap => Symbol("Column$i"))

            # Add 'Backup_Emissions' as the first row to temp_df
            temp_df = prepend!(temp_df, DataFrame(Symbol("Column$i") => [backupEmissions]))

            # Add 'cTotal' as the last row to temp_df
            temp_df = append!(temp_df, DataFrame(Symbol("Column$i") => [cTotal]))

            # Now you can concatenate (temp_df now has the correct number of rows)
            global dfBackupCapacityOverviewReplacement = hcat(dfBackupCapacityOverviewReplacement, temp_df, makeunique=true)
        end
        println("Run ", i, " completed with CO2 limit: ", co2_limit)
    end
else
    @error "Could not determine co2_start or co2_end. Check the emissions.csv file and Thermal.csv file."
end

# Write the combined DataFrame to CSV
CSV.write("backup_capacity_overview_replacement.csv", dfBackupCapacityOverviewReplacement)