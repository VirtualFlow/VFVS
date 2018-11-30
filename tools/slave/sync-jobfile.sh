#!/bin/bash
# ---------------------------------------------------------------------------
#
# Usage: . sync-jobfile.sh jobline_no
#
# Description: Synchronizes the jobfile with the settings in the VF_CONTROLFILE
# (the global or local VF_CONTROLFILE if existent).
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
# 2017-03-18  Including the parition in the config file
#
# ---------------------------------------------------------------------------
# Displaying help if first argument is -h
if [ "${1}" = "-h" ]; then
usage="Usage: . sync-jobfile.sh jobline_no"
    echo -e "\n${usage}\n\n"
    return
fi
if [[ "$#" -ne "1" && "$#" -ne "2" ]]; then
   echo -e "\nWrong number of arguments. Exiting."
   echo -e "\n${usage}\n\n"
   return 1
fi

# Standard error response
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
jobline_no=${1}

# Determining the controlfile to use for this jobline
controlfile=""
for file in $(ls ../../workflow/control/*-* 2>/dev/null || true); do
    file_basename=$(basename $file)
    jobline_range=${file_basename/.*}
    jobline_no_start=${jobline_range/-*}
    jobline_no_end=${jobline_range/*-}
    if [[ "${jobline_no_start}" -le "${jobline_no}" && "${jobline_no}" -le "${jobline_no_end}" ]]; then
        export controlfile="${file}"
        break
    fi
done
if [ -z "${controlfile}" ]; then
    export controlfile="../../workflow/control/all.ctrl"
fi

# Getting the batchsystem type
batchsystem="$(grep -m 1 "^batchsystem=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"


# Printing some information
echo -e "Syncing the jobfile of jobline ${jobline_no} with the controlfile file ${controlfile}."

# Syncing the number of nodes
steps_per_job_new="$(grep -m 1 "^steps_per_job=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${batchsystem}" = "SLURM" ]; then
    job_line=$(grep -m 1 "nodes=" ../../workflow/job-files/main/${jobline_no}.job)
    steps_per_job_old=${job_line/"#SBATCH --nodes="}
    sed -i "s/nodes=${steps_per_job_old}/nodes=${steps_per_job_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    job_line=$(grep -m 1 " -l nodes=" ../../workflow/job-files/main/${jobline_no}.job)
    steps_per_job_old=${job_line/"#PBS -l nodes="}
    steps_per_job_old=${steps_per_job_old/:*}
    sed -i "s/nodes=${steps_per_job_old}:/nodes=${steps_per_job_new}:/g" ../../workflow/job-files/main/${jobline_no}.job
fi

# Syncing the number of cpus per step
cpus_per_step_new="$(grep -m 1 "^cpus_per_step=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${batchsystem}" = "SLURM" ]; then
    job_line="$(grep -m 1 "cpus-per-task=" ../../workflow/job-files/main/${jobline_no}.job)"
    cpus_per_step_old=${job_line/"#SBATCH --cpus-per-task="}
    sed -i "s/cpus-per-task=${cpus_per_step_old}/cpus-per-task=${cpus_per_step_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    job_line="$(grep -m 1 " -l nodes=" ../../workflow/job-files/main/${jobline_no}.job)"
    cpus_per_step_old=${job_line/\#PBS -l nodes=*:ppn=}
    sed -i "s/ppn=${cpus_per_step_old}/ppn=${cpus_per_step_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" = "LSF" ]; then
    job_line="$(grep -m 1 "\-n" ../../workflow/job-files/main/${jobline_no}.job)"
    cpus_per_step_old=${job_line/\#BSUB -n }
    sed -i "s/-n ${cpus_per_step_old}/-n ${cpus_per_step_new}/g" ../../workflow/job-files/main/${jobline_no}.job
    sed -i "s/ptile=${cpus_per_step_old}/ptile=${cpus_per_step_new}/g" ../../workflow/job-files/main/${jobline_no}.job
fi

# Syncing the timelimit
line=$(cat ${controlfile} | grep -m 1 "^timelimit=")
timelimit_new="$(grep -m 1 "^timelimit=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${batchsystem}" == "SLURM" ]; then
    job_line=$(grep -m 1 "^#SBATCH \-\-time=" ../../workflow/job-files/main/${jobline_no}.job)
    timelimit_old=${job_line/"#SBATCH --time="}
    sed -i "s/${timelimit_old}/${timelimit_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    job_line=$(grep -m 1 "^#PBS \-l walltime=" ../../workflow/job-files/main/${jobline_no}.job)
    timelimit_old=${job_line/"#PBS -l walltime="}
    sed -i "s/${timelimit_old}/${timelimit_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" == "SGE" ]; then
    job_line=$(grep -m 1 "^#\$ \-l h_rt=" ../../workflow/job-files/main/${jobline_no}.job)
    timelimit_old=${job_line/"#\$ -l h_rt="}
    sed -i "s/${timelimit_old}/${timelimit_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" == "LSF" ]; then
    job_line=$(grep -m 1 "^#BSUB \-W " ../../workflow/job-files/main/${jobline_no}.job)
    timelimit_old=${job_line/"#BSUB -W "}
    sed -i "s/${timelimit_old}/${timelimit_new}/g" ../../workflow/job-files/main/${jobline_no}.job
fi

# Syncing the partition
line=$(cat ${controlfile} | grep -m 1 "^partition=")
partition_new="$(grep -m 1 "^partition=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${batchsystem}" = "SLURM" ]; then
    sed -i "s/--partition=.*/--partition=${partition_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    sed -i "s/^#PBS -q .*/#PBS -q ${partition_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" = "SGE" ]; then
    sed -i "s/^#\\$ -q .*/#\$ -q ${partition_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" = "LSF" ]; then
    sed -i "s/^#BSUB -q .*/#BSUB -q ${partition_new}/g" ../../workflow/job-files/main/${jobline_no}.job
fi

# Syncing the job letter
line=$(cat ${controlfile} | grep -m 1 "^job_letter=")
job_letter_new="$(grep -m 1 "^job_letter=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${batchsystem}" = "SLURM" ]; then
    sed -i "s/^#SBATCH --job-name=[a-zA-Z]/#SBATCH --job-name=${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    sed -i "s/^#PBS -N [a-zA-Z]/#PBS -N ${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" = "SGE" ]; then
    sed -i "s/^#\\$ -N [a-zA-Z]/#\$ -N ${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" = "LSF" ]; then
    sed -i "s/^#BSUB -J [a-zA-Z]/#BSUB -J ${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
fi

