#!/usr/bin/env bash

#Checking the input arguments
usage="Usage: vf_redistribute_collections_single.sh <input_collection_file> <queues_per_step_new> <steps_per_job_new> <first_job_no> <output_folder>

One collection will be placed per collection file/queue.
All existing files in the output folder will be deleted."


if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -ne "5" ]; then
   echo -e "\nWrong number of arguments. Exiting."
   echo -e "\n${usage}\n\n"
   exit 1
fi

# Displaying the banner
echo
echo
. slave/show_banner.sh
echo
echo

# Standard error response 
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
input_collection_file=$1
queues_per_step_new=$2
steps_per_job_new=$3
first_job_no=$4
output_folder=$5
export VF_CONTROLFILE="../workflow/control/all.ctrl"

# Verbosity
export VF_VERBOSITY_COMMANDS="$(grep -m 1 "^verbosity_commands=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${VF_VERBOSITY_COMMANDS}" = "debug" ]; then
    set -x
fi

# Preparing the directory
echo -e " *** Preparing the output directory ***\n"
rm ${output_folder}/* 2>/dev/null || true

# Loop for each collection
queue_no=1
step_no=1
job_no=${first_job_no}
echo -e " *** Starting to distribute the collections ***\n"
while IFS= read -r line || [[ -n "$line" ]]; do
    echo " * Assigning collection $line to queue $job_no-$step_no-$queue_no"
    echo $line > ${output_folder}/${job_no}-${step_no}-${queue_no}
    queue_no=$((queue_no + 1))
    if [ "${queue_no}" -gt "${queues_per_step_new}" ]; then
        queue_no=1
        step_no=$((step_no + 1))
        if [ "${step_no}" -gt "${steps_per_job_new}" ]; then
            step_no=1
            job_no=$((job_no + 1))
        fi
    fi
done < "${input_collection_file}"

echo -e "\n * Resdistribution complete\n\n"

