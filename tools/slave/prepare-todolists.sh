#!/bin/bash
# ----------------------------
#
# Usage: . prepare-todolists.sh jobline_no steps_per_job queues_per_step [quiet]
#
# Description: prepares the todolists for the queues. The tasks are taken from the central todo list ../../workflow/ligand-collections/todo/todo.all
#
# Option: quiet (optional)
#    Possible values:
#        quiet: No information is displayed on the screen.
#
# ---------------------------------------------------------------------------

# TODO: improve second backup mecha (copying back)

# Displaying help if the first argument is -h
usage="Usage: . prepare-todolists.sh jobline_no steps_per_job queues_per_step [quiet]"
if [ "${1}" = "-h" ]; then
    echo "${usage}"
    return
fi

# Setting the error sensitivity
if [[ "${VF_ERROR_SENSITIVITY}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.
fi

# Variables
queue_no_1="${1}"
steps_per_job="${2}"
queues_per_step="${3}"
export LC_ALL=C
todo_file_temp=${VF_TMPDIR}/${USER}/VFLP/${VF_JOBLETTER}/${VF_JOBLINE_NO}/prepare-todolists/todo.all

# Verbosity (the script is only called by the job scripts)
if [ "${VF_VERBOSITY_LOGFILES}" = "debug" ]; then
    set -x
fi

# Printing some information
echo -e "\n * Preparing the to-do lists for jobline ${queue_no_1}\n"

# Standard error response
error_response_std() {
    echo "Error has been trapped."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    #clean_up
    if [[ "${VF_ERROR_RESPONSE}" == "ignore" ]]; then
        echo -e "\n * Ignoring error. Trying to continue..."
    elif [[ "${VF_ERROR_RESPONSE}" == "next_job" ]]; then
        echo -e "\n * Trying to stop this job and to start a new job..."
        exit 0        exit 0
    elif [[ "${VF_ERROR_RESPONSE}" == "fail" ]]; then
        echo -e "\n * Stopping this jobline."
        exit 1
    fi
}
# Trapping only after we got hold of the to-do.all file (the wait command seems to fail when catching USR1, and thus causes the general error response rather than a time_near_limit response)

# Handling signals
time_near_limit() {
    echo "The script ${BASH_SOURCE[0]} caught a time limit signal."
    # clean_up
    exit 0
}
trap 'time_near_limit' 10

termination_signal() {
    echo "The script ${BASH_SOURCE[0]} caught a termination signal."
    # clean_up
    exit 1
}
trap 'termination_signal' 1 2 3 9 15


next_todo_list() {

    # Variables
    next_todo_list_index=$(printf "%04d" $((10#${current_todo_list_index}+1)) )

    # Checking if another todo file exists
    if [ -f ../../workflow/ligand-collections/todo/todo.all.${next_todo_list_index} ]; then

        # Printing information
        echo "The next todo list will be used (todo.all.${next_todo_list_index})"

        # Changing the symlink
        rm ../../workflow/ligand-collections/todo/todo.all.locked
        ln -s todo.all.${next_todo_list_index} ../../workflow/ligand-collections/todo/todo.all.locked

        # Copying the new todo list to temp
        cp ../../workflow/ligand-collections/todo/todo.all.${next_todo_list_index} ${todo_file_temp}

        # Emptying the old todo list
        echo -n "" > ../../workflow/ligand-collections/todo/todo.all.${current_todo_list_index}

        # Changing variables
        current_todo_list_index=${next_todo_list_index}
    fi
}
trap 'termination_signal' 1 2 3 9 15

# Clean up when exiting
clean_up() {

#    # Moving the to-do.all file to its original place
#    other_todofile_exists="false"
#    if [ -f ../../workflow/ligand-collections/todo/todo.all ]; then
#        echo "Warning: The file ../../workflow/ligand-collections/todo/todo.all already exists."
#        no_of_lines_1=$(fgrep -c "" ../../workflow/ligand-collections/todo/todo.all)
#        no_of_lines_2=$(fgrep -c "" "${todo_file_temp}")
#        other_todofile_exists="true"
#        other_todofile_is_larger="false"
#        if [ "${no_of_lines_1}" -ge "${no_of_lines_2}" ]; then
#            echo "The number of lines in the found todo file is larger than in our one. Discarding our version."
#            other_todofile_is_larger="true"
#        else
#            echo "The number of lines in the found todo file is smaller than in our one. Using our version."
#        fi
#    fi
#
#    # Checking if our to-do file has size zero and the locked one is very large
#    copy_flag="true"
#    #if [[ ! -s ${todo_file_temp} ]] && [[ -f ../../workflow/ligand-collections/todo/todo.all.locked ]]; then
#    #    no_of_lines_1=$(fgrep -c "" ../../workflow/ligand-collections/todo/todo.all.locked 2>/dev/null || true)
#    #    if [[ "${no_of_lines_1}" -ge "1000" ]]; then
#    #        copy_flag="false"
#    #    fi
#    #fi
#
#    if [[ "${other_todofile_exists}" == "false"  ]] || [[ "${other_todofile_exists}" == "true" && "${other_todofile_is_larger}" == "false" ]]; then
#        if [[ -f "${todo_file_temp}" && "${copy_flag}" == "true" ]]; then
#            mv ${todo_file_temp}  ../../workflow/ligand-collections/todo/
#            echo -e "\nThe file ${todo_file_temp} has been moved back to the original folder (../../workflow/ligand-collections/todo/).\n"
#            rm ../../workflow/ligand-collections/todo/todo.all.locked || true
#
#        elif [[ -f ../../workflow/ligand-collections/todo/todo.all.locked ]]; then
#            mv ../../workflow/ligand-collections/todo/todo.all.locked ../../workflow/ligand-collections/todo/todo.all
#            echo -e "The file ../../workflow/ligand-collections/todo/todo.all.locked has been moved back to ../../workflow/ligand-collections/todo/"
#
#        else
#            echo -e "\nThe file ${todo_file_temp} could not be moved back to the original folder (../../workflow/ligand-collections/todo/)."
#            echo -e "Also the file ../../workflow/ligand-collections/todo/todo.all.locked could not be moved back to ../../workflow/ligand-collections/todo/"
#        fi
#    fi
    cp ${todo_file_temp}  ../../workflow/ligand-collections/todo/todo.all.locked
    mv ../../workflow/ligand-collections/todo/todo.all.locked ../../workflow/ligand-collections/todo/todo.all
    rm -r ${VF_TMPDIR}/${USER}/VFLP/${VF_JOBLETTER}/${VF_JOBLINE_NO} || true
}
trap 'clean_up' EXIT

# Hiding the to-do.all list
status="false";
k="1"
max_iter=250
if [ ! -d ${VF_TMPDIR}/${USER}/VFLP/${VF_JOBLETTER}/${VF_JOBLINE_NO}/prepare-todolists/ ]; then
    mkdir -p ${VF_TMPDIR}/${USER}/VFLP/${VF_JOBLETTER}/${VF_JOBLINE_NO}/prepare-todolists/
fi
modification_time_difference=0
start_time_waiting="$(date +%s)"
line=$(cat ../${VF_CONTROLFILE} | grep "^dispersion_time_min=")
dispersion_time_min=${line/"dispersion_time_min="}
line=$(cat ../${VF_CONTROLFILE} | grep "^dispersion_time_max=")
dispersion_time_max=${line/"dispersion_time_max="}
modification_time_treshhold=$(shuf -i ${dispersion_time_min}-${dispersion_time_max} -n1)
modification_time_treshhold_lockedfile="3600"              # one hour

# Loop for hiding the todo.all file
while [[ "${status}" = "false" ]]; do
    modification_time=$(stat -c %Z ../../workflow/ligand-collections/todo/todo.all || true)
    if [ "${modification_time}" -eq "${modification_time}" ]; then
        modification_time_difference="$(($(date +%s) - modification_time))"
    else
        modification_time_difference=0
    fi
    if [ "${modification_time_difference}" -ge "${modification_time_treshhold}" ]; then
        date
        if mv ../../workflow/ligand-collections/todo/todo.all ../../workflow/ligand-collections/todo/todo.all.locked 2>/dev/null; then
            cp ../../workflow/ligand-collections/todo/todo.all.locked ${todo_file_temp}
            current_todo_list_index="$(realpath ../../workflow/ligand-collections/todo/todo.all.locked | xargs basename | xargs basename | awk -F '.' '{print $3}')"
            cp ${todo_file_temp} ../../workflow/ligand-collections/var/todo.all.${current_todo_list_index}.bak.${queue_no_1}
            status="true"
            trap 'error_response_std $LINENO' ERR
        else
            sleep 1."$(shuf -i 0-9 -n1)"
        fi
    else

        echo "The ligand-collections/todo/todo.all (if existent) did not meet the requirements for continuation (trial ${k})."
        sleep "$(shuf -i 10-30 -n1).$(shuf -i 0-9 -n1)"
        if [ -f ../../workflow/ligand-collections/todo/todo.all.locked ]; then
            # Checking the locked file
            modification_time=$(stat -c %Z ../../workflow/ligand-collections/todo/todo.all.locked || true)
            if [ "${modification_time}" -eq "${modification_time}" ]; then
                modification_time_difference="$(($(date +%s) - modification_time))"
            else
                modification_time_difference=0
            fi
            if [ "${modification_time_difference}" -ge "${modification_time_treshhold_lockedfile}" ]; then
                echo " * The file ../../workflow/ligand-collections/todo/todo.all does exist. Probably it was abandoned because the locked file is quite old."
                echo " * Adopting the locked file to this jobline."
                cp ../../workflow/ligand-collections/todo/todo.all.locked ${todo_file_temp}
                status="true"
                trap 'error_response_std $LINENO' ERR
            elif [ "${k}" = "${max_iter}" ]; then
                echo "Reached iteration ${max_iter}. Also the file ../../workflow/ligand-collections/todo/todo.all.locked does not exit."
                echo "This seems to be hopeless. Stopping the refilling process."
                error_response_std
            fi
        fi
        k=$((k+1))
    fi
done
end_time_waiting="$(date +%s)"

# Checking if there are tasks left in the to-do file
no_collections_incomplete="$(cat ${todo_file_temp} 2>/dev/null | grep -c "[^[:blank:]]" || true)"
if [[ "${no_collections_incomplete}" = "0" ]]; then

    # Checking if there is one more todo list
    next_todo_list
    no_collections_incomplete="$(cat ${todo_file_temp} 2>/dev/null | grep -c "[^[:blank:]]" || true)"

    # If no more new todo list, quitting
    if [[ "${no_collections_incomplete}" = "0" ]]; then
        echo "There is no more ligand collection in the todo.all file. Stopping the refilling procedure."
        exit 0
    fi
fi

# Removing empty lines
grep '[^[:blank:]]' < ${todo_file_temp} > ${todo_file_temp}.tmp || true
mv ${todo_file_temp}.tmp ${todo_file_temp}

# Variables
line=$(cat ../${VF_CONTROLFILE} | grep "collection_folder=" | sed 's/\/$//g')
collection_folder=${line/"collection_folder="}
collection_folder=${collection_folder%/}
VF_START_TIME_SECONDS="$(date +%s)"

# Getting the number of ligands to-do per queue
line=$(cat ../${VF_CONTROLFILE} | grep "ligands_todo_per_queue=")
ligands_todo_per_queue=${line/"ligands_todo_per_queue="}

# Getting the number of ligands per refilling step
line=$(cat ../${VF_CONTROLFILE} | grep "ligands_per_refilling_step=")
ligands_per_refilling_step=${line/"ligands_per_refilling_step="}

# Screen formatting output
if [[ ! "$*" = *"quiet"* ]]; then
    echo
fi

# Creating a temporary to-do file with the new ligand collections
todo_new_temp_basename="${VF_TMPDIR}/${USER}/VFLP/${VF_JOBLETTER}/${VF_JOBLINE_NO}/prepare-todolists/todo.new"

# Getting the number of ligands which are already in the local to-do lists
ligands_todo=""
queue_collection_numbers=""
for queue_no_2 in $(seq 1 ${steps_per_job}); do
    # Loop for each queue of the node
    for queue_no_3 in $(seq 1 ${queues_per_step}); do

        # Variables
        queue_no="${queue_no_1}-${queue_no_2}-${queue_no_3}"

        # TODO: checking if it works (job run on test). Read the entire listinto memory as bash array. 10K package size during refilling. Test the new ligand-list mechanism during breaks.

        # Creating empty temp todo files
        echo -n "" > ${todo_new_temp_basename}_${queue_no}

        ligands_todo[${queue_no_2}0000${queue_no_3}]=0
        queue_collection_numbers[${queue_no_2}0000${queue_no_3}]=0
        # Getting the current number of the ligands to-do
        if [ -f "../../workflow/ligand-collections/todo/${queue_no}" ]; then
            queue_collection_index=0
            for queue_collection in $(awk '{print $1}' ../../workflow/ligand-collections/todo/${queue_no}); do
                queue_collection_lengths=$(awk '{print $2}' ../../workflow/ligand-collections/todo/${queue_no} | tr "\n" " ")
                queue_collection_lengths=(${queue_collection_lengths})
		        no_to_add=${queue_collection_lengths[queue_collection_index]}
                if [ ! "${no_to_add}" -eq "${no_to_add}" ]; then
                    echo " * Warning: Could not get the length of collection ${queue_collection}. Found value is: ${no_to_add}. Using value 0 for the length."
                    no_to_add=0
                fi
                ligands_todo[${queue_no_2}0000${queue_no_3}]=$((ligands_todo[${queue_no_2}0000${queue_no_3}] + ${no_to_add} ))
                queue_collection_numbers[${queue_no_2}0000${queue_no_3}]=$((queue_collection_numbers[${queue_no_2}0000${queue_no_3}] + 1 ))
                queue_collection_index=$((queue_collection_index+1))
            done
        else
        # If no local to-do list exists create one
            touch ../../workflow/ligand-collections/todo/${queue_no}
        fi
        if [ -f "../../workflow/ligand-collections/current/${queue_no}" ]; then
            queue_collection_index=0
            for queue_collection in $(awk '{print $1}' ../../workflow/ligand-collections/current/${queue_no}); do
                queue_collection_tranch=${queue_collection/_*}
                queue_collection_ID=${queue_collection/*_}
                queue_collection_lengths=$(awk '{print $2}' ../../workflow/ligand-collections/current/${queue_no} | tr "\n" " ")
                no_to_add=${queue_collection_lengths[queue_collection_index]}
                if [ ! "${no_to_add}" -eq "${no_to_add}" ]; then
                    echo " * Warning: Could not get the length of collection ${queue_collection}. Found value is: ${no_to_add}. Using value 0 for the length."
                    no_to_add=0
                fi
                no_to_substract=0
                if [ -f ../../workflow/ligand-collections/ligand-lists/${queue_collection_tranch}/${queue_collection_ID}.status ]; then
                    no_to_substract=$(cat ../../workflow/ligand-collections/ligand-lists/${queue_collection_tranch}/${queue_collection_ID}.* | awk '{print $1}' | uniq | wc -l)
                else
                    echo -e " * Warning: Could not get the number of ligands to substract. Found value is: ${no_to_substract} \n * Using value 0 for the length."
                    no_to_substract=0
                fi
                ligands_todo[${queue_no_2}0000${queue_no_3}]=$((ligands_todo[${queue_no_2}0000${queue_no_3}] + ${no_to_add} - ${no_to_substract} ))
                queue_collection_numbers[${queue_no_2}0000${queue_no_3}]=$((queue_collection_numbers[${queue_no_2}0000${queue_no_3}] + 1 ))
            done
        fi
    done
done

# Printing some infos about the to-do lists of this queue before the refilling
if [[ ! "$*" = *"quiet"* ]]; then
    echo "Starting the (re)filling of the todolists of the queues."
    echo
    for queue_no_2 in $(seq 1 ${steps_per_job}); do
        # Loop for each queue of the node
        for queue_no_3 in $(seq 1 ${queues_per_step}); do
            queue_no="${queue_no_1}-${queue_no_2}-${queue_no_3}"
            echo "Before (re)filling the todolists the queue ${queue_no} had ${ligands_todo[${queue_no_2}0000${queue_no_3}]} ligands todo distributed in ${queue_collection_numbers[${queue_no_2}0000${queue_no_3}]} collections."
        done
    done
    echo
fi

# Loop for each refilling step
no_of_refilling_steps="$((${ligands_todo_per_queue} / ${ligands_per_refilling_step}))"
no_collections_remaining="$(grep -cv '^\s*$' ${todo_file_temp} || true)"
no_collections_assigned=0
no_collections_beginning=${no_collections_remaining}
for refill_step in $(seq 1 ${no_of_refilling_steps}); do
    step_limit=$((${refill_step} * ${ligands_per_refilling_step}))
    # Loop for each node
    for queue_no_2 in $(seq 1 ${steps_per_job}); do
        # Loop for each queue of the node
        for queue_no_3 in $(seq 1 ${queues_per_step}); do
            queue_no="${queue_no_1}-${queue_no_2}-${queue_no_3}"

            while [ "${ligands_todo[${queue_no_2}0000${queue_no_3}]}" -lt "${step_limit}" ]; do
                # Checking if there is one more ligand collection to be done
                if [ "${no_collections_remaining}" -eq "0" ]; then

                    # Checking if there is one more todo list
                    next_todo_list
                    no_collections_remaining="$(cat ${todo_file_temp} 2>/dev/null | grep -c "[^[:blank:]]" || true)"

                    # If no more new todo list, quitting
                    if [[ "${no_collections_remaining}" = "0" ]]; then
                        echo "There is no more ligand collection in the todo.all file. Stopping the refilling procedure."
                        break 4
                    fi
                fi

                # Setting some variables
                next_ligand_collection_and_length="$(head -n 1 ${todo_file_temp})"
                next_ligand_collection=${next_ligand_collection_and_length// *}
                echo "${next_ligand_collection_and_length}" >> ${todo_new_temp_basename}_${queue_no}
                no_to_add=${next_ligand_collection_and_length//* }
                if ! [ "${no_to_add}" -eq "${no_to_add}" ]; then
                    echo " * Warning: Could not get the length of collection ${next_ligand_collection}. Found value is: ${no_to_add}. Exiting."
                    exit 1
                fi
                ligands_todo[${queue_no_2}0000${queue_no_3}]=$(( ${ligands_todo[${queue_no_2}0000${queue_no_3}]} + ${no_to_add} ))
                queue_collection_numbers[${queue_no_2}0000${queue_no_3}]=$((queue_collection_numbers[${queue_no_2}0000${queue_no_3}] + 1 ))
                # Removing the new collection from the ligand-collections-to-do file
                tail -n +2 ${todo_file_temp} > ${todo_file_temp}.tmp || true
                mv ${todo_file_temp}.tmp ${todo_file_temp}
                # Updating the variable no_collections_remaining
                no_collections_remaining=$((no_collections_remaining-1))
                no_collections_assigned=$((no_collections_assigned+1))
            done
        done
    done
done

# Adding the new collections from the temporary to-do file to the permanent one of the queue
for queue_no_2 in $(seq 1 ${steps_per_job}); do
    for queue_no_3 in $(seq 1 ${queues_per_step}); do
        queue_no="${queue_no_1}-${queue_no_2}-${queue_no_3}"
        cat ${todo_new_temp_basename}_${queue_no} >> ../../workflow/ligand-collections/todo/${queue_no}
        rm ${todo_new_temp_basename}_${queue_no}
    done
done

# Printing some infos about the to-do lists of this queue after the refilling
if [[ ! "$*" = *"quiet"* ]]; then
    for queue_no_2 in $(seq 1 ${steps_per_job}); do
        # Loop for each queue of the node
        for queue_no_3 in $(seq 1 ${queues_per_step}); do
            queue_no="${queue_no_1}-${queue_no_2}-${queue_no_3}"
            echo "After (re)filling the todolists the queue ${queue_no} has ${ligands_todo[${queue_no_2}0000${queue_no_3}]} ligands todo distributed in ${queue_collection_numbers[${queue_no_2}0000${queue_no_3}]} collections."
        done
    done
fi

# Displaying some information
if [[ ! "$*" = *"quiet"* ]]; then
    end_time_seconds="$(date +%s)"
    echo
    echo "The todo lists for the queues were (re)filled in $((end_time_seconds-VF_START_TIME_SECONDS)) second(s) (waiting time not included)."
    echo "The waiting time was $((end_time_waiting-start_time_waiting)) second(s)."
    echo
fi
