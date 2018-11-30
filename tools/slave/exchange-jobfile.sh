#!/bin/bash
# ---------------------------------------------------------------------------
#
# Usage: . exchange-jobfile template_file VF_JOBLINE_NO [quiet]
#
# Description: Exchanges a jobfile in use with a new (template) jobfile.
#
# Option: quiet (optional)
#    Possible values:
#        quiet: No information is displayed on the screen.
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------
# Displaying help if the first argument is -h
usage="Usage: . exchange-jobfile template_file VF_JOBLINE_NO [quiet]"
if [ "${1}" = "-h" ]; then
    echo "${usage}"
    return
fi
if [[ "$#" -ne "2" && "$#" -ne "3" ]]; then
   echo -e "\nWrong number of arguments. Exiting.\n"
   echo -e "${usage}\n\n"
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
jobline_no=${2}

# Determining the controlfile to use for this jobline
controlfile=""
for file in $(ls ../../workflow/control/*-* 2>/dev/null || true); do
    file_basename=$(basename $file)
    jobline_range=${file_basename/.*}
    jobline_no_start=${jobline_range/-*}
    jobline_no_end=${jobline_range/*-}
    if [[ "${jobline_no_start}" -le "${jobline_no}" && "${jobline_no}" -le "${jobline_no_end}" ]]; then
        controlfile="${file}"
        break
    fi
done
if [ -z "${controlfile}" ]; then
    controlfile="../../workflow/control/all.ctrl"
fi

# Getting the batchsystem type
batchsystem="$(grep -m 1 "^batchsystem=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Getting the jobline number and the current job number
job_template=${1}
new_job_file=${jobline_no}.job
if [ "${batchsystem}" = "SLURM" ]; then
    line=$(cat ../../workflow/job-files/main/${new_job_file} | grep -m 1 "job\-name=")
    job_no=${line/"#SBATCH --job-name=[a-zA-Z]-"}
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    line=$(cat ../../workflow/job-files/main/${new_job_file} | grep -m 1 "\-N")
    job_no=${line/"#PBS -N [a-zA-Z]-"}
elif [ "${batchsystem}" = "SGE" ]; then
    line=$(cat ../../workflow/job-files/main/${new_job_file} | grep -m 1 "\-N")
    job_no=${line/"#\$ -N [a-zA-Z]-"}
elif [ "${batchsystem}" = "LSF" ]; then
    line=$(cat ../../workflow/job-files/main/${new_job_file} | grep -m 1 "\-J")
    job_no=${line/"#BSUB -N [a-zA-Z]-"}
fi
# Copying the new job file
cp ../${job_template} ../../workflow/job-files/main/${new_job_file}
. copy-templates.sh subjobfiles

# Changing the job number 1.1 (of template/new job file) to current job number
if [ "${batchsystem}" = "SLURM" ]; then
    sed -i "s/^#SBATCH --job-name=\([a-zA-Z]\)-.*/#SBATCH --job-name=\1-${job_no}/g" ../../workflow/job-files/main/${new_job_file}
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    sed -i "s/^#PBS -N \([a-zA-Z]\)-.*/#PBS -N \1-${job_no}/g" ../../workflow/job-files/main/${new_job_file}
elif [ "${batchsystem}" = "SGE" ]; then
    sed -i "s/^#\\$ -N \([a-zA-Z]\)-.*/#\$ -N \1-${job_no}/g" ../../workflow/job-files/main/${new_job_file}
elif [ "${batchsystem}" = "LSF" ]; then
    sed -i "s/^#BSUB -J \([a-zA-Z]\)-.*/#BSUB -J \1-${job_no}/g" ../../workflow/job-files/main/${new_job_file}
fi

# Changing the output filenames
if [ "${batchsystem}" = "SLURM" ]; then
    sed -i "s|^#SBATCH --output=.*|#SBATCH --output=.*/workflow/output-files/jobs/job-${job_no}_%j.out|g" ../../workflow/job-files/main/${new_job_file}
    sed -i "s|^#SBATCH --error=.*|#SBATCH --output=.*/workflow/output-files/jobs/job-${job_no}_%j.out|g" ../../workflow/job-files/main/${new_job_file}
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    sed -i "s|^#PBS -\([oe]\) .*|#PBS -\1 .*/workflow/output-files/jobs/job-${job_no}_\${PBS_JOBID}.out|g" ../../workflow/job-files/main/${new_job_file}
elif [ "${batchsystem}" = "SGE" ]; then
    sed -i "s|^#\\$ -\([oe]\) .*|#\$ -\1 .*/workflow/output-files/jobs/job-${job_no}_\${JOB_ID}.out|g" ../../workflow/job-files/main/${new_job_file}
elif [ "${batchsystem}" = "LSF" ]; then
    sed -i "s|^#BSUB -oo .*|#BSUB -oo .*/workflow/output-files/jobs/job-${job_no}_%J.out|g" ../../workflow/job-files/main/${new_job_file}
fi

# Displaying some information
if [[ ! "$*" = *"quiet"* ]]; then
    echo "The jobfiles were exchanged."
    echo
fi

