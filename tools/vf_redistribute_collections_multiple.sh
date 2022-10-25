#!/usr/bin/env bash

# Copyright (C) 2019 Christoph Gorgulla
#
# This file is part of VirtualFlow.
#
# VirtualFlow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# VirtualFlow is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with VirtualFlow.  If not, see <https://www.gnu.org/licenses/>.

#Checking the input arguments
usage="Usage: vf_redistribute_collections_multiple <input_collection_file> <jobline_no_start> <jobline_no_end> <steps_per_job> <queues_per_step> <collections_per_queue> <output_folder>

<collections_per_queue> collection will be placed per collection file/queue."


if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -ne "7" ]; then
   echo -e "\nWrong number of arguments. Exiting."
   echo -e "\n${usage}\n\n"
   exit 1
fi

# Displaying the banner
echo
echo
. helpers/show_banner.sh
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
jobline_no_start=$2
jobline_no_end=$3
steps_per_job=$4
queues_per_step=$5
collections_per_queue=$6
output_folder=$7

# Preparing the directory
echo -e " *** Preparing the output directory ***\n"
#rm ${output_folder}/* 2>/dev/null || true

# Loop for each collection
queue_no=1
step_no=1
echo -e " *** Starting to distribute the collections ***\n"
sed -i "s/^$//g" ${input_collection_file}
for i in $(seq 1 $collections_per_queue); do
    for job_no in $(seq ${jobline_no_start} ${jobline_no_end}); do
        for step_no in $(seq 1 ${steps_per_job}); do
            for queue_no in $(seq 1 ${queues_per_step_new}); do
                collection="$(head -n 1 ${input_collection_file})"
                collection="$(echo ${collection} | tr -d '\040\011\012\015')"
                if [[ ${collection} == *"_"* ]]; then
                    echo " * Assigning collection ${collection} to queue $job_no-$step_no-$queue_no"
                    echo ${collection} >> ${output_folder}/${job_no}-${step_no}-${queue_no}
                    sed -i "/${collection}/d" ${input_collection_file} || true
                fi
            done
        done
    done
done

echo -e "\n * Resdistribution complete\n\n"

