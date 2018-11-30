#!/bin/bash
# ---------------------------------------------------------------------------
#
# Usage: . continue-jobline VF_JOBLINE_NO sync_mode
#
# Description: Continues a jobline by adjusting the latest job script and submitting
# it to the batchsystem.
#
# Option: sync_mode
#    Possible values:
#        sync: The sync-control-jobfile script is called
#        anything else: no synchronization
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------
# Displaying help if the first argument is -h
usage="Usage: . continue-jobline VF_JOBLINE_NO sync_mode"
if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [[ "$#" -ne "2" ]]; then
   echo -e "\nWrong number of arguments. Exiting."
   echo -e "\n${usage}\n\n"
   exit 1
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
# Getting the batchsystem type
batchsystem="$(grep -m 1 "^batchsystem=" ../${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
sync_mode=${2}

# Getting the jobline number and the old job number
VF_JOBLINE_NO=${1}
if [ "${batchsystem}" = "SLURM" ]; then
    line=$(cat ../../workflow/job-files/main/${VF_JOBLINE_NO}.job | grep -m 1 "job-name")
    VF_OLD_JOB_NO=${line/^#SBATCH --job-name=[a-zA-Z]-}
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    line=$(cat ../../workflow/job-files/main/${VF_JOBLINE_NO}.job | grep -m 1 "\-N")
    VF_OLD_JOB_NO=${line/^\#PBS -N [a-zA-Z]-}
elif [ "${batchsystem}" = "SGE" ]; then
    line=$(cat ../../workflow/job-files/main/${VF_JOBLINE_NO}.job | grep -m 1 "\-N")
    VF_OLD_JOB_NO=${line/^\#\$ -N [a-zA-Z]-}
elif [ "${batchsystem}" = "LSF" ]; then
    line=$(cat ../../workflow/job-files/main/${VF_JOBLINE_NO}.job | grep -m 1 "^#BSUB \-J")
    VF_OLD_JOB_NO=${line/^\#BSUB -J [a-zA-Z]-}
fi
VF_VF_OLD_JOB_NO_2=${VF_OLD_JOB_NO/*.}


# Computing the new job number
new_job_no_2=$((VF_VF_OLD_JOB_NO_2 + 1))
new_job_no="${VF_JOBLINE_NO}.${new_job_no_2}"


# Syncing the workflow settings if specified
if [ "${sync_mode}" == "sync" ]; then
    . sync-jobfile.sh ${VF_JOBLINE_NO}
fi

# Changing the job number 1.1 (of template/new job file) to current job number
if [ "${batchsystem}" = "SLURM" ]; then
    sed -i "s/^#SBATCH --job-name=\([a-zA-Z]\)-.*/#SBATCH --job-name=\1-${new_job_no}/g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    sed -i "s/^#PBS -N \([a-zA-Z]\)-.*/#PBS -N \1-${new_job_no}/g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
elif [ "${batchsystem}" = "LSF" ]; then
    sed -i "s/^#BSUB -J \([a-zA-Z]\)-.*/#BSUB -J \1-${new_job_no}/g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
elif [ "${batchsystem}" = "SGE" ]; then
    sed -i "s/^#\\$ -N \([a-zA-Z]\)-.*/#\$ -N \1-${new_job_no}/g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
fi

# Changing the output filenames
if [ "${batchsystem}" = "SLURM" ]; then
    sed -i "s|^#SBATCH --output=.*|#SBATCH --output=../workflow/output-files/jobs/job-${new_job_no}_%j.out|g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
    sed -i "s|^#SBATCH --error=.*|#SBATCH --output=../workflow/output-files/jobs/job-${new_job_no}_%j.out|g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    sed -i "s|^#PBS -\([oe]\) .*|#PBS -\1 ../workflow/output-files/jobs/job-${new_job_no}_\${PBS_JOBID}.out|g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
elif [ "${batchsystem}" = "SGE" ]; then
    sed -i "s|^#\\$ -\([oe]\) .*|#\$ -\1 ../workflow/output-files/jobs/job-${new_job_no}_\${PBS_JOBID}.out|g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
elif [ "${batchsystem}" = "LSF" ]; then
    sed -i "s|^#BSUB -oo .*|#BSUB -oo ../workflow/output-files/jobs/job-${new_job_no}_%J.out|g"  ../../workflow/job-files/main/${VF_JOBLINE_NO}.job
fi


# Submitting new job
. submit.sh ../workflow/job-files/main/${VF_JOBLINE_NO}.job
