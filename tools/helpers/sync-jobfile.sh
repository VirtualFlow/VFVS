#!/usr/bin/env bash

# Copyright (C) 2019 Christoph Gorgulla
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# This file is part of VirtualFlow.
#
# VirtualFlow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# VirtualFlow is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with VirtualFlow.  If not, see <https://www.gnu.org/licenses/>.

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
# 2020-02-23  Including AWS Batch support
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
    echo "Error was trapped which is a nonstandard error." | tee -a /dev/stderr
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" | tee -a /dev/stderr
    echo "Error on line $1" | tee -a /dev/stderr
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
job_letter_new="$(grep -m 1 "^job_letter=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${batchsystem}" = "SLURM" ]; then
    sed -i "s/^#SBATCH --job-name=[a-zA-Z]/#SBATCH --job-name=${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    sed -i "s/^#PBS -N [a-zA-Z]/#PBS -N ${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" = "SGE" ]; then
    sed -i "s/^#\\$ -N [a-zA-Z]/#\$ -N ${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
elif [ "${batchsystem}" = "lsf" ]; then
    sed -i "s/^#bsub -j [a-za-z]/#bsub -j ${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
fi

# For AWS Batch we need to populate a few different fields
if [ "${batchsystem}" = "AWSBATCH" ]; then
	sed -i "s/#JOBLINE#/${jobline_no}/g" ../../workflow/job-files/main/${jobline_no}.job

	object_store_bucket_new="$(grep -m 1 "^object_store_bucket=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
	object_store_job_data_new="$(grep -m 1 "^object_store_job_data_prefix=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
	object_store_input_path="s3://${object_store_bucket_new}/${object_store_job_data_new}/input/vf_input.tar.gz"
	batch_prefix_new="$(grep -m 1 "^aws_batch_prefix=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

	aws_batch_number_of_queues="$(grep -m 1 "^aws_batch_number_of_queues=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
	aws_batch_prefix="$(grep -m 1 "^aws_batch_prefix=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

	sed -i "s|#OBJECT_INPUT#|${object_store_input_path}|g" ../../workflow/job-files/main/${jobline_no}.job

	if [ -f "../../workflow/workunits/${jobline_no}" ]; then
		steps_in_chunk=$(cat ../../workflow/workunits/${jobline_no})
	else
		steps_in_chunk=0
	fi

	jobdef_suffix="16"
	batch_queue_number=$(( ((${jobline_no} - 1) % ${aws_batch_number_of_queues}) + 1))

	if [ -f "../../workflow/workunits/${jobline_no}.size" ]; then
		average_size=$(cat ../../workflow/workunits/${jobline_no}.size)
		echo "average_size=${average_size}"
		if [ "${average_size}" -le "900" ]; then
			jobdef_suffix="8"
			batch_queue_number="${batch_queue_number}s"
		fi
	fi

	sed -i "s/#VCPUS#/${jobdef_suffix}/g" ../../workflow/job-files/main/${jobline_no}.job
	sed -i "s/#STEPS_IN_TASK#/${steps_in_chunk}/g" ../../workflow/job-files/main/${jobline_no}.job
	sed -i "s/#JOBDEF_SUFFIX#/${jobdef_suffix}/g" ../../workflow/job-files/main/${jobline_no}.job
	sed -i "s/#JOBLETTER#/${job_letter_new}/g" ../../workflow/job-files/main/${jobline_no}.job
	sed -i "s/#BATCH_PREFIX#/${batch_prefix_new}/g" ../../workflow/job-files/main/${jobline_no}.job

	sed -i "s/#BATCH_QUEUENUM#/${batch_queue_number}/g" ../../workflow/job-files/main/${jobline_no}.job
fi



