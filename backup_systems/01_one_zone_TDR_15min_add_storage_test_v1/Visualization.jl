using DataFrames





###############################
#cost split diagram
# Read all NetRevenue files from their respective folders
netrevenue_files = ["NetRevenue.csv", "NetRevenue.csv", "NetRevenue.csv", "NetRevenue.csv"]
result_folders = ["results", "results_1", "results_2", "results_3"]

# Assuming you have the necessary packages loaded (CSV, DataFrames, StatsPlots, GenX)

# Function to read a specific row from a CSV file in a given folder
function read_row(folder, file, row_number)
    filepath = joinpath(case, folder, file)
    df = CSV.read(filepath, DataFrame, missingstring="NA")
    return df[row_number, :]
end

# Extract specific rows from different folders
netrevenue_rows = [
    read_row(result_folders[1], netrevenue_files[1], 1),
    read_row(result_folders[2], netrevenue_files[2], 2),
    read_row(result_folders[3], netrevenue_files[3], 3),
    read_row(result_folders[4], netrevenue_files[4], 4)
]

# Combine the rows into a DataFrame
netrevenue = vcat(netrevenue_rows...)

# Rest of the code (similar to the first example)
CSV.write(joinpath(outputs_path, "cost_rows.csv"), netrevenue)

netrevenue =  CSV.read(joinpath(case,"results/cost_rows.csv"),DataFrame,missingstring="NA")

xnames = netrevenue[!,2]
names1 = ["Investment cost" "Investment cost Storage" "Fixed OM cost" "OM Cost Storage" "Variable OM cost" "Fuel cost" "Start Cost" "Revenue"]

# Assuming 'gen' and 'dfBackupOverview' are available from your previous context
netrev_backup_fix = GenX.backup_inv_cost_per_mwhyr.(gen) .* dfBackupOverview[:, 2]
netrev_backup_var = GenX.backup_fixed_om_cost_per_mwhyr.(gen) .* dfBackupOverview[:, 2]

netrev = [netrevenue[!, 6] + netrevenue[!, 7] + netrevenue[!, 8] netrev_backup_fix netrevenue[!, 10] + netrevenue[!, 11] + netrevenue[!, 12] netrev_backup_var netrevenue[!, 14] + netrevenue[!, 16] netrevenue[!, 15] netrevenue[!, 18] netrevenue[!, 21]]

groupedbar(
    xnames, netrev,
    bar_position=:stack, bar_width=0.9, size=(850, 800),
    labels=names1, title="Cost Allocation", xlabel="Node", ylabel="Cost (Dollars)",
    titlefontsize=10, legend=:outerright, ylims=[0, maximum(netrevenue[!, "Revenue"])], xrotation=90
)
StatsPlots.scatter!(xnames, netrevenue[!, "Revenue"], label="Revenue", color="black")

#####################ä


#emissions diagram (works)
# Read all Emission files from their respective folders
emission_files = ["emissions.csv", "emissions.csv", "emissions.csv", "emissions.csv"]
result_folders = ["results", "results_1", "results_2", "results_3"]

# Assuming you have the necessary packages loaded (CSV, DataFrames, StatsPlots, GenX)

# Function to read a specific row from a CSV file in a given folder
function read_row(folder, file, row_number)
    filepath = joinpath(case, folder, file)
    df = CSV.read(filepath, DataFrame, missingstring="NA")
    return df[row_number, :]
end

# Extract specific rows from different folders
emission_rows = [
    read_row(result_folders[1], emission_files[1], 2),
    read_row(result_folders[2], emission_files[2], 2),
    read_row(result_folders[3], emission_files[3], 2),
    read_row(result_folders[4], emission_files[4], 2)
]

# Combine the rows into a DataFrame
emissions_full = vcat(emission_rows...)
# Rest of the code (similar to the first example)
CSV.write(joinpath(outputs_path, "emissions_full.csv"), emissions_full)

emissions_full =  CSV.read(joinpath(case,"results/emissions_full.csv"),DataFrame,missingstring="NA")

println(typeof(emissions_full))


xnames_2 = ["Diesel Generator", "Methanol FC", "Ammonia Generator"]
emissions_plot = emissions_full[1:3, 2]

Plots.bar(xnames_2, emissions_plot, 
    xlabel = "Technology Options", 
    ylabel = "Emission Values", 
    label = nothing,  # No labels on individual bars
    legend = :topleft, # Position the legend
    title = "Emissions by Technology Option"
)




########################################
#simpler code from before
# Read all NetRevenue files from their respective folders
netrevenue_files = ["NetRevenue.csv", "NetRevenue.csv", "NetRevenue.csv", "NetRevenue.csv"]
result_folders = ["results", "results_1", "results_2", "results_3"]

netrevenues = [CSV.read(joinpath(case, folder, file), DataFrame, missingstring="NA") 
               for (folder, file) in zip(result_folders, netrevenue_files)]

xnames = netrevenues[1][!,2]  # Assuming technology names are the same in all files
names1 = ["Investment cost" "Investment cost Storage" "Fixed OM cost" "OM Cost Storage" "Variable OM cost" "Fuel cost" "Start Cost" "Revenue"]


# Extract relevant cost data from each file (specifically from column 6)
netrevs = []
for netrevenue in netrevenues
    cost_col_index = 6  # Fixed column index

    # Check if column 6 has any non-zero values
    if any(netrevenue[!, cost_col_index] .!= 0)
        cost_data = netrevenue[!, cost_col_index]
        revenue_data = netrevenue[!,"Revenue"]
        
        push!(netrevs, [cost_data, revenue_data]) 
    else
        println("Warning: Column 6 in $(netrevenue_files[i]) has all zeros. Skipping this file.")
    end
end

################################################

#this code works:

netrevenue =  CSV.read(joinpath(case,"results/NetRevenue.csv"),DataFrame,missingstring="NA")


xnames = netrevenue[!,2]
names1 =  ["Investment cost" "Investment cost Storage" "Fixed OM cost" "OM Cost Storage" "Variable OM cost" "Fuel cost" "Start Cost" "Revenue"]

netrev_backup_fix = GenX.backup_inv_cost_per_mwhyr.(gen) .* dfBackupOverview[:,2]
netrev_backup_var = GenX.backup_fixed_om_cost_per_mwhyr.(gen) .* dfBackupOverview[:,2]

netrev = [netrevenue[!,6]+netrevenue[!,7]+netrevenue[!,8] netrev_backup_fix netrevenue[!,10]+netrevenue[!,11]+netrevenue[!,12] netrev_backup_var netrevenue[!,14]+netrevenue[!,16] netrevenue[!,15] netrevenue[!,18] netrevenue[!,21]]


groupedbar(xnames,netrev, bar_position = :stack, bar_width=0.9,size=(850,800),
    labels=names1,title="Cost Allocation",xlabel="Node",ylabel="Cost (Dollars)", 
    titlefontsize=10,legend=:outerright,ylims=[0,maximum(netrevenue[!,"Revenue"])],xrotation = 90)
StatsPlots.scatter!(xnames,netrevenue[!,"Revenue"],label="Revenue",color="black")


##############################################

###################################################
#this code works!!
# Pre-processing for emissions graph
emm1 =  CSV.read(joinpath(case,"results/emissions.csv"),DataFrame)
tstart = 1
tend = 600

# Assuming emm1 contains emissions data for only one zone
emm_tot = emm1[3:end,2]

emm_plot = DataFrame([collect((tstart-3):(tend-3)) emm_tot[tstart:tend,1] repeat(["Zone 1"],(tend-tstart+1))],
    ["Hour","MW","Zone"]);

emm_plot  |>@vlplot(mark={:line},
    x={:Hour,title="Time Step (hours)",axis={values=tstart:20:tend}}, 
    y={:MW,title="Emissions (Tons)",type="quantitative"},
    width=845,height=400,title="Emissions")

#######################################################

