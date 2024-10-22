using GenX
using Gurobi
using CSV
using DataFrames
using JuMP

# Ensure that no CO2 limit
df_co2_lim = CSV.read("backup_systems/03_real_demand_sec_batteries/policies/CO2_cap.csv", DataFrame)
df_co2_lim[1, "CO_2_Cap_Zone_1"] = 0
CSV.write("backup_systems/03_real_demand_sec_batteries/policies/CO2_cap.csv", df_co2_lim)

# Function to modify Thermal.csv to enable only specific technologies
function modify_thermal_csv(technologies)
    df = CSV.read("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", DataFrame)
    df[!, "Max_Cap_MW"] .= 0    # Reset all "Max_Cap_MW" values to 0
    for tech in technologies
        df[df.Resource .== tech, "Max_Cap_MW"] .= -1  # Enable specified technologies
    end
    CSV.write("backup_systems/03_real_demand_sec_batteries/resources/Thermal.csv", df)
end

# Define the technologies
technologies = [
    "MA_Diesel_Gen",
    "MA_Biodiesel_Gen",
    "MA_Methanol_FC",
    "MA_Hydrogen_FC",
    "MA_Ammonia_Gen",
]

# Define the battery combinations
#battery_combinations = [
#    [],
#    ["MA_Secondary_Li_Ion_BESS", "MA_Secondary_Iron_Air_BESS"],
#    ["MA_Secondary_Li_Ion_BESS", "MA_Secondary_Iron_Air_BESS", "MA_Primary_Al_Air_BESS"],
#]

# Create a DataFrame to store the results
dfResults = DataFrame(
    Technology = String[], 
    Case = String[], 
    TotalCost = Float64[], 
    AnnualEmissions = Float64[],
    BackupFuelCapacity = Float64[],
    BackupVolume = Float64[],
    BackupWeight = Float64[],
    BackupEmissions = Float64[],
    # Capacity columns for each technology
    MA_Diesel_Gen = Float64[],
    MA_Biodiesel_Gen = Float64[],
    MA_Methanol_FC = Float64[],
    MA_Hydrogen_FC = Float64[],
    MA_Ammonia_Gen = Float64[],
    MA_Primary_Al_Air_BESS = Float64[],
    MA_Secondary_Li_Ion_BESS = Float64[],
    MA_Secondary_Iron_Air_BESS = Float64[] 
)

# Iterate over the technologies
for tech in technologies
    # Iterate over the battery combinations
    #for batteries in battery_combinations
        # Enable the current technology and battery combination
        modify_thermal_csv([tech])

        # Run the model
        include("Run.jl")

        # Read the total cost from costs.csv
        dfCost = CSV.read("backup_systems/03_real_demand_sec_batteries/results/costs.csv", DataFrame)
        cTotal = dfCost[1, :Total]

        # Read the AnnualSum from emissions.csv 
        dfEmissions = CSV.read("backup_systems/03_real_demand_sec_batteries/results/emissions.csv", DataFrame)
        annualEmissions = dfEmissions[3, 2] 

        # Read backup overview data
        dfBackupOverview = CSV.read("backup_systems/03_real_demand_sec_batteries/results/backup_overview.csv", DataFrame)
        
        # Extract values from the "Sum" row of backup_overview.csv
        backupFuelCapacity = dfBackupOverview[end, :Backup_fuel_capacity_MMBtu] 
        backupVolume = dfBackupOverview[end, :Volume_m3]
        backupWeight = dfBackupOverview[end, :Weight_kg]
        backupEmissions = dfBackupOverview[end, :Emissions_tCO2]

        # Read capacity data
        dfCapacity = CSV.read("backup_systems/03_real_demand_sec_batteries/results/capacity.csv", DataFrame)
        
        # Extract capacity values for each technology from capacity.csv
        dieselCapacity = dfCapacity[dfCapacity.Resource .== "MA_Diesel_Gen", :EndCap][1]
        biodieselCapacity = dfCapacity[dfCapacity.Resource .== "MA_Biodiesel_Gen", :EndCap][1]
        methanolCapacity = dfCapacity[dfCapacity.Resource .== "MA_Methanol_FC", :EndCap][1]
        hydrogenCapacity = dfCapacity[dfCapacity.Resource .== "MA_Hydrogen_FC", :EndCap][1]
        ammoniaCapacity = dfCapacity[dfCapacity.Resource .== "MA_Ammonia_Gen", :EndCap][1]
        primaryAlAirCapacity = dfCapacity[dfCapacity.Resource .== "MA_Primary_Al_Air_BESS", :EndCap][1]
        secondaryLiIonCapacity = dfCapacity[dfCapacity.Resource .== "MA_Secondary_Li_Ion_BESS", :EndCap][1]
        secondaryIronAirCapacity = dfCapacity[dfCapacity.Resource .== "MA_Secondary_Iron_Air_BESS", :EndCap][1]

        # Create a label for the current case
        case_label = tech

        # Add the results to the DataFrame
        push!(dfResults, (
            tech, 
            case_label, 
            cTotal, 
            annualEmissions, 
            backupFuelCapacity,
            backupVolume,
            backupWeight,
            backupEmissions,
            dieselCapacity,
            biodieselCapacity,
            methanolCapacity,
            hydrogenCapacity,
            ammoniaCapacity,
            primaryAlAirCapacity,
            secondaryLiIonCapacity,
            secondaryIronAirCapacity
        ))
    #end
end

# Write the results to a CSV file
CSV.write("backup_battery_savings_peak_only.csv", dfResults)