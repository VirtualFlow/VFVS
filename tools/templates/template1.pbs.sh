#!/bin/bash
# ---------------------------------------------------------------------------
#
# Description: PBS job file.
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-07  Various improvemnts (version 1.3)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
# 2017-04-08  Adjustment to version 9.2
#
# ---------------------------------------------------------------------------


# PBS/Moab Settings
###############################################################################

#PBS -N h-1.1
#PBS -l nodes=1:ppn=24
#PBS -l naccesspolicy=singlejob
#PBS -o ../workflow/output-files/jobs/job-1.1_${PBS_JOBID}.out
#PBS -e ../workflow/output-files/jobs/job-1.1_${PBS_JOBID}.out
#PBS -l walltime=00:12:00
#PBS -A bec00123
#PBS -q mpp2testq
#PBS -m a
#PBS -M silmaril@zedat.fu-berlin.de
#PBS -l signal=10@300

# Job Information
##################################################################################

echo
echo "                    *** Job Information ***                    "
echo "==============================================================="
echo
echo "Environment variables"
echo "------------------------"
env
echo
echo
echo "*** Job Infos by checkjob and qstat -f ***"
echo "--------------------------------------------------"
checkjob $PBS_JOBID
qstat -f $PBS_JOBID

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
    echo "The script ${BASH_SOURCE[0]} caught a time limit signal."
}
trap 'time_near_limit' 10

termination_signal() {
    echo "The script ${BASH_SOURCE[0]} caught a termination signal. Stopping jobline."
    if [[ "${VF_ERROR_RESPONSE}" == "ignore" ]]; then
        echo -e "\n Ignoring error. Trying to continue..."
    elif [[ "${VF_ERROR_RESPONSE}" == "next_job" ]]; then
        echo -e "\n Ignoring error. Trying to continue and start next job..."
        print_job_infos_end
        exit 0
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

# Checking if the queue should be stopped
check_queue_end1() {

    # Determining the VF_CONTROLFILE to use for this jobline
    VF_CONTROLFILE=""
    for file in $(ls ../workflow/control/*-* 2>/dev/null || true); do
        file_basename=$(basename $file)
        jobline_range=${file_basename/.*}
        VF_JOBLINE_NO_START=${jobline_range/-*}
        VF_JOBLINE_NO_END=${jobline_range/*-}
        if [[ "${VF_JOBLINE_NO_START}" -le "${VF_JOBLINE_NO}" && "${VF_JOBLINE_NO}" -le "${VF_JOBLINE_NO_END}" ]]; then
            export VF_CONTROLFILE="${file}"
            break
        fi
    done
    if [ -z "${VF_CONTROLFILE}" ]; then
        export VF_CONTROLFILE="../workflow/control/all.ctrl"
    fi

    # Checking if the queue should be stopped
    line="$(cat ${VF_CONTROLFILE} | grep "stop_after_next_check_interval=")"
    stop_after_next_check_interval=${line/"stop_after_next_check_interval="}
    if [[ "${stop_after_next_check_interval}" == "true" ]]; then
        echo
        echo "This job line was stopped by the stop_after_next_check_interval flag in the VF_CONTROLFILE ${VF_CONTROLFILE}."
        echo
        print_job_infos_end
        exit 0
    fi

    # Checking if there are still ligand collections todo
    no_collections_incomplete="0"
    i=0
    # Using a loop to try several times if there are no ligand collections left - maybe the files where just shortly inaccessible
    while [ "${no_collections_incomplete}" == "0" ]; do
        no_collections_incomplete="$(cat ../workflow/ligand-collections/todo/todo.all* ../workflow/ligand-collections/todo/${VF_JOBLINE_NO}-* ../workflow/ligand-collections/current/${VF_JOBLINE_NO}-* 2>/dev/null | grep -c "[^[:blank:]]" || true)"
        i="$((i + 1))"
        if [ "${i}" == "5" ]; then
            break
        fi
        sleep 1
    done
    if [[ "${no_collections_incomplete}" = "0" ]]; then
        echo
        echo "This job line was stopped because there are no ligand collections left."
        echo
        print_job_infos_end
        exit 0
    fi
}

check_queue_end2() {
    check_queue_end1
    line=$(cat ${VF_CONTROLFILE} | grep "stop_after_job=")
    stop_after_job=${line/"stop_after_job="}
    if [ "${stop_after_job}" = "true" ]; then
        echo
        echo "This job line was stopped by the stop_after_job flag in the VF_CONTROLFILE ${VF_CONTROLFILE}."
        echo
        print_job_infos_end
        exit 0
    fi
}

# Setting important variables
export VF_NODES_PER_JOB=${PBS_NUM_NODES}
export VF_OLD_JOB_NO=${PBS_JOBNAME:2}
export VF_VF_OLD_JOB_NO_2=${VF_OLD_JOB_NO/*.}
export VF_QUEUE_NO_1=${VF_OLD_JOB_NO/.*}
export VF_JOBLINE_NO=${VF_QUEUE_NO_1}
export VF_BATCHSYSTEM="PBS"
export VF_SLEEP_TIME_1="1"
export VF_STARTINGTIME=`date`
export VF_START_TIME_SECONDS="$(date +%s)"
export LC_ALL=C


# Determining the VF_CONTROLFILE to use for this jobline
VF_CONTROLFILE=""
for file in $(ls ../workflow/control/*-* 2>/dev/null|| true); do
    file_basename=$(basename $file)
    jobline_range=${file_basename/.*}
    VF_JOBLINE_NO_START=${jobline_range/-*}
    VF_JOBLINE_NO_END=${jobline_range/*-}
    if [[ "${VF_JOBLINE_NO_START}" -le "${VF_JOBLINE_NO}" && "${VF_JOBLINE_NO}" -le "${VF_JOBLINE_NO_END}" ]]; then
        export VF_CONTROLFILE="${file}"
        break
    fi
done
if [ -z "${VF_CONTROLFILE}" ]; then
    export VF_CONTROLFILE="../workflow/control/all.ctrl"
fi

# Verbosity
VF_VERBOSITY_LOGFILES="$(grep -m 1 "^verbosity_logfiles=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_VERBOSITY_LOGFILES
if [ "${VF_VERBOSITY_LOGFILES}" = "debug" ]; then
    set -x
fi

# VF_TMPDIR
export VF_TMPDIR="$(grep -m 1 "^tempdir=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
# Creating the ${VF_TMPDIR}/${USER} folder if not present
if [ ! -d "${VF_TMPDIR}/${USER}" ]; then
    mkdir -p ${VF_TMPDIR}/${USER}
fi

# Setting the job letter1
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^job_letter=")
export VF_JOBLETTER=${line/"job_letter="}

# Setting the error sensitivity
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "error_sensitivity=")
export VF_ERROR_SENSITIVITY=${line/"error_sensitivity="}
if [[ "${VF_ERROR_SENSITIVITY}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.
fi

# Setting the error response
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^error_response=")
export VF_ERROR_RESPONSE=${line/"error_response="}

# Checking if queue should be stopped
check_queue_end1

# Getting the available wallclock time
job_line=$(grep -m 1 "walltime=" ../workflow/job-files/main/${VF_JOBLINE_NO}.job)
timelimit=${job_line/\#PBS -l walltime=}
export VF_TIMELIMIT_SECONDS="$(echo -n "${timelimit}" | awk -F ':' '{print $3 + $2 * 60 + $1 * 3600}')"

# Getting the number of queues per step
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "queues_per_step=")
export VF_QUEUES_PER_STEP=${line/"queues_per_step="}

# Preparing the todo lists for the queues
cd slave
bash prepare-todolists.sh ${VF_JOBLINE_NO} ${VF_NODES_PER_JOB} ${VF_QUEUES_PER_STEP}
cd ..

# Starting the individual steps on different nodes
for VF_STEP_NO in $(seq 1 ${VF_NODES_PER_JOB} ); do
    export VF_STEP_NO
    echo "Starting job step VF_STEP_NO on host $(hostname)."
    bash ../workflow/job-files/sub/one-step.sh &
    pids[$(( VF_STEP_NO - 0 ))]=$!
    sleep "${VF_SLEEP_TIME_1}"
done

# Waiting for all steps to finish

# Checking if all queues exited without error ("wait" waits for all of them, but always returns 0)
exit_code=0
for pid in ${pids[@]}; do
    wait $pid || let "exit_code=1"
done
if [ "$exit_code" == "1" ]; then
    error_response_std
fi


# Creating the next job
#####################################################################################
echo
echo
echo "                  *** Preparing the next batch system job ***                     "
echo "=================================================================================="
echo

# Checking if the queue should be stopped
check_queue_end2

# Syncing the new jobfile with the settings in the VF_CONTROLFILE
cd slave
. sync-jobfile.sh ${VF_JOBLINE_NO}
cd ..

# Changing the job name
new_job_no_2=$((VF_VF_OLD_JOB_NO_2 + 1))
new_job_no="${VF_JOBLINE_NO}.${new_job_no_2}"
sed -i "s/^#PBS -N ${VF_JOBLETTER}-.*/#PBS -N ${VF_JOBLETTER}-${new_job_no}/g" ../workflow/job-files/main/${VF_JOBLINE_NO}.job

# Changing the output filenames
sed -i "s|^#PBS -\([oe]\) .*|#PBS -\1 ../workflow/output-files/jobs/job-${new_job_no}_\${PBS_JOBID}.out|g" ../workflow/job-files/main/${VF_JOBLINE_NO}.job

# Checking how much time has passed since the job has been started
end_time_seconds="$(date +%s)"
time_diff="$((end_time_seconds - VF_START_TIME_SECONDS))"
treshhold=100
if [ "${time_diff}" -le "${treshhold}" ]; then
    echo "Since the beginning of the job less than ${treshhold} seconds have passed."
    echo "Sleeping for some while to prevent a job submission run..."
    sleep 120
fi


# Submitting a new new job
cd slave 
. submit.sh ../workflow/job-files/main/${VF_JOBLINE_NO}.job
cd ..


# Finalizing the job
#####################################################################################
print_job_infos_end
