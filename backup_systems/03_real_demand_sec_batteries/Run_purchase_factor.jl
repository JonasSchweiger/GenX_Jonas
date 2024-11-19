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


#Influence of emergency purchase fuel factor
#note that emergency purchases of course have to be activated!


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

    df[8, "emergency_quantity_mmbtu"] = co2_limit

    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end

# Get CO2 emissions from backup_cost.csv
function get_co2_emissions()
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/results/backup_cost.csv", DataFrame)
    
    return df[1, "Backup_Emissions"]
end


dfBackupPurchasePenalty = DataFrame()
#modify_thermal_csv_value(-1) 


predifined_purchase_penalties = [1,2,5,10,20]
# Run Julia multiple times with different CO2 limits
for (i,purchase_penalty) in enumerate(predifined_purchase_penalties)

    # Set the CO2 limit in the CO2_cap.csv file
    modify_co2_cap_csv(purchase_penalty)

    include("Run.jl")

    # --- Read data for dfBackupPurchasePenalty ---

    # Read the "backup_cost.csv" file
    dfCapacity = CSV.read("backup_systems/03_real_demand_sec_batteries/results/capacity.csv", DataFrame)

    # Read "costs.csv" and extract "cTotal" value
    dfCosts = CSV.read("backup_systems/03_real_demand_sec_batteries/results/costs.csv", DataFrame)
    cTotal = dfCosts[1, :Total]


    # Read "backup_cost.csv" and extract "Backup_Emissions" from the first row
    dfBackupCost_2 = CSV.read("backup_systems/03_real_demand_sec_batteries/results/backup_cost.csv", DataFrame)
    backupEmissions = dfBackupCost_2[1, "Backup_Emissions"] 

    # --- Create or update dfBackupPurchasePenalty ---

    if i == 1
        # Extract the first two columns for the first iteration, renaming them
        global dfBackupPurchasePenalty = dfCapacity[:, [:Resource, :EndCap]]
        rename!(dfBackupPurchasePenalty, :Resource => :Column1, :EndCap => :Column2) 

        # Add 'Backup_Emissions' as the first row
        dfBackupPurchasePenalty = prepend!(dfBackupPurchasePenalty,  DataFrame(Symbol("Column1") => ["Backup_Emissions"], Symbol("Column2") => [backupEmissions]))

        # Add 'cTotal' as the last row
        dfBackupPurchasePenalty = append!(dfBackupPurchasePenalty, DataFrame(Symbol("Column1") => ["cTotal"], Symbol("Column2") => [cTotal]))
        dfBackupPurchasePenalty = append!(dfBackupPurchasePenalty, DataFrame(Symbol("Column1") => ["purchase_penalty"], Symbol("Column2") => [purchase_penalty]))

    else
        # Extract only the :EndCap column for subsequent iterations
        temp_df = dfCapacity[:, [:EndCap]] 

        # Rename the column to match dfBackupPurchasePenalty
        rename!(temp_df, :EndCap => Symbol("Column$i"))

        # Add 'Backup_Emissions' as the first row to temp_df
        temp_df = prepend!(temp_df, DataFrame(Symbol("Column$i") => [backupEmissions]))

        # Add 'cTotal' as the last row to temp_df
        temp_df = append!(temp_df, DataFrame(Symbol("Column$i") => [cTotal]))
        temp_df = append!(temp_df, DataFrame(Symbol("Column$i") => [purchase_penalty]))

        # Now you can concatenate (temp_df now has the correct number of rows)
        global dfBackupPurchasePenalty = hcat(dfBackupPurchasePenalty, temp_df, makeunique=true)
    end
    println("Run ", i, " completed with CO2 limit: ", purchase_penalty)
end

# Write the combined DataFrame to CSV
CSV.write("backup_purchase_penalty.csv", dfBackupPurchasePenalty)