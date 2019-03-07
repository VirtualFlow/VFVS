#!/bin/bash
# ---------------------------------------------------------------------------
#
# ---------------------------------------------------------------------------

#Checking the input arguments
usage="Usage: vf_start_jobline.sh <start-jobline-id> <end-jobline-id> <job_template> <submit-job> <delay-time-in-seconds>

Description: Prepares the jobfiles of joblines and if specified submits them.

Arguments:
    <start-jobline-id>:         Positive integer
    <end-jobline-id>:           Positive integer
    <job-template>:             Filename (with absolute or relative path) of the job templates in the template folder, depending on the batchsystem
    <submit-job>:               Whether the newly created job should be directly submitted to the batch system. Possible options: submit, nosubmit
    <time-delay-in-seconds>:    Time delay between submitted jobs (to disperse the jobs in time to prevent problems with the central task list)
"

if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0 
fi

if [[ "$#" -ne "5" ]]; then

    # Printing some information
    echo
    echo "The wrong number of arguments was provided."
    echo "Number of expected arguments: 5"
    echo "Number of provided arguments: ${#}"
    echo "Use the -h option to display basic usage information of the command."
    echo
    echo
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
    echo
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
start_jobline_no=${1}
end_jobline_no=${2}
delay_time=${5}
submit_mode=${4}
job_template=${3}
if [ -f ../workflow/control/all.ctrl ]; then
    export VF_CONTROLFILE="../workflow/control/all.ctrl"
else
    export VF_CONTROLFILE="templates/all.ctrl"
fi

# Verbosity
VF_VERBOSITY_COMMANDS="$(grep -m 1 "^verbosity_commands=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_VERBOSITY_COMMANDS
if [ "${VF_VERBOSITY_COMMANDS}" = "debug" ]; then
    set -x
fi

# Getting the batchsystem type
batchsystem="$(grep -m 1 "^batchsystem=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Formatting screen output
echo "" 
 
# Duplicating the main template job file and syncing the copied jobfiles with the control file
for i in $(seq ${start_jobline_no} ${end_jobline_no}); do
    cp ${job_template} ../workflow/job-files/main/${i}.job
    sed -i "s/-1\.1/-${i}\.1/g" ../workflow/job-files/main/${i}.job
    cd slave
    . sync-jobfile.sh ${i}
    cd ..
done

# Formatting screen output
echo "" 

# Submitting the job files
if [[ "${submit_mode}" = "submit" ]]; then
    cd slave
    for i in $(seq ${start_jobline_no} ${end_jobline_no}); do
        . submit.sh ../workflow/job-files/main/${i}.job
        if [ ! "${i}" = "${end_jobline_no}" ]; then
            sleep ${delay_time}
        fi
    done
    cd ..
fi