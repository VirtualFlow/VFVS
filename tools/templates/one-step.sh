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

# ---------------------------------------------------------------------------
#
# Description: Subjobfile which runs on one node and belongs to one batch system step. 
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-07  Various improvemnts (version 1.3)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------

# Functions
# Standard error response
error_response_std() {

    # Printint some information
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Environment variables" 1>&2
    echo "----------------------------------" 1>&2
    env 1>&2

    # Copying again the queue output files back to the shared filesystem (was done already in the one-queue.sh file, but during job abortions it can fail due to a shortage of time)
    for i in $(seq 1 ${VF_QUEUES_PER_STEP}); do
        VF_QUEUE_NO_3="${i}"
        VF_QUEUE_NO="${VF_QUEUE_NO_12}-${VF_QUEUE_NO_3}"
        cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.* ../workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/ 2>/dev/null || true
    done

    # Checking error response
    if [[ "${VF_ERROR_RESPONSE}" == "ignore" ]]; then

        # Printing some information
        echo -e "\n * Ignoring error. Trying to continue..." | tee /dev/stderr

    elif [[ "${VF_ERROR_RESPONSE}" == "next_job" ]]; then

        # Printing some information
        echo -e "\n * Trying to stop this queue without causing the jobline to fail..." | tee /dev/stderr

        # Exiting
        exit 0

    elif [[ "${VF_ERROR_RESPONSE}" == "fail" ]]; then

        # Printing some information
        echo -e "\n * Trying to stop this queue and causing the jobline to fail..." | tee /dev/stderr

        # Exiting
        exit 1
    fi
}
trap 'error_response_std $LINENO' ERR

time_near_limit() {
    echo "The script one-step.sh caught a time limit signal."
    echo "Sending this signal to all the queues started by this step."
    kill -s 10 ${pids[*]} || true
    wait
}
trap 'time_near_limit' 10

another_signal() {
    echo "The script one-step.sh caught a terminating signal."
    echo "Sending terminating signal to all the queues started by this step."
    kill -s 1 ${pids[*]} || true
    wait
}
trap 'time_near_limit' 1 2 3 9 15


clean_up() {

    # Copying again the queue output files back to the shared filesystem (was done already in the one-queue.sh file, but during job abortions it can fail due to a shortage of time) Only can work if the clean-up of one-queue did not work, since it deletes the temporary queue folder
    for i in $(seq 1 ${VF_QUEUES_PER_STEP}); do
        VF_QUEUE_NO_3="${i}"
        VF_QUEUE_NO="${VF_QUEUE_NO_12}-${VF_QUEUE_NO_3}"
        cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.* ../workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/ 2>/dev/null || true
    done
}
trap 'clean_up' EXIT

# Sourcing bashrc
source ~/.bashrc || true

prepare_queue_files_tmp() {

    # Creating the required folders    
    if [ -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/" ]; then
        rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/
    fi
    mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/
    
    # Copying the required files
    if ls -1 ../workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.* > /dev/null 2>&1; then
        cp ../workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.* ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/
    fi
}

# Verbosity
if [ "${VF_VERBOSITY_LOGFILES}" = "debug" ]; then
    set -x
fi


# Preparing the temporary controlfile
export VF_CONTROLFILE_TEMP=${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/controlfile
mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/
cp ${VF_CONTROLFILE} ${VF_CONTROLFILE_TEMP}

# Setting and exporting variables
export VF_QUEUE_NO_2=${VF_STEP_NO}
export VF_QUEUE_NO_12="${VF_QUEUE_NO_1}-${VF_QUEUE_NO_2}"
export VF_LITTLE_TIME="false";
export VF_START_TIME_SECONDS
export VF_TIMELIMIT_SECONDS
pids=""
store_queue_log_files="$(grep -m 1 "^store_queue_log_files=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Creating required folders
mkdir -p ../workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/
mkdir -p ../workflow/ligand-collections/todo/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/
mkdir -p ../workflow/ligand-collections/current/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/
mkdir -p ../workflow/ligand-collections/done/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/

# Preparing the local docking input files
mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/
docking_files_archive="$(grep -m 1 "^docking_files_archive=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tar -xvzf ${docking_files_archive} -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/
for file in $(find ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/ -iname config.txt); do
    sed -i "s|\.\./|${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/|" $file
done

# Starting the individual queues
for i in $(seq 1 ${VF_QUEUES_PER_STEP}); do
    export VF_QUEUE_NO_3="${i}"
    export VF_QUEUE_NO="${VF_QUEUE_NO_12}-${VF_QUEUE_NO_3}"
    prepare_queue_files_tmp
    echo "Job step ${VF_STEP_NO} is starting queue ${VF_QUEUE_NO} on host $(hostname)."
    if [ ${store_queue_log_files} == "all_uncompressed" ]; then
        source ../workflow/job-files/sub/one-queue.sh >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.all 2>&1 &
    elif [ ${store_queue_log_files} == "all_compressed" ]; then
        source ../workflow/job-files/sub/one-queue.sh 2>&1 | gzip >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.all.gz &
    elif [ ${store_queue_log_files} == "only_error_uncompressed" ]; then
        source ../workflow/job-files/sub/one-queue.sh 2> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.err &
    elif [ ${store_queue_log_files} == "only_error_compressed" ]; then
        source ../workflow/job-files/sub/one-queue.sh 2> >(gzip >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.err.gz) &
    elif [ ${store_queue_log_files} == "std_compressed_error_uncompressed" ]; then
        source ../workflow/job-files/sub/one-queue.sh 1> >(gzip >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.std.gz) 2>> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.err &
    elif [ ${store_queue_log_files} == "all_compressed_error_uncompressed" ]; then
        source ../workflow/job-files/sub/one-queue.sh 1> >(gzip >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.all.gz) 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/queue-${VF_QUEUE_NO}.out.err) &
    elif [ ${store_queue_log_files} == "none" ]; then
        source ../workflow/job-files/sub/one-queue.sh 2>&1 >/dev/null &
    else
        echo "Error: The variable store_log_file in the control file ${VF_CONTROLFILE_TEMP} has an unsupported value (${store_queue_log_files})."
        false
    fi
    pids[$(( i - 1 ))]=$!
done

# Checking if all queues exited without error ("wait" waits for all of them, but always returns 0)
exit_code=0
for pid in ${pids[@]}; do
    wait $pid || let "exit_code=1"
done
if [ "$exit_code" == "1" ]; then
    error_response_std $LINENO
fi

# Cleaning up
exit 0
