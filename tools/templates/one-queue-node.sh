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

object_store_type="$(grep -m 1 "^object_store_type=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_bucket="$(grep -m 1 "^object_store_bucket=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_job_data="$(grep -m 1 "^object_store_job_data_prefix=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_ligands_prefix="$(grep -m 1 "^object_store_ligands_prefix=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

s3_output_path="s3://${object_store_bucket}/${object_store_job_data}/output"
s3_input_path="s3://${object_store_bucket}/${object_store_ligands_prefix}"

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
        echo -e "\n * Ignoring error. Trying to continue..." | tee -a /dev/stderr

    elif [[ "${VF_ERROR_RESPONSE}" == "next_job" ]]; then

        # Cleaning up
        #clean_queue_files_tmp

        # Printing some information
        echo -e "\n * Trying to stop this queue and causing the jobline to fail..." | tee -a /dev/stderr

        # Exiting
        exit 0

    elif [[ "${VF_ERROR_RESPONSE}" == "fail" ]]; then

        # Cleaning up
        #clean_queue_files_tmp

        # Printing some information
        echo -e "\n * Trying to stop this queue and causing the jobline to fail..." | tee -a /dev/stderr

        # Exiting
        exit 1
    fi
}
trap 'error_response_std $LINENO' ERR



# Preparing the folders and files in ${VF_TMPDIR}
prepare_collection_files_tmp() {

    # Creating the required folders
    if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/" ]; then
        mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/
    elif  [ -d ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/ ]; then
        rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/
    fi
    for docking_scenario_name in ${docking_scenario_names[@]}; do
        if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}" ]; then
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}
        elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/")" ]; then
            rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/*
        fi
        if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}" ]; then
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}
        elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/")" ]; then
            rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/*
        fi
        if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}" ]; then
            mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}
        elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/")" ]; then
            rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/*
        fi
    done
    if [ ! -d "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/" ]; then
        mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/
    elif [ "$(ls -A "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/")" ]; then
        rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/*
    fi

    # Extracting the required files
    if [ ! -f ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar ]; then
        if [ -f ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}.tar ]; then
            tar -xf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/ ${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
            gunzip ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
         else
		 mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/
            aws s3 cp ${s3_input_path}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
	    if [ $? -ne 0 ]; then
		echo " * Error: The ligand collection ${next_ligand_collection_tranch}_${next_ligand_collection_ID} could not be found." | tee -a /dev/stderr
		error_response_std $LINENO
	    fi
	    gunzip ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar.gz
	fi

    fi

    # Checking if the collection could be extracted
    if [ ! -f ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar ]; then

        # Raising an error
        echo " * Error: The ligand collection ${next_ligand_collection_tranch}_${next_ligand_collection_ID} could not be prepared." | tee -a /dev/stderr
        error_response_std $LINENO
    fi

    # Extracting all the ligands of the collection at the same time (faster than individual for each ligand separately)
    tar -xf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}

}

update_summary() {
    trap 'error_response_std $LINENO' ERR

    if [ ! -f ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt ]; then
        printf "Tranch   Compound   average-score   maximum-score   number-of-dockings" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
        for k in $(seq 1 ${docking_replica_index_end}); do
            printf "   score-replica-$k" >>  ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
        done
        printf "\n" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
    fi

    if [ -f "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.scores" ]; then

    	# get the scores from this

	declare -a scores_all
	readarray -t scores_all < <(cat ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.scores)

    	# Computing the new average value
	score_average=$(echo "${scores_all[@]}" | tr -s " " "\n" | awk '{ sum += $1 } END { if (NR > 0) print sum / NR }')

    	# Computing the new maximum value
	score_maximum=$(echo "${scores_all[@]}" | awk '{m=$1;for(i=1;i<=NF;i++)if($i<m)m=$i;print m}')

    	# Upating the line
    	scores_all_expaned="${scores_all[@]}"

    	number_of_scores=$(wc -l ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.scores | awk '{print $1}')

    	printf "${next_ligand_collection} ${next_ligand} %3.1f %3.1f %5s ${scores_all_expaned}\n" "${score_average}" "${score_maximum}" "${number_of_scores}" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt

    	column -t ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt.tmp
    	mv ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt.tmp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.txt
   fi
}



save_collection_file() {
	local_ligand_collection=${1}
	local_ligand_collection_tranch="${local_ligand_collection/_*}"
	local_ligand_collection_metatranch="${local_ligand_collection_tranch:0:2}"
	local_ligand_collection_ID="${local_ligand_collection/*_}"

	# Printing some information
	echo -e "\n * The collection ${local_ligand_collection} has been completed."
	echo "    * Storing corresponding files..."

	# Loop for each docking type
	for docking_scenario_name in ${docking_scenario_names[@]}; do

        mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
		tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

		aws s3 cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz  ${s3_output_path}/${docking_scenario_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz


		# Summaries

		mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/
		gzip < ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.txt > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.txt.gz || true

		aws s3 cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.txt.gz ${s3_output_path}/${docking_scenario_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.txt.gz

		# logfiles

		mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/

		tar -czf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz -C ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ ${local_ligand_collection_ID} || true

		aws s3 cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz ${s3_output_path}/${docking_scenario_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz

	done

	# Copy the status file
	gzip ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status 

	aws s3 cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status.gz ${s3_output_path}/${docking_scenario_name}/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status.gz

}



# Tidying up collection folders and files in ${VF_TMPDIR}
clean_collection_files_tmp() {


	# Printing some information
	echo -e "\n * The collection ${local_ligand_collection} has been completed."
	echo "    * cleaning corresponding files..."

            # Loop for each docking type
            for docking_scenario_name in ${docking_scenario_names[@]}; do

                rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz &> /dev/null || true
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

                # Cleaning up
                rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz &> /dev/null || true
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/summaries/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

                # Cleaning up
                rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/complete/${docking_scenario_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.tar.gz &> /dev/null || true
                rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID} &> /dev/null || true

	done


        # Cleaning up
        rm -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/ &> /dev/null || true
        rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${local_ligand_collection_metatranch}/${local_ligand_collection_tranch}/${local_ligand_collection_ID}.status* &> /dev/null || true

#    fi
    needs_cleaning="false"
}


# Function for end of the queue
end_queue() {

    # Variables
    exitcode=${1}

    # Checking if cleaning up is needed
    clean_collection_files_tmp ${next_ligand_collection}

    #  Exiting
    exit ${exitcode}
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




determine_controlfile() {

    # Updating the temporary controlfile
    cp ${VF_CONTROLFILE} ${VF_CONTROLFILE_TEMP}

}

# Error reponse ligand elements
error_response_ligand_elements() {

    # Variables
    element=$1
    ligand_list_entry="failed(ligand_elements:${element})"

    # Printing some information
    echo | tee -a /dev/stderr
    echo "The ligand contains elements (${element}) which cannot be handled by quickvina." | tee -a /dev/stderr
    echo "Skipping this ligand and continuing with next one." | tee -a /dev/stderr

    # Updating the ligand list file
    echo "${next_ligand} ${ligand_list_entry}" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status

    # Printing some information
    echo "Ligand ${next_ligand} ${ligand_list_entry} on $(date)."

    # Continuing with next ligand
    continue
}

# Error reponse ligand coordinates
error_response_ligand_coordinates() {

    # Variables
    element=$1
    ligand_list_entry="failed(ligand_coordinates)"

    # Printing some information
    echo
    echo "The ligand contains elements with the same coordinates."
    echo "Skipping this ligand and continuing with next one."

    # Updating the ligand list file
    echo "${next_ligand} ${ligand_list_entry}" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status

    # Printing some information
    echo "Ligand ${next_ligand} ${ligand_list_entry} on $(date)."

    # Continuing with next ligand
    continue
}


process_collection() {
	# break out the variables
	next_ligand_collection_ID="${next_ligand_collection/*_}"
	next_ligand_collection_tranch="${next_ligand_collection/_*}"
	next_ligand_collection_metatranch="${next_ligand_collection_tranch:0:2}"
	echo "length is $next_ligand_collection_length"
	echo "collection is next_ligand_collection"
	#next_ligand_collection_length=$(head -n 1 ../workflow/ligand-collections/todo/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/${VF_QUEUE_NO} | awk '{print $2}')


	# Updating the ligand-collection files
	#echo "${next_ligand_collection} ${next_ligand_collection_length}" > ../workflow/ligand-collections/current/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/${VF_QUEUE_NO}

	# Printing some information
	echo "The new ligand collection is ${next_ligand_collection}."


	# prepare and get the collection dataset
	prepare_collection_files_tmp


	# Make a list of the environment each docking program run will need -- the workitem list below will source those variables

	env_file=${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/env.sh
	cat << EOF > ${env_file}
VF_TMPDIR=${VF_TMPDIR}
VF_JOBLETTER=${VF_JOBLETTER}
VF_QUEUE_NO_12=${VF_QUEUE_NO_12}
VF_QUEUE_NO=${VF_QUEUE_NO}
VF_VERBOSITY_LOGFILES=${VF_VERBOSITY_LOGFILES}
VF_ERROR_SENSITIVITY=${VF_ERROR_SENSITIVITY}
next_ligand_collection=${next_ligand_collection}
next_ligand_collection_metatranch=${next_ligand_collection_metatranch}
next_ligand_collection_tranch=${next_ligand_collection_tranch}
next_ligand_collection_ID=${next_ligand_collection_ID}
supported_docking_programs="${supported_docking_programs}"
EOF

	# build up a work list that we can go through
	rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workitems 2> /dev/null
	ligand_index=0
	while IFS= read -r next_ligand
	do
		ligand_index=$((ligand_index+1))
		docking_scenario_index_start=1

		# Displaying the heading for the new ligand
		echo ""
		echo "      Ligand ${ligand_index} of job ${VF_OLD_JOB_NO} belonging to collection ${next_ligand_collection}: ${next_ligand}"
		echo "*****************************************************************************************"

		# Checking if ligand contains B, Si, Sn
		if grep -q " B " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format}; then
			error_response_ligand_elements "B"
		elif grep -i -q " Si " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format}; then
			error_response_ligand_elements "Si"
		elif grep -i -q " Sn " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format}; then
			error_response_ligand_elements "Sn"
		fi

		# Checking if the ligand contains duplicate coordinates
		duplicate_count=$(grep ATOM ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} | awk '{print $6, $7, $8}' | sort | uniq -c | grep -v " 1 " | wc -l)
		if [ ${duplicate_count} -ne "0" ]; then
			error_response_ligand_coordinates
		fi


		for docking_scenario_index in $(seq ${docking_scenario_index_start} ${docking_scenario_index_end}); do
			docking_scenario_name=${docking_scenario_names[(($docking_scenario_index - 1))]}
			docking_scenario_program=${docking_scenario_programs[(($docking_scenario_index - 1))]}
			docking_scenario_inputfolder=${docking_scenario_inputfolders[(($docking_scenario_index - 1))]}
			docking_replica_index_start=1
			docking_replica_index_end=${docking_scenario_replicas_total[(($docking_scenario_index - 1))]}

			# Loop for each replica for the current docking type

			for docking_replica_index in $(seq ${docking_replica_index_start} ${docking_replica_index_end}); do
				echo "/opt/vf/tools/templates/single_run_wrap.sh ${env_file} ${next_ligand} ${docking_scenario_name} ${docking_scenario_program} ${docking_scenario_inputfolder} ${docking_replica_index} ${docking_scenario_index} ${docking_scenario_index_end} ${docking_replica_index_end}" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workitems

			done
		done
	done < <(tar -tf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar | tail --lines=+2 | awk -F '[/.]' '{print $2}')

	echo "*** Running parallel work ***"

	# Now run each ligand separately
	if [ -z ${VF_CONTAINER_VCPUS} ]; then
		parallel < ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workitems
	else
		echo "Running ${VF_CONTAINER_VCPUS} vCPUs in parallel"
		parallel --jobs ${VF_CONTAINER_VCPUS} < ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workitems
	fi

	# Now that we are done with the collection generate the collection-level files

	sleep 1

	echo "*** Printing out completed ligands ***"

	while IFS= read -r next_ligand
	do
		for docking_scenario_index in $(seq ${docking_scenario_index_start} ${docking_scenario_index_end}); do
			docking_scenario_name=${docking_scenario_names[(($docking_scenario_index - 1))]}
			docking_scenario_program=${docking_scenario_programs[(($docking_scenario_index - 1))]}
			docking_scenario_inputfolder=${docking_scenario_inputfolders[(($docking_scenario_index - 1))]}
			docking_replica_index_end=${docking_scenario_replicas_total[(($docking_scenario_index - 1))]}

			update_summary

			# Loop for each replica for the current docking type
#			for docking_replica_index in $(seq ${docking_replica_index_start} ${docking_replica_index_end}); do
#				if [ -f "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.output" ]; then
#					cat ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.output
#				else
#					echo "No output for ${next_ligand}_replica-${docking_replica_index} found!"
#				fi
#			done
		done
	done < <(tar -tf ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.tar | tail --lines=+2 | awk -F '[/.]' '{print $2}')


	# Copy everything over to the shared storage

	needs_cleaning="true"
	collection_complete="true"

	save_collection_file ${next_ligand_collection}
	clean_collection_files_tmp ${next_ligand_collection}

	# Removing the new collection from the ligand-collections-todo file
	#perl -ni -e "print unless /${next_ligand_collection}\b/" ../workflow/ligand-collections/todo/${VF_QUEUE_NO_1}/${VF_QUEUE_NO_2}/${VF_QUEUE_NO}
}


# Verbosity
if [ "${VF_VERBOSITY_LOGFILES}" = "debug" ]; then
    set -x
fi

# Determining the control file
export VF_CONTROLFILE_TEMP=${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/controlfile
determine_controlfile

# Variables
keep_ligand_summary_logs="$(grep -m 1 "^keep_ligand_summary_logs=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ligand_check_interval="$(grep -m 1 "^ligand_check_interval=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
cpus_per_queue="$(grep -m 1 "^cpus_per_queue=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
outputfiles_level="$(grep -m 1 "^outputfiles_level=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ligand_library_format="$(grep -m 1 "^ligand_library_format=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Docking
supported_docking_programs="vina, qvina02, qvina_w, smina,vina_xb, vina_carb, gwovina, adfr"
needs_cleaning="false"

# Determining the names of each docking type
docking_scenario_names="$(grep -m 1 "^docking_scenario_names=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_scenario_names <<< "$docking_scenario_names"

# Determining the number of docking types
docking_scenario_index_end=${#docking_scenario_names[@]}

# Determining the docking programs to use for each docking type
docking_scenario_programs="$(grep -m 1 "^docking_scenario_programs=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_scenario_programs <<< "$docking_scenario_programs"
docking_scenario_programs_length=${#docking_scenario_programs[@]}

# Determining the docking type replicas
docking_scenario_replicas_total="$(grep -m 1 "^docking_scenario_replicas=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_scenario_replicas_total <<< "$docking_scenario_replicas_total"
docking_scenario_replicas_total_length=${#docking_scenario_replicas_total[@]}

# Determining the docking type input folders
docking_scenario_inputfolders="$(grep -m 1 "^docking_scenario_inputfolders=" ${VF_CONTROLFILE_TEMP} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_scenario_inputfolders <<< "$docking_scenario_inputfolders"
docking_scenario_inputfolders_length=${#docking_scenario_inputfolders[@]}

# Determining the docking scenario receptor files
for docking_scenario_index in $(seq 0 $((${docking_scenario_index_end} - 1)) ); do
    docking_scenario_receptor_filenames[${docking_scenario_index}]=$(grep "^receptor" ${docking_scenario_inputfolders[((docking_scenario_index))]}/config.txt | awk -F "/" '{print $NF}')
done



# Checking the variables for errors
if ! [ "${docking_scenario_index_end}" -eq "${docking_scenario_programs_length}" ]; then
    echo "ERROR:" | tee -a /dev/stderr
    echo " * Some variables specified in the controlfile ${VF_CONTROLFILE_TEMP} are not compatible." | tee -a /dev/stderr
    echo " * The variable docking_scenario_names has ${docking_scenario_index_end} entries." | tee -a /dev/stderr
    echo " * The variable docking_scenario_programs has ${docking_scenario_programs_length} entries." | tee -a /dev/stderr
    exit 1
elif ! [ "${docking_scenario_index_end}" -eq "${docking_scenario_replicas_total_length}" ]; then
    echo "ERROR:" | tee /dev/stderr
    echo " * Some variables specified in the controlfile ${VF_CONTROLFILE_TEMP} are not compatible." | tee -a /dev/stderr
    echo " * The variable docking_scenario_names has ${docking_scenario_index_end} entries." | tee -a /dev/stderr
    echo " * The variable docking_scenario_replicas has ${docking_scenario_replicas_total_length} entries." | tee -a /dev/stderr
    exit 1
elif ! [ "${docking_scenario_index_end}" -eq "${docking_scenario_inputfolders_length}" ]; then
    echo "ERROR:" | tee /dev/stderr
    echo " * Some variables specified in the controlfile ${VF_CONTROLFILE_TEMP} are not compatible." | tee -a /dev/stderr
    echo " * The variable docking_scenario_names has ${docking_scenario_index_end} entries." | tee -a /dev/stderr
    echo " * The variable docking_scenario_inputfolders has ${docking_scenario_inputfolders_length} entries." | tee -a /dev/stderr
    exit 1
fi


# Checking the variables for errors
if ! [[ "${ligand_library_format}" = "mol2" || "${ligand_library_format}" = "pdbqt" ]]; then
    echo "ERROR:" | tee -a /dev/stderr
    echo " * A variable specified in the controlfile ${VF_CONTROLFILE_TEMP} are not specified correctly." | tee -a /dev/stderr
    echo " * The variable ligand_library_format has value ${ligand_library_format}." | tee -a /dev/stderr
    echo " * Supported values are currently 'pdbqt' and 'mol2'" | tee -a /dev/stderr
    exit 1
fi




# Saving some information about the VF_CONTROLFILE_TEMP
echo
echo
echo "*****************************************************************************************"
echo "              Beginning of a new job (job ${VF_OLD_JOB_NO}) in queue ${VF_QUEUE_NO}"
echo "*****************************************************************************************"
echo
echo "Control files in use"
echo "-------------------------"
echo "Controlfile = ${VF_CONTROLFILE_TEMP}"
echo
echo "Contents of the VF_CONTROLFILE_TEMP ${VF_CONTROLFILE_TEMP}"
echo "-----------------------------------------------"
cat ${VF_CONTROLFILE_TEMP}
echo
echo


# loop through every collection there is...


while IFS= read -r next_ligand_collection_line
do
	next_ligand_collection=$(echo ${next_ligand_collection_line} | awk '{print $1}')
	next_ligand_collection_length=$(echo ${next_ligand_collection_line} | awk '{print $2}')
	process_collection

done < /tmp/vf_tasks/${VF_STEP_NO}

no_more_ligand_collection


