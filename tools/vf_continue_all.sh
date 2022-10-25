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
usage="Usage: vf_continue_all.sh <job template> <delay_time_in_seconds>"
if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -ne "2" ]; then
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

# Clean up
clean_up() {
    rm -r ${tempdir}/ 2>/dev/null || true
}
trap 'clean_up' EXIT

# Variables
job_template=$1
delay_time=$2
export VF_CONTROLFILE="../workflow/control/all.ctrl"
export VF_JOBLETTER="$(grep -m 1 "^job_letter=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
no_of_jobfiles=$(ls ../workflow/job-files/main/ | wc -l)
vf_tempdir="$(grep -m 1 "^tempdir_default=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Verbosity
export VF_VERBOSITY_COMMANDS="$(grep -m 1 "^verbosity_commands=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${VF_VERBOSITY_COMMANDS}" = "debug" ]; then
    set -x
fi

# Body
tempdir=${vf_tempdir}/$USER/VFVS/${VF_JOBLETTER}/vf_continue_all_$(date | tr " :" "_")
mkdir -p ${tempdir}
cat /dev/null > ${tempdir}/sqs.out
bin/sqs > ${tempdir}/sqs.out || true

# Loop for each jobfile
counter=1
for file in $(ls -v ../workflow/job-files/main/); do
    VF_JOBLINE_NO=${file/.job}
    if ! grep -q "${VF_JOBLETTER}\-${VF_JOBLINE_NO}\." ${tempdir}/sqs.out; then
        ./vf_continue_jobline.sh ${VF_JOBLINE_NO} ${VF_JOBLINE_NO} ${job_template} 1
        if [ ! "${counter}" -eq "${no_of_jobfiles}" ]; then
            sleep $delay_time
        fi
    fi
    counter=$((counter + 1))
done

# Cleaning up
rm ${tempdir}/sqs.out
