#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#
# Description: Slurm job file. 
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-07  Various improvemnts (version 1.3)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
# 2017-03-20  Adaption to version 8.10
#
# ---------------------------------------------------------------------------


# Slurm Settings
###############################################################################

#SBATCH --job-name=h-1.1
#SBATCH --mail-user=cgorgulla@crystal.harvard.edu
#SBATCH --mail-type=fail
#SBATCH --time=00-01:00:00
#SBATCH --mem-per-cpu=1000
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=main
#SBATCH --output=../workflow/output-files/jobs/job-1.1_%j.out           # File to which standard out will be written
#SBATCH --error=../workflow/output-files/jobs/job-1.1_%j.out            # File to which standard err will be written
#SBATCH --signal=10@300 
##SBATCH --constraint="scratch2"

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
echo "Job infos by scontrol"
echo "------------------------"
scontrol show job $SLURM_JOB_ID

# Running the Job - Screening of the Ligands
######################################################################
echo
echo "                    *** Job Output ***                    "
echo "==========================================================="
echo

# Functions
# Standard error response 
error_response_std() {
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo "Environment variables" 1>&2 
    echo "----------------------------------" 1>&2
    env 1>&2
    if [[ "${error_response}" == "ignore" ]]; then
        echo -e "\n Ignoring error. Trying to continue..."
    elif [[ "${error_response}" == "next_job" ]]; then
        echo -e "\n Ignoring error. Trying to continue and start next job..."
    elif [[ "${error_response}" == "fail" ]]; then
        echo -e "\n Stopping jobline."
        print_job_infos_end
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
    if [[ "${error_response}" == "ignore" ]]; then
        echo -e "\n Ignoring error. Trying to continue..."
    elif [[ "${error_response}" == "next_job" ]]; then
        echo -e "\n Ignoring error. Trying to continue and start next job..."
    elif [[ "${error_response}" == "fail" ]]; then
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
    echo "Starting time:" $STARTINGTIME
    echo "Ending time:  " $(date)
    echo
}

# Checking if the queue should be stopped
check_queue_end1() {

    # Determining the controlfile to use for this jobline
    controlfile=""
    for file in $(ls ../workflow/control/*-* 2>/dev/null|| true); do 
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
        export controlfile="../workflow/control/all.ctrl"
    fi


    # Checking if the queue should be stopped
    line="$(cat ${controlfile} | grep "stop_after_ligand=")"
    stop_after_ligand=${line/"stop_after_ligand="}
    if [ "${stop_after_ligand}" = "yes" ]; then
        echo
        echo "This job line was stopped by the stop_after_ligand flag in the controlfile ${controlfile}."
        echo
        print_job_infos_end
        exit 0
    fi
    
    # Checking if there are still ligand collections todo
    no_collections_incomplete="0"
    i=0
    # Using a loop to try several times if there are no ligand collections left - maybe the files where just shortly inaccessible
    while [ "${no_collections_incomplete}" == "0" ]; do    
        no_collections_incomplete="$(cat ../workflow/ligand-collections/todo/todo.all* ../workflow/ligand-collections/todo/${jobline_no}-* ../workflow/ligand-collections/current/${jobline_no}-* 2>/dev/null | grep -c "[^[:blank:]]" || true)"
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
    line=$(cat ${controlfile} | grep "stop_after_job=")
    stop_after_job=${line/"stop_after_job="}
    if [ "${stop_after_job}" = "yes" ]; then
        echo
        echo "This job line was stopped by the stop_after_job flag in the controlfile ${controlfile}."
        echo
        print_job_infos_end
        exit 0
    fi
}

# Creating the /tmp/${USER} folder if not present
if [ ! -d "/tmp/${USER}" ]; then
    mkdir -p /tmp/${USER}
fi

# Setting important variables
job_line=$(grep -m 1 "job-name=" $0)
jobname=${job_line/"#SBATCH --job-name="}
export old_job_no=${jobname:2}
#export old_job_no=${SLURM_JOB_NAME/h-}
export old_job_no_2=${old_job_no/*.}
export queue_no_1=${old_job_no/.*}
export jobline_no=${queue_no_1}
export batch_system="SLURM"
export sleep_time_1="1"
STARTINGTIME=`date`
export start_time_seconds="$(date +%s)"
job_line=$(grep -m 1 "nodes=" ../workflow/job-files/main/${jobline_no}.job)
export nodes_per_job=${job_line/"#SBATCH --nodes="}
#export nodes_per_job=${SLURM_JOB_NUM_NODES}
export LC_ALL=C

# Determining the controlfile to use for this jobline
controlfile=""
for file in $(ls ../workflow/control/*-* 2>/dev/null|| true); do 
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
    export controlfile="../workflow/control/all.ctrl"
fi

# Setting the job letter1
line=$(cat ${controlfile} | grep -m 1 "^job_letter=")
export job_letter=${line/"job_letter="}

# Setting the verbosity level
line=$(cat ${controlfile} | grep -m 1 "^verbosity=")
export verbosity=${line/"verbosity="}
if [[ "${verbosity}" == "debug" ]]; then
    set -x
fi

# Setting the error sensitivity 
line=$(cat ${controlfile} | grep -m 1 "^error_sensitivity=")
export error_sensitivity=${line/"error_sensitivity="}
if [[ "${error_sensitivity}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.         
fi

# Setting the error response 
line=$(cat ${controlfile} | grep -m 1 "^error_response=")
export error_response=${line/"error_response="}

# Checking if the queue should be stopped
check_queue_end1

# Getting the available wallclock time
job_line=$(grep -m 1 "time=" ../workflow/job-files/main/${jobline_no}.job)
timelimit=${job_line/"#SBATCH --time="}
timelimit=${timelimit//-/:}
export timelimit_seconds="$(echo -n "${timelimit}" | awk -F ':' '{print $4 + $3 * 60 + $2 * 3600 + $1 * 3600 * 24}')"

# Getting the number of queues per step
line=$(cat ${controlfile} | grep "^queues_per_step=")
export queues_per_step=${line/"queues_per_step="}

# Preparing the todo lists for the queues
cd slave
bash prepare-todolists ${jobline_no} ${nodes_per_job} ${queues_per_step}
cd ..

# Starting the individual steps on different nodes
for step_no in $(seq 1 ${nodes_per_job} ); do
    export step_no
    echo "Starting job step $step_no on host $(hostname)."
    srun --relative=$((step_no - 1)) -n 1 -N 1 ../workflow/job-files/sub/one-step.sh &
    pids[$(( step_no - 0 ))]=$!
    sleep "${sleep_time_1}"
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

# Syncing the new jobfile with the settings in the controlfile
cd slave
. sync-jobfile ${jobline_no}
cd ..

# Changing the job name
new_job_no_2=$((old_job_no_2 + 1))
new_job_no="${jobline_no}.${new_job_no_2}"
sed -i "s/^#SBATCH --job-name=${job_letter}.*/#SBATCH --job-name=${job_letter}-${new_job_no}/g" ../workflow/job-files/main/${jobline_no}.job

# Changing the output filenames
sed -i "s|^#SBATCH --output=.*|#SBATCH --output=../workflow/output-files/jobs/job-${new_job_no}_%j.out|g" ../workflow/job-files/main/${jobline_no}.job
sed -i "s|^#SBATCH --error=.*|#SBATCH --output=../workflow/output-files/jobs/job-${new_job_no}_%j.out|g" ../workflow/job-files/main/${jobline_no}.job

# Checking how much time has passed since the job has been started
end_time_seconds="$(date +%s)"
time_diff="$((end_time_seconds - start_time_seconds))"
treshhold=120
if [ "${time_diff}" -le "${treshhold}" ]; then
    echo "Since the beginning of the job less than ${treshhold} seconds have passed."
    echo "Sleeping for some while to prevent a job submission run..."
    sleep ${treshhold}
fi

# Submitting a new new job
cd slave 
. submit ../workflow/job-files/main/${jobline_no}.job
cd ..


# Finalizing the job
#####################################################################################
print_job_infos_end
