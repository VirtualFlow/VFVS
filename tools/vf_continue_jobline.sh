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
usage="Usage: vf_continue_jobline.sh first_jobline_no last_jobline_no job_template delay_time_in_seconds [quiet]"
if [ "${1}" == "-h" ]; then
    echo -e "\n${usage}\n\n"
    exit 0 
fi

if [[ "$#" -ne "4" ]] && [[ "$#" -ne "5" ]]; then
    echo -e "\nWrong number of arguments. Exiting.\n"
    echo -e "${usage}\n\n"
    exit 1
fi

# Displaying the banner
if [[ "$0" != "$BASH_SOURCE" ]]; then # test if the script was sourced or executed
    echo
    echo
    . helpers/show_banner.sh
    echo
    echo
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
first_jobline_no=${1}
last_jobline_no=${2}
job_template=${3}
export VF_CONTROLFILE="../workflow/control/all.ctrl"
export VF_JOBLETTER="$(grep -m 1 "^job_letter=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"


# Verbosity
VF_VERBOSITY_COMMANDS="$(grep -m 1 "^verbosity_commands=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_VERBOSITY_COMMANDS
if [ "${VF_VERBOSITY_COMMANDS}" = "debug" ]; then
    set -x
fi

# Formatting screen output
echo "" 

# Removing old files if existens
if [ -f "tmp/jobs-to-continue" ]; then
    rm tmp/jobs-to-continue
fi
mkdir -p tmp

# Storing all the jobs which are currently running
touch tmp/jobs-all
bin/sqs > tmp/jobs-all 2>/dev/null || true

# Storing all joblines which have to be restarted
echo "Checking which joblines are already in the batchsystem"
for VF_JOBLINE_NO in $(seq ${first_jobline_no} ${last_jobline_no}); do
    if ! grep -q "${VF_JOBLETTER}\-${VF_JOBLINE_NO}\."  tmp/jobs-all; then
        echo "Adding jobline ${VF_JOBLINE_NO} to the list of joblines to be continued."
        echo ${VF_JOBLINE_NO} >> "tmp/jobs-to-continue"
    else
        echo "Omitting jobline ${VF_JOBLINE_NO} because it was found in the batchsystem."
    fi
done

# Variables
k=0
delay_time="${4}"

# Resetting the collections and continuing the jobs if existent
if [ -f tmp/jobs-to-continue ]; then
    k_max="$(cat tmp/jobs-to-continue | wc -l)"
    for VF_JOBLINE_NO in $(cat tmp/jobs-to-continue ); do
        k=$(( k + 1 ))
        cd helpers
        echo "Continuing jobline ${VF_JOBLINE_NO}"
        . exchange-continue-jobline.sh ${VF_JOBLINE_NO} ${VF_JOBLINE_NO} ${job_template} quiet
        cd ..
        if [ ! "${k}" = "${k_max}" ]; then
            sleep ${delay_time}
        fi
    done
fi

# Removing the temporary files
if [ -f "tmp/jobs-all" ]; then
    rm tmp/jobs-all
fi
if [ -f "tmp/jobs-to-continue" ]; then
    rm tmp/jobs-to-continue
fi

# Displaying some information
if [[ ! "$*" = *"quiet"* ]]; then
    echo "Number of joblines which were continued: ${k}"
    echo
fi
