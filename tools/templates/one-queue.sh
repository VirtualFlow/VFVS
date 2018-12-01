#!/bin/bash
# ---------------------------------------------------------------------------
#
# Description: Bash script for virtual screening of ligands with AutoDock Vina.
#
# ---------------------------------------------------------------------------

# Setting the verbosity level
if [[ "${VF_VERBOSITY_LOGFILES}" == "debug" ]]; then
    set -x
fi

# Setting the error sensitivity
if [[ "${VF_ERROR_SENSITIVITY}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.
fi

# TODO: Different input file format
# TODO: Test with storing logfile
# TODO: Change ligand-lists/todo /current ... to subfolders
# TODO: Add ligand info into each completed collection -> creating correct sums and faster
# TODO: Refill during runtime


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

    # Checking error response
    if [[ "${VF_ERROR_RESPONSE}" == "ignore" ]]; then

        # Printing some information
        echo -e "\n * Ignoring error. Trying to continue..."

    elif [[ "${VF_ERROR_RESPONSE}" == "next_job" ]]; then

        # Cleaning up
        clean_queue_files_tmp

        # Printing some information
        echo -e "\n * Trying to stop this queue and causing the jobline to fail..."

        # Exiting
        exit 0

    elif [[ "${VF_ERROR_RESPONSE}" == "fail" ]]; then

        # Cleaning up
        clean_queue_files_tmp

        # Printing some information
        echo -e "\n * Trying to stop this queue and causing the jobline to fail..."

        # Exiting
        exit 1
    fi
}
trap 'error_response_std $LINENO' ERR



# Error reponse docking
error_response_docking() {

    # Printing some information
    echo "An error occurred during the docking procedure (${docking_type_name})."
    echo "Skipping this ligand and continuing with next one."

    # Variables
    ligand_list_entry="docking:failed"

    # Updating the ligand list
    update_ligand_list_end "false"
    continue
}

# Error reponse docking program
error_response_docking_program() {

    # Printing some information
    echo "An error occurred during the docking procedure (${docking_type_name})."
    echo "An unsupported docking program ($1) has been specified."
    echo "Supported docking programs are: ${supported_docking_programs}"
    echo "Aborting the virtual screening procedure..."
    fail_reason="unsported docking program specified ($1)"

    # Updating the ligand list
    update_ligand_list_end "true"
    exit 1
}

# Time limit close
time_near_limit() {
    VF_LITTLE_TIME="true";
    end_queue 0
}
trap 'time_near_limit' 1 2 3 9 10 12 15

# Cleaning the queue folders
clean_queue_files_tmp() {
    cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/queue-${VF_QUEUE_NO}.* ../workflow/output-files/queues/
    sleep 1
    rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/
}
trap 'clean_queue_files_tmp' EXIT RETURN

# Writing the ID of the next ligand to the current ligand list
update_ligand_list_start() {

    # Variables
    ligand_start_time_ms=$(($(date +'%s * 1000 + %-N / 1000000')))
    ligand_list_entry=""

    # Updating the ligand-list file
    echo "${next_ligand} ${docking_type_index} ${docking_replica_index} processing" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status
}

update_ligand_list_end() {

    # Variables
    success="${1}" # true or false
    pipeline_part="${2}"
    ligand_total_time_ms="$(($(date +'%s * 1000 + %-N / 1000000') - ${ligand_start_time_ms}))"

    # Updating the ligand-list file
    perl -pi -e "s/${next_ligand} ${docking_type_index} ${docking_replica_index} processing.*/${next_ligand}  ${docking_type_index} ${docking_replica_index} ${ligand_list_entry} total-time:${ligand_total_time_ms}/g" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status

    # Printing some information
    echo
    if [ "${success}" == "true" ]; then
        echo "Ligand ${next_ligand} completed ($2) on $(date)."
    else
        echo "Ligand ${next_ligand} failed ($2) on on $(date)."
    fi
    echo "Total time for this ligand (${next_ligand}) in ms: ${ligand_total_time_ms}"
    echo

    # Variables
    ligand_list_entry=""
}

update_summary() {
    trap 'error_response_std $LINENO' ERR

    if [ ! -f ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt ]; then
        printf "Compound   average-score   maximum-score   number-of-dockings" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
        for k in $(seq 1 ${docking_replica_index_end}); do 
            printf "   score-replica-$k" >>  ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
        done
        printf "\n" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
    fi
    if [ "${docking_replica_index}" -eq "1" ]; then
        printf "${next_ligand} %3.1f %3.1f %5s %3.1f\n" "${score_value}" "${score_value}" "1" "${score_value}" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
    else
        scores_previous=$(grep ${next_ligand} ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt | tr -s " " | cut -d " " -f 5-)
        read -a scores_all <<< "${scores_previous} ${score_value}"
        
        # Computing the new average value
        score_average=$(echo "${scores_all[@]}" | tr -s " " "\n" | awk '{ sum += $1 } END { if (NR > 0) print sum / NR }')
        
        # Computing the new maximum value
        score_maximum=$(echo "${scores_all[@]}" | awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}')
        
        # Upating the line
        scores_all_expaned="${scores_all[@]}"
        perl -pi -e "s/${next_ligand}\b.*/${next_ligand} ${score_average} ${score_maximum} ${docking_replica_index} ${scores_all_expaned}/g" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
    fi
    column -t ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt.tmp
    mv ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt.tmp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
}

# Obtaining the next ligand collection.
next_ligand_collection() {
    trap 'error_response_std $LINENO' ERR
    needs_cleaning="false"

    # Checking if this jobline should be stopped now
    line=$(cat ${VF_CONTROLFILE} | grep "^stop_after_collection=")
    stop_after_collection=${line/"stop_after_collection="}
    if [ "${stop_after_collection}" = "true" ]; then
        echo
        echo "This job line was stopped by the stop_after_collection flag in the VF_CONTROLFILE ${VF_CONTROLFILE}."
        echo
        end_queue 0
    fi
    echo
    echo "A new collection has to be used if there is one."

    # Checking if there exists a todo file for this queue
    if [ ! -f ../workflow/ligand-collections/todo/${VF_QUEUE_NO} ]; then
        echo
        echo "This queue is stopped because there exists no todo file for this queue."
        echo
        end_queue 0
    fi

    # Loop for iterating through the remaining collections until we find one which is not already finished
    new_collection="false"
    while [ "${new_collection}" = "false" ]; do

       # Checking if there is one more ligand collection to be done
        no_collections_remaining="$(grep -cv '^\s*$' ../workflow/ligand-collections/todo/${VF_QUEUE_NO} || true)"
        if [[ "${no_collections_remaining}" = "0" ]]; then
            # Renaming the todo file to its original name
            no_more_ligand_collection
        fi

        # Setting some variables
        next_ligand_collection=$(head -n 1 ../workflow/ligand-collections/todo/${VF_QUEUE_NO} | awk '{print $1}')
        next_ligand_collection_ID="${next_ligand_collection/*_}"
        next_ligand_collection_tranch="${next_ligand_collection/_*}"
        next_ligand_collection_metatranch="${next_ligand_collection_tranch:0:2}"
        next_ligand_collection_length=$(head -n 1 ../workflow/ligand-collections/todo/${VF_QUEUE_NO} | awk '{print $2}')
        if grep -w "${next_ligand_collection}" ../workflow/ligand-collections/done/* &>/dev/null; then
            echo "This ligand collection was already finished. Skipping this ligand collection."
        elif grep -w "${next_ligand_collection}" ../workflow/ligand-collections/current/* &>/dev/null; then
            echo "On this ligand collection already another queue is working. Skipping this ligand collection."
        elif grep -w ${next_ligand_collection} $(ls ../workflow/ligand-collections/todo/* &>/dev/null | grep -v "${VF_QUEUE_NO}" &>/dev/null); then
            echo "This ligand collection is in one of the other todo-lists. Skipping this ligand collection."
        else
            new_collection="true"
        fi
        # Removing the new collection from the ligand-collections-todo file
        perl -ni -e "print unless /${next_ligand_collection}\b/" ../workflow/ligand-collections/todo/${VF_QUEUE_NO}
    done

    # Updating the ligand-collection files
    echo "${next_ligand_collection} ${next_ligand_collection_length}" > ../workflow/ligand-collections/current/${VF_QUEUE_NO}

    if [ "${VF_VERBOSITY_LOGFILES}" == "debug" ]; then
        echo -e "\n***************** INFO **********************"
        echo ${VF_QUEUE_NO}
        ls -lh ../workflow/ligand-collections/current/${VF_QUEUE_NO} 2>/dev/null || true
        cat ../workflow/ligand-collections/current/${VF_QUEUE_NO} 2>/dev/null || true
        cat ../workflow/ligand-collections/todo/${VF_QUEUE_NO} 2>/dev/null || true
        echo -e "***************** INFO END ******************\n"
    fi

    # Creating the subfolder in the ligand-lists folder
    mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists

    # Printing some information
    echo "The new ligand collection is ${next_ligand_collection}."
}

# Preparing the folders and files in ${VF_TMPDIR}
prepare_collection_files_tmp() {

    # Creating the required folders
    if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}" ]; then
        mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}
    elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}")" ]; then
        rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/*
    fi
    for docking_type_name in ${docking_type_names[@]}; do
        if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}" ]; then
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}
        elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/")" ]; then
            rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/*
        fi
        if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}" ]; then
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}
        elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/")" ]; then
            rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/*
        fi
        if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}" ]; then
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}
        elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/")" ]; then
            rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/*
        fi
    done
    if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/" ]; then
        mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/
    elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/")" ]; then
        rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/*
    fi

    # Extracting the required files
    if [ -f ${collection_folder}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}.tar ]; then
        tar -xf ${collection_folder}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/ ${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
        gunzip ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
    else
        # Raising an error
        echo " * Error: The tranch archive file ${collection_folder}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}.tar does not exist..."
        error_response_std $LINENO
    fi

    # Checking if the collection could be extracted
    if [ ! -f ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar ]; then

        # Raising an error
        echo " * Error: The ligand collection ${next_ligand_collection_tranch}_${next_ligand_collection_ID} could not be prepared."
        error_response_std $LINENO
    fi

    # Extracting all the PDBQT at the same time (faster than individual for each ligand separately)
    tar -xf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}

    # Copying the required old output files if continuing old collection
    for docking_type_name in ${docking_type_names[@]}; do
        if [ "${new_collection}" = "false" ]; then
            tar -xzf ../output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/ || true
            tar -xzf ../output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/ || true
            tar -xzf ../output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/ || true
        fi
    done
    if [[ -f  ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status ]]; then
        cp ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/
    fi

    # Cleaning up
    #rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar
    # If we remove it here, then we need to make the next_ligand determination dependend on the extracted archive rather than the archive. Are we using the extracted archive? I think so, for using the PDBQT
}

# Stopping this queue because there is no more ligand collection to be screened
no_more_ligand_collection() {

    # Printing some information
    echo
    echo "This queue is stopped because there is no more ligand collection."
    echo

    # Ending the queue
    end_queue 0
}

# Tidying up collection folders and files in ${VF_TMPDIR}
clean_collection_files_tmp() {

    # Checking if cleaning is needed at all
    if [ "${needs_cleaning}" = "true" ]; then
        local_ligand_collection=${1}
        local_ligand_collection_tranch="${local_ligand_collection/_*}"
        local_ligand_collection_metatranch="${local_ligand_collection_tranch:0:2}"
        local_ligand_collection_ID="${local_ligand_collection/*_}"

        # Checking if all the folders required are there
        if [ "${collection_complete}" = "true" ]; then

            # Printing some information
            echo -e "\n * The collection ${local_ligand_collection} has been completed."
            echo "    * Storing and cleaning corresponding files..."

            # Loop for each docking type
            for docking_type_name in ${docking_type_names[@]}; do

                # Results
                # Compressing the collection and saving in the complete folder
                mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
                tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

                # Adding the completed collection archive to the tranch archive
                mkdir  -p ../output-files/complete/${docking_type_name}/results/${local_ligand_collection_metatranch}
                tar -rf ../output-files/complete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/results/${local_ligand_collection_metatranch} ${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz || true

                # Cleaning up
                rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz &> /dev/null || true
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

                # Summaries
                # Compressing the collection and saving in the complete folder
                mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
                tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

                # Adding the completed collection archive to the tranch archive
                mkdir  -p ../output-files/complete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}
                tar -rf ../output-files/complete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/summaries/${local_ligand_collection_metatranch} ${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz || true

                # Cleaning up
                rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz &> /dev/null || true
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

                # Logfiles
                # Compressing the collection and saving in the complete folder
                mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
                tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

                # Adding the completed collection archive to the tranch archive
                mkdir  -p ../output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}
                tar -rf ../output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch} ${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz || true

                # Cleaning up
                rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz &> /dev/null || true
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

            done

            # Checking if we should keep the ligand log summary files
            if [ "${keep_ligand_summary_logs}" = "true" ]; then

                # Directory preparation
                mkdir  -p ../output-files/complete/ligand-lists/${local_ligand_collection_metatranch}
                gzip ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status
                tar -rf ../output-files/complete/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/ ${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status.gz || true
            fi

            # Updating the ligand collection files
            echo -n "" > ../workflow/ligand-collections/current/${VF_QUEUE_NO}
            ligands_succeeded_tautomerization="$(zgrep "tautomerization([0-9]\+):success" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status.gz | grep -c tautomerization)"
            ligands_succeeded_targetformat="$(zgrep -c "targetformat-generation([A-Za-z]\+):success" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status.gz)"
            ligands_failed="$(zgrep -c "failed total" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status.gz)"
            ligands_started="$(zgrep -c "initial" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status.gz)"
            echo "${local_ligand_collection} was completed by queue ${VF_QUEUE_NO} on $(date). Ligands started:${ligands_started} succeeded(tautomerization):${ligands_succeeded_tautomerization} succeeded(target-format):${ligands_succeeded_targetformat} failed:${ligands_failed}" >> ../workflow/ligand-collections/done/${VF_QUEUE_NO}

        else
            # Loop for each target format
            for docking_type_name in ${docking_type_names[@]}; do

                # Results
                # Compressing the collecion
                tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

                # Copying the files which should be kept in the permanent storage location
                mkdir -p ../output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
                cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz ../output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/

                # Cleaning up
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

                # Summaries
                # Compressing the collecion
                tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

                # Copying the files which should be kept in the permanent storage location
                mkdir -p ../output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
                cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz ../output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/

                # Cleaning up
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

                # Results
                # Compressing the collecion
                tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

                # Copying the files which should be kept in the permanent storage location
                mkdir -p ../output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
                cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz ../output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/

                # Cleaning up
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

            done

            mkdir -p ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/
            cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/ || true

        fi

        # Cleaning up
        rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true
        rm  ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar &> /dev/null || true
        rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status.* &> /dev/null || true
        rm ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status &> /dev/null || true

        # Cleaning up
        for targetformat in ${targetformats//:/ }; do
            rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${targetformat}/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true
        done

    fi
    needs_cleaning="false"
}

# Function for end of the queue
end_queue() {

    # Variables
    exitcode=${1}

    # Checking if cleaning up is needed
    if [[ "${ligand_index}" -gt "1" && "${new_collection}" == "false" ]] ; then
        clean_collection_files_tmp ${next_ligand_collection}
    fi

    # Cleaning up the queue files
    clean_queue_files_tmp

    #  Exiting
    exit ${exitcode}
}


# Verbosity
if [ "${VF_VERBOSITY_LOGFILES}" = "debug" ]; then
    set -x
fi

# Variables
targetformats="$(grep -m 1 "^targetformats=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
minimum_time_remaining="$(grep -m 1 "^minimum_time_remaining=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
keep_ligand_summary_logs="$(grep -m 1 "^keep_ligand_summary_logs=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ligand_check_interval="$(grep -m 1 "^ligand_check_interval=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cpus_per_queue="$(grep -m 1 "^cpus_per_queue=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Docking
supported_docking_programs="vina, qvina02, qvina_w, smina, adfr"
needs_cleaning="false"

# Determining the names of each docking type
docking_type_names="$(grep -m 1 "^docking_type_names=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_type_names <<< "$docking_type_names"

# Determining the number of docking types
docking_type_index_end=${#docking_type_names[@]}

# Determining the docking programs to use for each docking type
docking_type_programs="$(grep -m 1 "^docking_type_programs=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_type_programs <<< "$docking_type_programs"
docking_type_programs_length=${#docking_type_programs[@]}

# Determining the docking type replicas
docking_type_replicas_total="$(grep -m 1 "^docking_type_replicas_total=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_type_replicas_total <<< "$docking_type_replicas_total"
docking_type_replicas_total_length=${#docking_type_replicas_total[@]}

# Determining the docking type input folders
docking_type_inputfolders="$(grep -m 1 "^docking_type_inputfolders=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_type_inputfolders <<< "$docking_type_inputfolders"
docking_type_inputfolders_length=${#docking_type_inputfolders[@]}

# Getting the value for the variable minimum_time_remaining
minimum_time_remaining="$(grep -m 1 "^minimum_time_remaining=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
minimum_time_remaining=$((minimum_time_remaining * 60)) # Conversion from minutes to seconds

# Checking the variables for errors
if ! [ "${docking_type_index_end}" -eq "${docking_type_programs_length}" ]; then
    echo "ERROR:" 
    echo " * Some variables specified in the controlfile ${VF_CONTROLFILE} are not compatible."
    echo " * The variable docking_type_names has ${docking_type_index_end} entries."
    echo " * The variable docking_type_programs has ${docking_type_programs_length} entries."
    exit 1
elif ! [ "${docking_type_index_end}" -eq "${docking_type_replicas_total_length}" ]; then
    echo "ERROR:" 
    echo " * Some variables specified in the controlfile ${VF_CONTROLFILE} are not compatible."
    echo " * The variable docking_type_names has ${docking_type_index_end} entries."
    echo " * The variable docking_type_replicas has ${docking_type_replicas_total_length} entries."
    exit 1
elif ! [ "${docking_type_index_end}" -eq "${docking_type_inputfolders_length}" ]; then
    echo "ERROR:" 
    echo " * Some variables specified in the controlfile ${VF_CONTROLFILE} are not compatible."
    echo " * The variable docking_type_names has ${docking_type_index_end} entries."
    echo " * The variable docking_type_inputfolders has ${docking_type_inputfolders_length} entries."
    exit 1
fi

# Saving some information about the VF_CONTROLFILE
echo
echo
echo "*****************************************************************************************"
echo "              Beginning of a new job (job ${VF_OLD_JOB_NO}) in queue ${VF_QUEUE_NO}"
echo "*****************************************************************************************"
echo
echo "Control files in use"
echo "-------------------------"
echo "Controlfile = ${VF_CONTROLFILE}"
echo
echo "Contents of the VF_CONTROLFILE ${VF_CONTROLFILE}"
echo "-----------------------------------------------"
cat ${VF_CONTROLFILE}
echo
echo

# Getting the folder where the colections are
collection_folder="$(grep -m 1 "^collection_folder=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Loop for each ligand
ligand_index=0
docking_index=0
while true; do

    # Variables
    new_collection="false"
    collection_complete="false"
    ligand_index=$((ligand_index+1))
    docking_type_index_start=1          # Will be overwritten if neccessary (if continuing collection in the middle of a ligand)
    docking_replica_index_start=1       # Will be overwritten if neccessary (if continuing collection in the middle of a ligand)

    # Preparing the next ligand
    # Checking the conditions for using a new collection
    if [[ "${ligand_index}" == "1" ]]; then

        # Checking if there is no current ligand collection
        if [[ ! -s ../workflow/ligand-collections/current/${VF_QUEUE_NO} ]]; then

            # Preparing a new collection
            next_ligand_collection
            prepare_collection_files_tmp

            # Getting the name of the first ligand of the first collection
            next_ligand=$(tar -tf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar | head -n 2 | tail -n 1 | awk -F '[/.]' '{print $2}')


        # Using the old collection
        else
            # Getting the name of the current ligand collection
            next_ligand_collection=$(awk '{print $1}' ../workflow/ligand-collections/current/${VF_QUEUE_NO})
            next_ligand_collection_ID="${next_ligand_collection/*_}"
            next_ligand_collection_tranch="${next_ligand_collection/_*}"
            next_ligand_collection_metatranch="${next_ligand_collection_tranch:0:2}"

            # Extracting the last ligand collection
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}
            tar -xf ${collection_folder}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/ ${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
            gunzip ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
            # Extracting all the PDBQT at the same time (faster)
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}
            tar -xf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/

            # Copying the ligand-lists status file if it exists
            if [[ -f  ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status ]]; then
                cp ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/

                # Variables
                last_ligand_entry=$(tail -n 1 ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status 2>/dev/null || true)
                last_ligand=$(echo ${last_ligand_entry} | awk -F ' ' '{print $1}')
                last_ligand_status=$(echo ${last_ligand_entry} | awk -F ' ' '{print $4}')
                docking_type_index_start=$(echo ${last_ligand_entry} | awk -F ' ' '{print $2}')
                docking_replica_index_start=$(echo ${last_ligand_entry} | awk -F ' ' '{print $3}')

                # Checking if the last ligand was in the status processing. In this case we will try to process the ligand again since the last process might have not have the chance to complete its tasks.
                if [ "${last_ligand_status}" == "processing" ]; then
                    perl -ni -e "/${last_ligand}:processing/d" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status # Might not work for VFVS due to multiple replicas
                    next_ligand="${last_ligand}"

                else

                    # Incrementing the indices (replica, type)
                    docking_replica_index_end=${docking_type_replicas_total[(($docking_type_index_start - 1))]}
                    if [ "${docking_replica_index_start}" -lt "${docking_replica_index_end}" ]; then
                        # Incrementing the replica index
                        docking_replica_index_start=$((docking_replica_index_start + 1))
                        next_ligand=${last_ligand}
                    elif [ "${docking_type_index_start}" -lt "${docking_type_index_end}" ]; then
                        # Incrementing the replica index
                        docking_type_index_start=$((docking_type_index_start + 1))
                        docking_replica_index_start=1
                        next_ligand=${last_ligand}
                    else
                        # Need to use new ligand
                        docking_replica_index_start=1
                        docking_type_index_start=1
                        next_ligand=$(tar -tf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar | grep -w -A 1 "${last_ligand}" | grep -v ${last_ligand} | awk -F '[/.]' '{print $2}')
                    fi
                fi

            else
                # Restarting the collection
                next_ligand=$(tar -tf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar | head -n 2 | tail -n 1 | awk -F '[/.]' '{print $2}')
            fi
        fi

    # Using the old collection
    else

        # Not first ligand of this queue
        last_ligand=$(tail -n 1 ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status 2>/dev/null | awk -F '[:. ]' '{print $1}' || true)
        next_ligand=$(tar -tf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar | grep -w -A 1 "${last_ligand}" | grep -v ${last_ligand} | awk -F '[/.]' '{print $2}')
    fi

    # Checking if we can use the collection determined so far
    if [ -n "${next_ligand}" ]; then

        # Preparing the collection folders if this is the first ligand of this queue
        if [[ "${ligand_index}" == "1" ]]; then
            prepare_collection_files_tmp
        fi

    # Otherwise we have to use a new ligand collection
    else
        collection_complete="true"
        # Cleaning up the files and folders of the old collection
        if [ ! "${ligand_index}" = "1" ]; then
            clean_collection_files_tmp ${next_ligand_collection}
        fi
        # Getting the next collection if there is one more
        next_ligand_collection
        prepare_collection_files_tmp
        # Getting the first ligand of the new collection
        next_ligand=$(tar -tf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/collections/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar | head -n 2 | tail -n 1 | awk -F '[/.]' '{print $2}')
        docking_type_index_start=1
        docking_replica_index_start=1
    fi

    # Displaying the heading for the new ligand
    echo ""
    echo "      Ligand ${ligand_index} of job ${VF_OLD_JOB_NO} belonging to collection ${next_ligand_collection}: ${next_ligand}"
    echo "*****************************************************************************************"

    # Setting up variables
    # Checking if the current ligand index divides by ligand_check_interval
    if [ "$((ligand_index % ligand_check_interval))" == "0" ]; then
        # Determining the VF_CONTROLFILE to use for this jobline
        VF_CONTROLFILE=""
        for file in $(ls ../workflow/control/*-* 2>/dev/null|| true); do
            file_basename=$(basename $file)
            jobline_range=${file_basename/.*}
            jobline_no_start=${jobline_range/-*}
            jobline_no_end=${jobline_range/*-}
            if [[ "${jobline_no_start}" -le "${VF_JOBLINE_NO}" && "${VF_JOBLINE_NO}" -le "${jobline_no_end}" ]]; then
                export VF_CONTROLFILE="${file}"
                break
            fi
        done
        if [ -z "${VF_CONTROLFILE}" ]; then
            VF_CONTROLFILE="../workflow/control/all.ctrl"
        fi

        # Checking if this queue line should be stopped immediately
        line=$(cat ${VF_CONTROLFILE} | grep "^stop_after_next_check_interval=")
        stop_after_next_check_interval=${line/"stop_after_next_check_interval="}
        if [ "${stop_after_next_check_interval}" = "true" ]; then
            echo
            echo " * This queue will be stopped due to the stop_after_next_check_interval flag in the VF_CONTROLFILE ${VF_CONTROLFILE}."
            echo
            end_queue 0
        fi
    fi

    # Checking if there is enough time left for a new ligand
    if [[ "${VF_LITTLE_TIME}" = "true" ]]; then
        echo
        echo " * This queue will be ended because a signal was caught indicating this queue should stop now."
        echo
        end_queue 0
    fi

    if [[ "$((VF_TIMELIMIT_SECONDS - $(date +%s ) + VF_START_TIME_SECONDS )) " -lt "${minimum_time_remaining}" ]]; then
        echo
        echo " * This queue will be ended because there is less than the minimum time remaining (${minimum_time_remaining} s) for the job (by internal calculation)."
        echo
        end_queue 0
    fi

    # Updating the ligand-list files
    update_ligand_list_start
    
    # Adjusting the ligand-list file
    ligand_list_entry="${ligand_list_entry} entry-type:initial"
    
    # Loop for each docking type
    for docking_type_index in $(seq ${docking_type_index_start} ${docking_type_index_end}); do

        # Variables
        docking_type_name=${docking_type_names[(($docking_type_index - 1))]}
        docking_type_program=${docking_type_programs[(($docking_type_index - 1))]}
        docking_type_inputfolder=${docking_type_inputfolders[(($docking_type_index - 1))]}
        docking_replica_index_end=${docking_type_replicas_total[(($docking_type_index - 1))]}

        # Loop for each replica for the current docking type
        for docking_replica_index in $(seq ${docking_replica_index_start} ${docking_replica_index_end}); do

            # Setting up variables
            docking_replica_index_start=1 # Need to reset it in case a new job was started before and set the variable to a value greater than 1
            start_time_ms=$(($(date +'%s * 1000 + %-N / 1000000')))
            fail_reason=""

            # Checking if there is enough time left for a new ligand
            if [[ "${VF_LITTLE_TIME}" = "true" ]]; then
                echo
                echo "This queue was ended because a signal was caught indicating this queue should stop now."
                echo
                end_queue 0
            fi
            echo $VF_START_TIME_SECONDS
            echo $(date +%s)
            echo $VF_TIMELIMIT_SECONDS
            if [[ "$((VF_TIMELIMIT_SECONDS - $(date +%s ) + VF_START_TIME_SECONDS )) " -lt "${minimum_time_remaining}" ]]; then
                echo
                echo "This queue was ended because there were less than the minimum time remaining (${minimum_time_remaining} s) for the job (by internal calculation)."
                echo
                end_queue 0
            fi

            # Updating the ligand-list files
            update_ligand_list_start

            # Displaying the heading for the new iteration
            echo
            echo "   ***   Starting new docking run: docking type ${docking_type_index}/${docking_type_index_end} (${docking_type_name}), replica ${docking_replica_index}/${docking_replica_index_end}   ***   "
            echo

            # Checking if ligand contains B, Si, Sn
            if grep -q " B " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt; then
                error_response_ligand_elements "B"
            elif grep -i -q " Si " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt; then
                error_response_ligand_elements "Si"
            elif grep -i -q " Sn " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt; then
                error_response_ligand_elements "Sn"
            fi

            # Running the docking program
            trap 'error_response_docking' ERR
            case $docking_type_program in
                qvina02)
                    
                    bin/time_bin -a -o "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/queue-${VF_QUEUE_NO}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/qvina02 --cpu ${cpus_per_queue} --config ${docking_type_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.pdbqt > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
                qvina_w)
                    bin/time_bin -a -o "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/queue-${VF_QUEUE_NO}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/qvina_w --cpu ${cpus_per_queue} --config ${docking_type_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.pdbqt > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
                vina)
                    bin/time_bin -a -o "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/queue-${VF_QUEUE_NO}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/vina --cpu ${cpus_per_queue} --config ${docking_type_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.pdbqt > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
                smina*)
                    bin/time_bin -a -o "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/queue-${VF_QUEUE_NO}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/smina --cpu ${cpus_per_queue} --config ${docking_type_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.pdbqt --out_flex ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.flexres.pdb --log ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} --atom_terms ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.atomterms
                    score_value=$(tac ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | grep -m 1 "^1    " | awk '{print $2}')
                    ;;
                adfr)
                    adfr_configfile_options=$(cat ${docking_type_inputfolder}/config.txt | tr -d "\n")
                    bin/time_bin -a -o "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/output-files/queues/queue-${VF_QUEUE_NO}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/adfr -l ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/pdbqt/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdbqt --jobName adfr ${adfr_configfile_options}
                    rename "_adfr_adfr.out" "" ${next_ligand}_replica-${docking_replica_index} ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}*
                    score_value=$(grep -m 1 "FEB" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.pdbqt | awk -F ': ' '{print $(NF)}')
                    ;;
                *)
                    error_response_docking_program $docking_type_program
            esac
            trap 'error_response_std $LINENO' ERR


            # Updating the summary
            update_summary

            # Updating the ligand list
            update_ligand_list_end "true"

            # Variables
            needs_cleaning="true"
        done
    done
done