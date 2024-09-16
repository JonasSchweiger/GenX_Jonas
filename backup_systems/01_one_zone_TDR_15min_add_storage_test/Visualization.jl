using DataFrames


case = joinpath("backup_systems/01_one_zone_perfect_foresight_15min");
emm1 =  CSV.read(joinpath(case,"results/emissions.csv"),DataFrame)

# Pre-processing
tstart = 1
tend = 400
names_emm = ["Zone 1"] 

emm_tot = DataFrame([emm1[3:end,2]],  # Only take the first column of emm1
    ["Zone 1"])

emm_plot = DataFrame([collect((tstart-3):(tend-3)) emm_tot[tstart:tend,1] repeat([names_emm[1]],(tend-tstart+1))],
    ["Hour","MW","Zone"]) 

    emm_plot  |>
@vlplot(mark={:line},
    x={:Hour,title="Time Step (hours)",labels="Zone:n",axis={values=tstart:24:tend}}, y={:MW,title="Emmissions (Tons)",type="quantitative"},
    color={"Zone:n"},width=845,height=400,title="Emmissions per Time Step")
