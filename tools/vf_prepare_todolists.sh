#!/usr/bin/env bash

# Copyright (C) 2019 Christoph Gorgulla
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

#Checking the input arguments
usage="Usage: vf_prepare_todolists.sh <start-jobline-id> <end-jobline-id>
#
#Description: Prepares the todo lists of the joblines in advance of the workflow. Uses the corresponding control files in ../workflow/control for each jobline.
#
#Arguments:
#    <start-jobline-id>:         Positive integer
#    <end-jobline-id>:           Positive integer
#"
if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -ne "2" ]; then
   echo -e "\nWrong number of arguments. Exiting..."
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

determine_controlfile() {

    # Determining the VF_CONTROLFILE to use for this jobline
    cd ..
    VF_CONTROLFILE=""
    for file in $(ls ../workflow/control/*-* 2>/dev/null || true); do
        file_basename=$(basename $file)
        jobline_range=${file_basename/.*}
        jobline_no_start=${jobline_range/-*}
        jobline_no_end=${jobline_range/*-}
        if [[ "${jobline_no_start}" -le "${VF_JOBLINE_NO}" && "${VF_JOBLINE_NO}" -le "${jobline_no_end}" ]]; then
            export VF_CONTROLFILE="${file}"
            break
        fi
    done

    # Checking if a specific control file was found
    if [ -z "${VF_CONTROLFILE}" ]; then
        if [[ -f ../workflow/control/all.ctrl ]]; then

            export VF_CONTROLFILE="../workflow/control/all.ctrl"

        else
            # Error response
            echo "Error: No relevant control file was found..."
            false
        fi
    fi
    cd helpers
}


# Variables
start_jobline_no=$1
end_jobline_no=$2

# Body
cd helpers
for i in $(seq $start_jobline_no $end_jobline_no); do

    # Determining the controlfile
    export VF_JOBLINE_NO=$i
    determine_controlfile

    # Variables
    export VF_TMPDIR="$(grep -m 1 "^tempdir=" ../${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    export VF_JOBLETTER="$(grep -m 1 "^job_letter=" ../${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    steps_per_job="$(grep -m 1 "^steps_per_job=" ../${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
    queues_per_step="$(grep -m 1 "^queues_per_step=" ../${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

    # Preparing the todolists
    bash prepare-todolists.sh $i $steps_per_job $queues_per_step;

done
cd ..


