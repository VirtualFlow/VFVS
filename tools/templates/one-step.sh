#!/bin/bash
# ---------------------------------------------------------------------------
#
# Description: Subjobfile which runs on one node and belongs to one batch system step. 
#
# Revision history:
# 2015-12-28  Import of file from JANINA version 2.2 and adaption to STELLAR version 6.1
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------

# Setting the verbosity level
if [[ "${verbosity}" == "debug" ]]; then
    set -x
fi

# Setting the error sensitivity 
if [[ "${error_sensitivity}" == "high" ]]; then
    set -uo pipefail
    trap "" PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.     
fi

# Functions
# Standard error response 
error_response_std() {
    echo "Error was trapped" 1>&2
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" 1>&2
    echo "Error on line $1" 1>&2
    echo "Environment variables" 1>&2 
    echo "----------------------------------" 1>&2
    env 1>&2
    if [[ "${error_response}" == "ignore" ]]; then
        echo -e "\n * Ignoring error. Trying to continue..."
    elif [[ "${error_response}" == "next_job" ]]; then
        echo -e "\n * Trying to stop this step without stopping the jobline/causing a failure..."
        exit 0
    elif [[ "${error_response}" == "fail" ]]; then
        exit 1
    fi
}
trap 'error_response_std $LINENO' ERR

# Handling signals
time_near_limit() {
    echo "The script ${BASH_SOURCE[0]} caught a time limit signal at $(date)."
    echo "Sending this signal to all the queues started by this step."
    kill -s 10 ${pids[*]} || true
    wait
}
trap 'time_near_limit' 10
termination_signal() {
    echo "The script ${BASH_SOURCE[0]} caught a termination signal at $(date)."
    echo "Sending termination signal to all the queues started by this step."
    kill -s 1 ${pids[*]} || true
    wait
}
trap 'termination_signal' 1 2 3 9 12 15


# Creating the required folders    
if [ ! -d "/tmp/${USER}/" ]; then
    mkdir /tmp/${USER}/
fi

prepare_queue_files_tmp() {
    # Creating the required folders    
    if [ -d "/tmp/${USER}/${queue_no}/" ]; then
        rm -r /tmp/${USER}/${queue_no}/
    fi
    mkdir -p /tmp/${USER}/${queue_no}/workflow/output-files/queues
    
    # Copying the requires files
    if ls -1 ../workflow/output-files/queues/queue-${queue_no}.* > /dev/null 2>&1; then
        cp ../workflow/output-files/queues/queue-${queue_no}.* /tmp/${USER}/${queue_no}/workflow/output-files/queues/
    fi    
}

# Setting important variables
export queue_no_2=${step_no}
export queue_no_12="${queue_no_1}-${queue_no_2}"
export little_time="false";
export start_time_seconds
export timelimit_seconds
pids=""

# Starting the individual queues
for i in $(seq 1 ${queues_per_step}); do
    export queue_no_3="${i}"
    export queue_no="${queue_no_12}-${queue_no_3}"
    prepare_queue_files_tmp
    echo "Job step ${step_no} is starting queue ${queue_no} on host $(hostname)."
    bash ../workflow/job-files/sub/one-queue.sh >> /tmp/${USER}/${queue_no}/workflow/output-files/queues/queue-${queue_no}.out 2>&1 &
    pids[$(( i - 0 ))]=$!
done

# Checking if all queues exited without error ("wait" waits for all of them, but always returns 0)
exit_code=0
for pid in ${pids[@]}; do
    wait $pid || let "exit_code=1"
done
if [ "$exit_code" == "1" ]; then
    error_response_std
fi

exit 0
