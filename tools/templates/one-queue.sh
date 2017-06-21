#!/bin/bash
# ---------------------------------------------------------------------------
#
# Description: Bash script for virtual screening of ligands with AutoDock Vina.
#
# Revision history:
# 2015-12-28  Import of file from JANINA version 2.2 and adaption to STELLAR version 6.1
# 2016-07-16  Various improvements
# 2016-07-26  Changing the name of the result files from all.result to all.result.pdbqt
#
# ---------------------------------------------------------------------------

# Setting the verbosity level
if [[ "${verbosity}" == "debug" ]]; then
    set -x
fi

# Setting the error sensitivity 
if [[ "${error_sensitivity}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.         
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
        echo -e "\n * Trying to stop this queue without stopping the joblfine/causing a failure..."
        exit 0
    elif [[ "${error_response}" == "fail" ]]; then
        exit 1
    fi
}
trap 'error_response_std $LINENO' ERR

# Time limit close
time_near_limit() {
    little_time="true";
    end_queue 0
}
trap 'time_near_limit' 1 2 3 9 10 12 15

# Functions
# Error reponse ligand elements
error_response_ligand_elements() {
    element=$1
    echo "The ligand contains elements (${element}) which cannot be handled by quickvina."
    echo "Skipping this ligand and continuing with next one."
    fail_reason="ligand elements"
    update_ligand_list_end_fail
    continue
}

# Error reponse docking
error_response_docking() {
    echo "An error occured during the docking procedure (${docking_type_name})."
    echo "Skipping this ligand and continuing with next one."
    fail_reason="docking"
    update_ligand_list_end_fail
    continue
}

# Error reponse docking program
error_response_docking_program() {
    echo "An error occured during the docking procedure (${docking_type_name})."
    echo "An unsupported docking program ($1) has been specified." 
    echo "Supported docking programs are: ${supported_docking_programs}"
    echo "Aborting the virtual screening procedure..."
    fail_reason="unsported docking program specified ($1)"
    update_ligand_list_end_fail
    exit 1
}

# Writing the ID of the next ligand to the current ligand list
update_ligand_list_start() {
    echo "${next_ligand} ${docking_type_index} ${docking_replica_index} processing" >> ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status.tmp
}

# Updating the current ligand list
update_ligand_list_end_fail() {
    trap 'error_response_std $LINENO' ERR

    # Updating the ligand-list file
    perl -pi -e "s/${next_ligand} ${docking_type_index} ${docking_replica_index} processing/${next_ligand} ${docking_type_index} ${docking_replica_index} failed (${fail_reason})/g" ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status.tmp
    
    # Printing some information
    echo "Ligand ${next_ligand} failed on on $(date)."
    echo "Total time for this ligand in ms: $(($(date +'%s * 1000 + %-N / 1000000') - ${start_time_ms}))"
    echo
}

# Updating the current ligand list
update_ligand_list_end_success() {
    trap 'error_response_std $LINENO' ERR

    # Updating the ligand-list file
    perl -pi -e "s/${next_ligand} ${docking_type_index} ${docking_replica_index} processing/${next_ligand} ${docking_type_index} ${docking_replica_index} successs /g" ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status.tmp
    # Printing some information
    echo
    echo "The docking run for ligand ${next_ligand} was completed successfully on $(date)."
    echo "Total time for this docking run was in ms: $(($(date +'%s * 1000 + %-N / 1000000') - ${start_time_ms}))"
    echo
}

update_summary() {
    trap 'error_response_std $LINENO' ERR

    if [ ! -f /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt ]; then
        printf "Compound   average-score   maximum-score   number-of-dockings" >> /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt
        for k in $(seq 1 ${docking_replica_index_end}); do 
            printf "   score-replica-$k" >>  /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt
        done
        printf "\n" >> /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt
    fi
    if [ "${docking_replica_index}" -eq "1" ]; then
        printf "${next_ligand} %3.1f %3.1f %5s %3.1f\n" "${score_value}" "${score_value}" "1" "${score_value}" >> /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt
    else
        scores_previous=$(grep ${next_ligand} /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt | tr -s " " | cut -d " " -f 5-)
        read -a scores_all <<< "${scores_previous} ${score_value}"
        
        # Computing the new average value
        score_average=$(echo "${scores_all[@]}" | tr -s " " "\n" | awk '{ sum += $1 } END { if (NR > 0) print sum / NR }')
        
        # Computing the new maximum value
        score_maximum=$(echo "${scores_all[@]}" | awk '{m=$1;for(i=1;i<=NF;i++)if($i>m)m=$i;print m}')
        
        # Upating the line
        scores_all_expaned="${scores_all[@]}"
        perl -pi -e "s/${next_ligand}.*/${next_ligand} ${score_average} ${score_maximum} ${docking_replica_index} ${scores_all_expaned}/g" /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt
    fi
    column -t /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt > /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt.tmp
    mv /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt.tmp /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt
}

# Obtaining the next ligand collection.
next_ligand_collection() {
    trap 'error_response_std $LINENO' ERR
    needs_cleaning=false
    
    # Checking if this jobline should be stopped now
    line=$(cat ${controlfile} | grep "^stop_after_collection=")
    stop_after_collection=${line/"stop_after_collection="}
    if [ "${stop_after_collection}" = "yes" ]; then   
        echo
        echo "This job line was stopped by the stop_after_collection flag in the controlfile ${controlfile}."
        echo
        end_queue 0
    fi
    echo
    echo "A new collection has to be used if there is one."
    
    # Checking if there exists a todo file for this queue
    if [ ! -f ../workflow/ligand-collections/todo/${queue_no} ]; then
        echo
        echo "This queue is stopped because there exists no todo file for this queue."
        echo
        end_queue 0
    fi
    
    # Loop for iterating through the remaining collections until we find one which is not already finished
    new_collection="false"
    while [ "${new_collection}" = "false" ]; do
    
       # Checking if there is one more ligand collection to be done
        no_collections_remaining="$(grep -cv '^\s*$' ../workflow/ligand-collections/todo/${queue_no} || true)" 
        if [[ "${no_collections_remaining}" = "0" ]]; then
            # Renaming the todo file to its original name
            no_more_ligand_collection
        fi
    
        # Setting some variables
        next_ligand_collection=$(head -n 1 ../workflow/ligand-collections/todo/${queue_no})
        next_ligand_collection_basename=${next_ligand_collection/.*}
        next_ligand_collection_sub2_basename="${next_ligand_collection_basename/*_}"
        next_ligand_collection_sub2="${next_ligand_collection/*_}"
        next_ligand_collection_sub1="${next_ligand_collection/_*}"
        if grep "${next_ligand_collection}" ../workflow/ligand-collections/done/* &>/dev/null; then
            echo "This ligand collection was already finished. Skipping this ligand collection."
        elif grep "${next_ligand_collection}" ../workflow/ligand-collections/current/* &>/dev/null; then
            echo "On this ligand collection already another queue is working. Skipping this ligand collection."
        elif grep ${next_ligand_collection} $(ls ../workflow/ligand-collections/todo/* | grep -v "${queue_no}" &>/dev/null); then
            echo "This ligand collection is in one of the other todo-lists. Skipping this ligand collection."
        else 
            new_collection="true"
        fi
        # Removing the new collection from the ligand-collections-todo file
        perl -ni -e "print unless /${next_ligand_collection}/" ../workflow/ligand-collections/todo/${queue_no}
    done   
                
    # Updating the ligand-collection files       
    echo "${next_ligand_collection}" > ../workflow/ligand-collections/current/${queue_no}
    
    if [ "${verbosity}" == "debug" ]; then 
        echo -e "\n***************** INFO **********************" 
        echo ${queue_no}
        ls -lh ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
        cat ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
        cat ../workflow/ligand-collections/todo/${queue_no} 2>/dev/null || true
        echo -e "***************** INFO END ******************\n"
    fi

# Creating the subfolder in the ligand-lists folder
    mkdir -p ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/
    
    # Printing some information
    echo "The new ligand collection is ${next_ligand_collection}."
}

# Preparing the folders and files in /tmp
prepare_collection_files_tmp() {
    trap 'error_response_std $LINENO' ERR

    # Creating the required folders
    if [ ! -d "/tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections" ]; then
        mkdir -p /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections
    elif [ "$(ls -A "/tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/")" ]; then
        rm -r /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/*
    fi
    if [ ! -d "/tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual" ]; then
        mkdir -p /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual
    elif [ "$(ls -A "/tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/")" ]; then
        rm -r /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/*
    fi
    for docking_type_name in ${docking_type_names[@]}; do
        if [ ! -d "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}" ]; then
            mkdir -p /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}
        elif [ "$(ls -A "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/")" ]; then
            rm -r /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/*
        fi
        if [ ! -d "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}" ]; then
            mkdir -p /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}
        elif [ "$(ls -A "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/")" ]; then
            rm -r /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/*
        fi
        if [ ! -d "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/" ]; then
            mkdir -p /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/
        elif [ "$(ls -A "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/")" ]; then
            rm -r /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/*
        fi
        if [ ! -d "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/other/" ]; then
            mkdir -p /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/other/
        elif [ "$(ls -A "/tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/other/")" ]; then
            rm -r /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/other/*
        fi
    done
        
    # Extracting the required files
    # 2015: tar -xf ${collection_folder}/${next_ligand_collection_sub1}.tar -C /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/ ${next_ligand_collection_sub1}/${next_ligand_collection_sub2}
    # 2016 Version has different tar archive structure... (not in subfolder)
    mkdir -p /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${next_ligand_collection_sub1}/
    tar -xf ${collection_folder}/${next_ligand_collection_sub1}.tar -C /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${next_ligand_collection_sub1}/ ${next_ligand_collection_sub2}

    # Copying the required old output files if continuing old collection
    for docking_type_name in ${docking_type_names[@]}; do
        if [ "${new_collection}" = "false" ]; then
            if [[ -f "../output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/all.tar" ]]; then
                cp ../output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/all.tar /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/
            fi
            if [[ -f "../output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/all.tar" ]]; then
                cp ../output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/all.tar /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/
            fi
            if [[ -f "../output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt" ]]; then
                cp ../output-files/incomplete/${docking_type_name}/summaries/first-poses/${next_ligand_collection_basename}.txt /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/
            fi
        fi
        if [[ -f  ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status ]]; then
            mv ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status.tmp
        fi
    done
}

# Stopping this queue because there is no more ligand collection to be screened
no_more_ligand_collection() {
    echo
    echo "This queue is stopped because there is no more ligand collection."
    echo
    end_queue 0
}

# Tidying up collection folders and files in /tmp
clean_collection_files_tmp() {
    trap 'error_response_std $LINENO' ERR
    if [ ${needs_cleaning} = "true" ]; then
        local_ligand_collection=${1}
        local_ligand_collection_basename=${local_ligand_collection/.*}
        local_ligand_collection_sub1="${local_ligand_collection_basename/_*}"
        local_ligand_collection_sub2="${local_ligand_collection/*_}"
        local_ligand_collection_sub2_basename="${local_ligand_collection_basename/*_}"

        for docking_type_name in ${docking_type_names[@]}; do
            if [ "${collection_complete}" = "true" ]; then
                # Checking if all the folders required are there
                if [ ! -d "../output-files/complete/${docking_type_name}/results/" ]; then
                    mkdir  -p ../output-files/complete/${docking_type_name}/results/
                fi
                if [ ! -d "../output-files/complete/${docking_type_name}/logfiles/" ]; then
                    mkdir -p ../output-files/complete/${docking_type_name}/logfiles/
                fi
                if [ ! -d "../output-files/complete/${docking_type_name}/summaries/first-poses/" ]; then
                    mkdir -p ../output-files/complete/${docking_type_name}/summaries/first-poses/
                fi
                # Copying the files which should be kept in the permanent storage location
                mkdir -p /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/results/${local_ligand_collection_sub1}
                cp /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_basename}/all.tar /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/results/${local_ligand_collection_sub1}/${local_ligand_collection_sub2_basename}.gz.tar
                tar -rf ../output-files/complete/${docking_type_name}/results/${local_ligand_collection_sub1}.tar -C /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/results ${local_ligand_collection_sub1}/${local_ligand_collection_sub2_basename}.gz.tar || true

                mkdir -p /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_sub1}
                cp /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_basename}/all.tar /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_sub1}/${local_ligand_collection_sub2_basename}.gz.tar
                tar -rf ../output-files/complete/${docking_type_name}/logfiles/${local_ligand_collection_sub1}.tar -C /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/logfiles/ ${local_ligand_collection_sub1}/${local_ligand_collection_sub2_basename}.gz.tar || true

                mkdir -p /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/summaries/first-poses/${local_ligand_collection_sub1}
                cp /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${local_ligand_collection_basename}.txt /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/summaries/first-poses/${local_ligand_collection_sub1}/${local_ligand_collection_sub2_basename}.txt
                gzip -f /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/summaries/first-poses/${local_ligand_collection_sub1}/${local_ligand_collection_sub2_basename}.txt || true
                tar -rf ../output-files/complete/${docking_type_name}/summaries/first-poses/${local_ligand_collection_sub1}.tar -C /tmp/${USER}/${queue_no}/output-files/complete/${docking_type_name}/summaries/first-poses/ ${local_ligand_collection_sub1}/${local_ligand_collection_sub2_basename}.txt.gz || true

                # Cleaning up
                rm -r ../output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_basename} &>/dev/null || true
                rm -r ../output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_basename} &>/dev/null || true
                rm -r ../output-files/incomplete/${docking_type_name}/summaries/first-poses/${local_ligand_collection_basename}* &>/dev/null || true
            else
                # Checking if all the folders required are there
                if [ ! -d "../output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_basename}/" ]; then
                    mkdir  -p ../output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_basename}/
                fi
                if [ ! -d "../output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_basename}/" ]; then
                    mkdir -p ../output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_basename}/
                fi
                if [ ! -d "../output-files/incomplete/${docking_type_name}/summaries/first-poses/" ]; then
                    mkdir -p ../output-files/incomplete/${docking_type_name}/summaries/first-poses/
                fi

                # Copying the files which should be kept in the permanent storage location
                cp /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_basename}/all.tar ../output-files/incomplete/${docking_type_name}/results/${local_ligand_collection_basename}/
                cp /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_basename}/all.tar ../output-files/incomplete/${docking_type_name}/logfiles/${local_ligand_collection_basename}/
                cp /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/summaries/first-poses/${local_ligand_collection_basename}.txt ../output-files/incomplete/${docking_type_name}/summaries/first-poses/
            fi
        done

        # Moving the ligand list status tmp file
        if [ -f ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status.tmp ]; then
            mv ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status.tmp ../workflow/ligand-collections/ligand-lists/${next_ligand_collection_sub1}/${next_ligand_collection_sub2_basename}.status
        fi
    fi
    needs_cleaning=false
}

# Cleaning the queue folders
clean_queue_files_tmp() {
    cp /tmp/${USER}/${queue_no}/workflow/output-files/queues/queue-${queue_no}.* ../workflow/output-files/queues/ || true
    rm -r /tmp/${USER}/${queue_no}/ || true
}
trap 'clean_queue_files_tmp' EXIT RETURN

# Function for end of the queue
end_queue() {
    if [[ "${ligand_index}" -gt "1" && "${new_collection}" == "false" ]] || [[ "${docking_counter_currentjob}" -gt "0" ]]; then
        clean_collection_files_tmp ${next_ligand_collection}
    fi
   
    clean_queue_files_tmp
    exit ${1}
}


# Saving some information about the controlfiles
echo
echo
echo "*****************************************************************************************"
echo "              Beginning of a new job (job ${old_job_no}) in queue ${queue_no}"
echo "*****************************************************************************************"
echo 
echo "Control files in use"
echo "-------------------------"
echo "controlfile = ${controlfile}"
echo
echo "Contents of the controlfile ${controlfile}"
echo "-----------------------------------------------"
cat ${controlfile}
echo
echo


# Variables
supported_docking_programs="vina, qvina02, smina, adfr"
needs_cleaning=false

# Setting the number of ligands to screen in this job
line=$(cat ${controlfile} | grep "^ligands_per_queue=")
no_of_ligands=${line/"ligands_per_queue="}
verbosity="false"

# Getting the folder where the collections are
line=$(cat ${controlfile} | grep "^collection_folder=" | sed 's/\/$//g')
collection_folder=${line/"collection_folder="}

# Determining the names of each docking type
line=$(cat ${controlfile} | grep "^docking_type_names=")
docking_type_names=${line/"docking_type_names="}
IFS=':' read -a docking_type_names <<< "$docking_type_names"
docking_type_names_length=${#docking_type_names[@]}

# Determining the number of docking types
docking_type_index_end=${#docking_type_names[@]}

# Determining the docking programs to use for each docking type
line=$(cat ${controlfile} | grep "^docking_type_programs=")
docking_type_programs=${line/"docking_type_programs="}
IFS=':' read -a docking_type_programs <<< "$docking_type_programs"
docking_type_programs_length=${#docking_type_programs[@]}

# Determining the docking type replicas
line=$(cat ${controlfile} | grep "^docking_type_replicas=")
docking_type_replicas_total=${line/"docking_type_replicas="}
IFS=':' read -a docking_type_replicas_total <<< "$docking_type_replicas_total"
docking_type_replicas_total_length=${#docking_type_replicas_total[@]}

# Determining the docking type input folders
line=$(cat ${controlfile} | grep "^docking_type_inputfolders=")
docking_type_inputfolders=${line/"docking_type_inputfolders="}
IFS=':' read -a docking_type_inputfolders <<< "$docking_type_inputfolders"
docking_type_inputfolders_length=${#docking_type_inputfolders[@]}

# Getting the value for the variable minimum_time_remaining
line=$(cat ${controlfile} | grep "^minimum_time_remaining=" | sed 's/\/$//g')
minimum_time_remaining=$((${line/"minimum_time_remaining="} * 60)) # Conversion from minutes to seconds

# Checking the variables for errors
if ! [ "${docking_type_names_length}" -eq "${docking_type_programs_length}" ]; then
    echo "ERROR:" 
    echo " * Some variables specified in the controlfile ${controlfile} are not compatible."
    echo " * The variable docking_type_names has ${docking_type_names_length} entries."
    echo " * The variable docking_type_programs has ${docking_type_programs_length} entries."
    exit 1
elif ! [ "${docking_type_names_length}" -eq "${docking_type_replicas_total_length}" ]; then
    echo "ERROR:" 
    echo " * Some variables specified in the controlfile ${controlfile} are not compatible."
    echo " * The variable docking_type_names has ${docking_type_names_length} entries."
    echo " * The variable docking_type_replicas has ${docking_type_replicas_total_length} entries."
    exit 1
elif ! [ "${docking_type_names_length}" -eq "${docking_type_inputfolders_length}" ]; then
    echo "ERROR:" 
    echo " * Some variables specified in the controlfile ${controlfile} are not compatible."
    echo " * The variable docking_type_names has ${docking_type_names_length} entries."
    echo " * The variable docking_type_inputfolders has ${docking_type_inputfolders_length} entries."
    exit 1
fi


# Loop for each ligand
for ligand_index in $(seq 1 ${no_of_ligands}); do
    
    # Variables
    new_collection="false"
    collection_complete="false"  
    docking_type_index_start=1          # Will be overwritten if neccessary (if continuing collection in the middle of a ligand)
    docking_replica_index_start=1       # Will be overwritten if neccessary (if continuing collection in the middle of a ligand)      
    docking_counter_currentjob=0

    # Preparing the next ligand    
    # Checking if this is the first ligand at all (beginning of first ligand collection)
    if [[ ! -f  "../workflow/ligand-collections/current/${queue_no}" ]]; then
        queue_collection_file_exists="false"
    else 
        queue_collection_file_exists="true"
        perl -ni -e "print unless /^$/" ../workflow/ligand-collections/current/${queue_no}
    fi
    # Checking the conditions for using a new collection
    if [[ "${queue_collection_file_exists}" = "false" ]] || [[ "${queue_collection_file_exists}" = "true" && ! $(cat ../workflow/ligand-collections/current/${queue_no} | tr -d '[:space:]') ]]; then
        
        if [ "${verbosity}" == "debug" ]; then 
            echo -e "\n***************** INFO **********************" 
            echo ${queue_no}
            ls -lh ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
            cat ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
            cat ../workflow/ligand-collections/todo/${queue_no} 2>/dev/null || true
            echo -e "***************** INFO END ******************\n"
        fi
        next_ligand_collection
        if [ "${verbosity}" == "debug" ]; then 
            echo -e "\n***************** INFO **********************" 
            echo ${queue_no}
            ls -lh ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
            cat ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
            cat ../workflow/ligand-collections/todo/${queue_no} 2>/dev/null || true
            echo -e "***************** INFO END ******************\n"
        fi
        prepare_collection_files_tmp
        if [ "${verbosity}" == "debug" ]; then 
            echo -e "\n***************** INFO **********************" 
            echo ${queue_no}
            ls -lh ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
            cat ../workflow/ligand-collections/current/${queue_no} 2>/dev/null || true
            cat ../workflow/ligand-collections/todo/${queue_no} 2>/dev/null || true
            echo -e "***************** INFO END ******************\n"
        fi
        # Getting the name of the first ligand of the first collection
        next_ligand=$(tar -tf /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${next_ligand_collection_sub1}/${next_ligand_collection_sub2} | head -n 1 | awk -F '.' '{print $1}')

    # Using the old collection
    else
        # Getting the name of the current ligand collection
        last_ligand_collection=$(cat ../workflow/ligand-collections/current/${queue_no})
        last_ligand_collection_basename=${last_ligand_collection/.*}        
        last_ligand_collection_sub1="${last_ligand_collection_basename/_*}"
        last_ligand_collection_sub2="${last_ligand_collection/*_}"
        last_ligand_collection_sub2_basename="${last_ligand_collection_basename/*_}"
        
        # Checking if this is the first ligand of this queue
        if [ "${ligand_index}" = "1" ]; then
            # Extracting the last ligand collection
            mkdir -p /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${last_ligand_collection_sub1}/
            # 2015: tar -xf ${collection_folder}/${last_ligand_collection_sub1}.tar -C /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/ ${last_ligand_collection_sub1}/${last_ligand_collection_sub2} || true
            tar -xf ${collection_folder}/${last_ligand_collection_sub1}.tar -C /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${last_ligand_collection_sub1}/ ${last_ligand_collection_sub2} || true

            # Checking if the collection.status.tmp file exists due to abnormal abortion of job/queue
            # Removing old status.tmp file if existent
            if [[ -f "../workflow/ligand-collections/ligand-lists/${last_ligand_collection_sub1}/${last_ligand_collection_sub2_basename}.status.tmp" ]]; then
                echo "The file ${last_ligand_collection_basename}.status.tmp exists already."
                echo "This collection will be restarted."
                rm ../workflow/ligand-collections/ligand-lists/${last_ligand_collection_sub1}/${last_ligand_collection_sub2_basename}.status.tmp
                
                # Getting the name of the first ligand of the first collection
                next_ligand=$(tar -tf /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${last_ligand_collection_sub1}/${last_ligand_collection_sub2} | head -n 1 | awk -F '.' '{print $1}')

            else
                last_ligand_entry=$(head -n 1 ../workflow/ligand-collections/ligand-lists/${last_ligand_collection_sub1}/${last_ligand_collection_sub2_basename}.status 2>/dev/null || true)
                last_ligand=$(echo ${last_ligand_entry} | awk -F ' ' '{print $1}')
                docking_type_index_start=$(echo ${last_ligand_entry} | awk -F ' ' '{print $2}')
                docking_replica_index_start=$(echo ${last_ligand_entry} | awk -F ' ' '{print $3}')
                
                # Incrementing the indeces (replica, type)
                docking_replica_index_end=${docking_type_replicas_total[(($docking_type_index_start - 1))]}
                if [ "${docking_replica_index_start}" -lt "${docking_replica_index_end}" ]; then
                    # then can increment the replica index
                    docking_replica_index_start=$((docking_replica_index_start + 1))
                    next_ligand=${last_ligand}
                elif [ "${docking_type_index_start}" -lt "${docking_type_index_end}" ]; then
                    # then can increment the type index
                    docking_type_index_start=$((docking_type_index_start + 1))
                    docking_replica_index_start=1
                    next_ligand=${last_ligand}
                else 
                    # Need to use new ligand
                    docking_replica_index_start=1
                    docking_type_index_start=1
                    next_ligand=$(tar -tf /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${last_ligand_collection_sub1}/${last_ligand_collection_sub2} | grep -A 1 "${last_ligand}" | grep -v ${last_ligand} | awk -F '.' '{print $1}')
                fi
            fi
        # Not first ligand of this queue
        else
            last_ligand=$(tail -n 1 ../workflow/ligand-collections/ligand-lists/${last_ligand_collection_sub1}/${last_ligand_collection_sub2_basename}.status.tmp 2>/dev/null | awk -F ' ' '{print $1}' || true)
            next_ligand=$(tar -tf /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${last_ligand_collection_sub1}/${last_ligand_collection_sub2} | grep -A 1 "${last_ligand}" | grep -v ${last_ligand} | awk -F '.' '{print $1}')
        fi
        
        # Check if we can use the old collection
        if [ -n "${next_ligand}" ]; then
            # We can continue to use the old ligand collection
            next_ligand_collection=${last_ligand_collection}
            next_ligand_collection_basename=${last_ligand_collection_basename}
            next_ligand_collection_sub2_basename="${next_ligand_collection_basename/*_}"
            next_ligand_collection_sub2="${next_ligand_collection/*_}"
            next_ligand_collection_sub1="${next_ligand_collection/_*}"
            # Preparing the collection folders only if ligand_index=1 
            if [ "${ligand_index}" = "1" ]; then
                prepare_collection_files_tmp
            fi
        # Otherwise we have to use a new ligand collection
        else
            collection_complete="true"
            # Cleaning up the files and folders of the old collection
            if [ ! "${ligand_index}" = "1" ]; then
               clean_collection_files_tmp ${last_ligand_collection}
            fi
            # Updating the ligand collection files       
            echo -n "" > ../workflow/ligand-collections/current/${queue_no}
            echo "${last_ligand_collection} was completed by queue ${queue_no} on $(date)" >> ../workflow/ligand-collections/done/${queue_no}
            # Getting the next collection if there is one more
            next_ligand_collection
            prepare_collection_files_tmp
            # Getting the first ligand of the new collection
            next_ligand=$(tar -tf /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${next_ligand_collection_sub1}/${next_ligand_collection_sub2} | head -n 1 | awk -F '.' '{print $1}')
            docking_type_index_start=1
            docking_replica_index_start=1
        fi
    fi
    
    # Displaying the heading for the new ligand
    echo ""
    echo "      Ligand ${ligand_index} of job ${old_job_no} belonging to collection ${next_ligand_collection_basename}: ${next_ligand}"
    echo "*****************************************************************************************"
    echo ""
        
    # Loop for each docking type
    for docking_type_index in $(seq ${docking_type_index_start} ${docking_type_index_end}); do
    
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
                controlfile="../workflow/control/all.ctrl"
            fi
          
            # Checking if this queue line should be stopped immediately
            line=$(cat ${controlfile} | grep "^stop_after_ligand=")
            stop_after_ligand=${line/"stop_after_ligand="}
            if [ "${stop_after_ligand}" = "yes" ]; then
                echo
                echo "This queue was stopped by the stop_after_ligand flag in the controlfile ${controlfile}."
                echo
                end_queue 0
            fi
          
            # Checking if there is enough time left for a new ligand
            if [[ "${little_time}" = "true" ]]; then
                echo
                echo "This queue was ended because a signal was caught indicating this queue should stop now."
                echo
                end_queue 0
            fi
            echo $start_time_seconds
            echo $(date +%s)
            echo $timelimit_seconds
            if [[ "$((timelimit_seconds - $(date +%s ) + start_time_seconds )) " -lt "${minimum_time_remaining}" ]]; then
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
        
            # Extracting the next ligand
            tar -xOf /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/collections/${next_ligand_collection_sub1}/${next_ligand_collection_sub2} ${next_ligand}.pdbqt.gz | zcat  > /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt
        
            # Checking if ligand contains B, Si, Sn
            if grep -q " B " /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt; then
                error_response_ligand_elements "B"
            elif grep -i -q " Si " /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt; then 
                error_response_ligand_elements "Si"
            elif grep -i -q " Sn " /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt; then 
                error_response_ligand_elements "Sn"
            fi       
                
            # Getting the number of cpus per queue
            line="$(cat ${controlfile} | grep "^cpus_per_queue=")" 
            cpus_per_queue=${line/"cpus_per_queue="}
        
            # Running the docking program
            trap 'error_response_docking' ERR
            case $docking_type_program in 
                qvina02)
                    bin/time_bin -a -o "/tmp/${USER}/${queue_no}/workflow/output-files/queues/queue-${queue_no}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/qvina02 --cpu ${cpus_per_queue} --config ${docking_type_inputfolder}/config.txt --ligand /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt --out /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.pdbqt > /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}
                    trap 'error_response_std $LINENO' ERR
                    score_value=$(grep " 1 " /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;       
                vina)
                    bin/time_bin -a -o "/tmp/${USER}/${queue_no}/workflow/output-files/queues/queue-${queue_no}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/vina --cpu ${cpus_per_queue} --config ${docking_type_inputfolder}/config.txt --ligand /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt --out /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.pdbqt > /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}
                    trap 'error_response_std $LINENO' ERR
                    score_value=$(grep " 1 " /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;   
                smina*)
                    bin/time_bin -a -o "/tmp/${USER}/${queue_no}/workflow/output-files/queues/queue-${queue_no}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/smina --cpu ${cpus_per_queue} --config ${docking_type_inputfolder}/config.txt --ligand /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt --out /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.pdbqt --out_flex /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.flexres.pdb --log /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index} --atom_terms /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.atomterms
                    score_value=$(tac /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index} | grep -m 1 "^1    " | awk '{print $2}')
                    ;;  
                adfr)
                    adfr_configfile_options=$(cat ${docking_type_inputfolder}/config.txt | tr -d "\n")
                    bin/time_bin -a -o "/tmp/${USER}/${queue_no}/workflow/output-files/queues/queue-${queue_no}.out" -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/adfr -l /tmp/${USER}/${queue_no}/input-files/ligands/pdbqt/individual/${next_ligand}.pdbqt --jobName adfr ${adfr_configfile_options}
                    rename "_adfr_adfr.out" "" ${next_ligand}_replica-${docking_replica_index} /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}*
                    score_value=$(grep -m 1 "FEB" /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.pdbqt | awk -F ': ' '{print $(NF)}')
                    ;;
                *)
                    error_response_docking_program $docking_type_program
            esac 
            trap 'error_response_std $LINENO' ERR
            

            # Archiving the files and results
            case $docking_type_program in 
                qvina02 | vina | smina* | adfr)
                    
                    # Updating the summary file
                    update_summary 
                    
                    # Compressing and archiving the pdbqt output file
                    gzip /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.pdbqt
                    tar -r -f /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/all.tar -C /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/ ${next_ligand}_replica-${docking_replica_index}.pdbqt.gz
                
                    # Compressing and archiving the screen/log output
                    gzip /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}
                    tar -r -f /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/all.tar -C /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/logfiles/${next_ligand_collection_basename}/ ${next_ligand}_replica-${docking_replica_index}.gz
                    ;;
            esac
            case $docking_type_program in
                adfr)
                    # Compressing and archiving the .dro (docking result object) output file
                    gzip /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/dro/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.dro
                    tar -r -f /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/all.tar -C /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/ ${next_ligand}_replica-${docking_replica_index}.dro.gz
                    ;;
                smina_rigid)
                    # Compressing and archiving the atomterms output file
                    gzip /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.atomterms
                    tar -r -f /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/all.tar -C /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/ ${next_ligand}_replica-${docking_replica_index}.atomterms.gz
                    ;;
                smina_flexible)
                    # Compressing and archiving the atomterms output file
                    gzip /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.atomterms
                    tar -r -f /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/all.tar -C /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/ ${next_ligand}_replica-${docking_replica_index}.atomterms.gz
                    # Compressing and archiving the pdbqt flexres output file
                    gzip /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/${next_ligand}_replica-${docking_replica_index}.flexres.pdb
                    tar -r -f /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/all.tar -C /tmp/${USER}/${queue_no}/output-files/incomplete/${docking_type_name}/results/${next_ligand_collection_basename}/ ${next_ligand}_replica-${docking_replica_index}.flexres.pdb.gz
                    ;;
            esac 
            
            # Updating the ligand list
            update_ligand_list_end_success
            docking_counter_currentjob=$((docking_counter_currentjob + 1))
           
            if [ "${verbosity}" == "debug" ]; then 
                echo -e "\n***************** INFO **********************" 
                echo ${queue_no}
                ls -lh ../workflow/ligand-collections/current/${queue_no}  2>/dev/null || true
                cat ../workflow/ligand-collections/current/${queue_no}  2>/dev/null || true
                cat ../workflow/ligand-collections/current/${squeue_no}  2>/dev/null || true
                echo -e "***************** INFO END ******************\n"
            fi
            needs_cleaning=true
        done
    done
done

# Cleaning up everything
clean_collection_files_tmp ${next_ligand_collection}
clean_queue_files_tmp

# Printing some final information
echo
echo "All ligands of this queue have been processed."
echo
