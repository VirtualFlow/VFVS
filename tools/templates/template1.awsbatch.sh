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
# Description: AWS Batch job file.
#
# Revision history:
# 2020-02-10  Original version
#
# ---------------------------------------------------------------------------


# Job Information
##################################################################################

df -h

echo
echo "                    *** Job Information ***                    "
echo "==============================================================="
echo
echo "Environment variables"
echo "------------------------"
env
echo
echo

# Running the Job - Screening of the Ligands
######################################################################
echo
echo "                    *** Job Output ***                    "
echo "==========================================================="
echo

# Functions
# Standard error response
error_response_std() {

    # Printing some informatoin
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo "Environment variables" 1>&2
    echo "----------------------------------" 1>&2
    env 1>&2

    # Checking error response type
    if [[ "${VF_ERROR_RESPONSE}" == "ignore" ]] || [[ "${VF_ERROR_RESPONSE}" == "next_job" ]]; then

        # Printing some information
        echo -e "\n * Trying to continue..."

    elif [[ "${VF_ERROR_RESPONSE}" == "fail" ]]; then

        # Printing some information
        echo -e "\n * Trying to stop this queue and causing the jobline to fail..."
        print_job_infos_end

        # Exiting
        exit 1
    fi
}
trap 'error_response_std $LINENO' ERR

# Handling signals
time_near_limit() {
    echo "The script ${BASH_SOURCE[0]} caught a time limit signal. Trying to start a new job."
}
trap 'time_near_limit' 10

termination_signal() {
    echo "The script ${BASH_SOURCE[0]} caught a termination signal. Stopping jobline."
    if [[ "${VF_ERROR_RESPONSE}" == "ignore" ]]; then
        echo -e "\n Ignoring error. Trying to continue..."
    elif [[ "${VF_ERROR_RESPONSE}" == "next_job" ]]; then
        echo -e "\n Ignoring error. Trying to continue and start next job..."
    elif [[ "${VF_ERROR_RESPONSE}" == "fail" ]]; then
        echo -e "\n Stopping the jobline."
        print_job_infos_end
        exit 1
    fi
}
trap 'termination_signal' 1 2 3 9 12 15

# Printing final job information
print_job_infos_end() {
    # Job information
    echo
    echo "                     *** Final Job Information ***                    "
    echo "======================================================================"
    echo
    echo "Starting time:" $VF_STARTINGTIME
    echo "Ending time:  " $(date)
    echo
}


# Setting important variables

export VF_STEP_NO=$((AWS_BATCH_JOB_ARRAY_INDEX + 1))
export VF_QUEUE_NO_2=${VF_STEP_NO}
export VF_QUEUE_NO_12="${VF_QUEUE_NO_1}-${VF_QUEUE_NO_2}"
export VF_BATCHSYSTEM="AWSBATCH"
export VF_STARTINGTIME=`date`
export VF_START_TIME_SECONDS="$(date +%s)"
export LC_ALL=C


# Get the input information
# VF_OBJECT_INPUT has the path to the input deck and control file

aws s3 cp ${VF_OBJECT_INPUT} /tmp/vf_input.tar.gz
gunzip /tmp/vf_input.tar.gz
tar xf /tmp/vf_input.tar -C /tmp/

echo $(pwd)

export VF_CONTAINER_PATH=/opt/vf
export VF_OBJECT_OUTPUT=1
export VF_CONTAINERIZED=1
export VF_OBJECT_INPUT=1
export VF_OBJECT_INPUT_PATH=/tmp/vf_input/input-files
export VF_CONTROLFILE="/tmp/vf_input/all.ctrl"
export VF_QUEUES_PER_STEP=1
export VF_QUEUE_MODE="host"

ls -al ${VF_CONTROLFILE}

object_store_type="$(grep -m 1 "^object_store_type=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_bucket="$(grep -m 1 "^object_store_bucket=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_job_data="$(grep -m 1 "^object_store_job_data_prefix=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

echo "${object_store_type}"

if [[ "${object_store_type}" == "s3" ]]; then
	aws s3 cp s3://${object_store_bucket}/${object_store_job_data}/input/tasks/${VF_QUEUE_NO_1}.tar.gz /tmp/vf_tasks.tar.gz

	gunzip /tmp/vf_tasks.tar.gz
	tar xf /tmp/vf_tasks.tar -C /tmp/
else
    echo "must use s3 for aws batch"
    exit 1
fi



# Verbosity
VF_VERBOSITY_LOGFILES="$(grep -m 1 "^verbosity_logfiles=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_VERBOSITY_LOGFILES
if [ "${VF_VERBOSITY_LOGFILES}" = "debug" ]; then
    set -x
fi

# Setting the error response
VF_ERROR_RESPONSE="$(grep -m 1 "^error_response=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_ERROR_RESPONSE

# VF_TMPDIR
export VF_TMPDIR="$(grep -m 1 "^tempdir_default=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
# Creating the ${VF_TMPDIR}/${USER} folder if not present
if [ ! -d "${VF_TMPDIR}/${USER}" ]; then
    mkdir -p ${VF_TMPDIR}/${USER}
fi

# VF_TMPDIR_FAST
export VF_TMPDIR_FAST="$(grep -m 1 "^tempdir_fast=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
# Creating the ${VF_TMPDIR}/${USER} folder if not present
if [ ! -d "${VF_TMPDIR}/${USER}" ]; then
    mkdir -p ${VF_TMPDIR}/${USER}
fi

export VF_TMPDIR=$VF_TMPDIR_FAST

# Setting the job letter1
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^job_letter=")
export VF_JOBLETTER=${line/"job_letter="}


# Setting the error sensitivity
VF_ERROR_SENSITIVITY="$(grep -m 1 "^error_sensitivity=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [[ "${VF_ERROR_SENSITIVITY}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.
fi

/opt/vf/tools/templates/one-step.sh

if [ "$?" == "1" ]; then
	error_response_std $LINENO
fi

exit_code=0

# Finalizing the job
#####################################################################################
print_job_infos_end
