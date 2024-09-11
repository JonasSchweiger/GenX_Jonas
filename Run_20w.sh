#!/bin/bash
#SBATCH --job-name=reg          # create a short name for your job
#SBATCH --nodes=1                           # node count
#SBATCH --ntasks=1                          # total number of tasks across all nodes
#SBATCH --cpus-per-task=48                  # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --output="reg.out"
#SBATCH --error="reg.err"
#SBATCH --mail-type=FAIL                    # notifications for job done & fail
#SBATCH --mail-user=fparolin@mit.edu        # send-to address
#SBATCH --exclusive

# Initialize module
source /etc/profile

module load julia/1.10.1
module load gurobi/gurobi-1102

julia --project=. Run_job_20w.jl

date