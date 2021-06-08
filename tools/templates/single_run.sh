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


# Error reponse docking
error_response_docking() {

    # Printing some information
    echo "An error occurred during the docking procedure (${docking_scenario_name})." | tee -a /dev/stderr
    echo "Skipping this ligand and continuing with next one." | tee -a /dev/stderr

    # Variables
    ligand_list_entry="failed(docking)"

    # Updating the ligand list
    update_ligand_list_end "false"
    continue
}

# Error reponse docking program
error_response_docking_program() {

    # Variables
    ligand_list_entry="failed(docking_program)"

    # Printing some information
    echo "An error occurred during the docking procedure (${docking_scenario_name})." | tee -a/dev/stderr
    echo "An unsupported docking program ($docking_scenario_program) has been specified." | tee -a /dev/stderr
    echo "Supported docking programs are: ${supported_docking_programs}" | tee -a /dev/stderr
    echo "Aborting the virtual screening procedure..." | tee -a /dev/stderr

    # Updating the ligand list
    update_ligand_list_end "false"
    exit 1
}

update_ligand_list_end() {

    # Variables
    success="${1}" # true or false
    docking_total_time_ms="$(($(date +'%s * 1000 + %-N / 1000000') - ${docking_start_time_ms}))"

    # Updating the ligand-list file
    # Not used currently: ligand_list_entry
    if [ "${success}" == "true" ]; then
        perl -pi -e "s/${next_ligand} ${docking_scenario_index} ${docking_replica_index} processing.*/${next_ligand} ${docking_scenario_index} ${docking_replica_index} succeeded total-time:${docking_total_time_ms}/g" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status
    else
        perl -pi -e "s/${next_ligand} ${docking_scenario_index} ${docking_replica_index} processing.*/${next_ligand} ${docking_scenario_index} ${docking_replica_index} ${ligand_list_entry} total-time:${docking_total_time_ms}/g" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status
    fi

    # Printing some information
    echo
    if [ "${success}" == "true" ]; then
        echo "Docking type  ${docking_scenario_index}/${docking_scenario_index_end} (${docking_scenario_name}), replica ${docking_replica_index}/${docking_replica_index_end} of ${next_ligand} completed successfully on $(date)."
    else
        echo "Docking type  ${docking_scenario_index}/${docking_scenario_index_end} (${docking_scenario_name}), replica ${docking_replica_index}/${docking_replica_index_end} of ${next_ligand} ${ligand_list_entry} on $(date)."
    fi
    echo "Total time for this docking (${next_ligand}) in ms: ${docking_total_time_ms}"
    echo

    # Variables
    ligand_list_entry=""
}

# Writing the ID of the next ligand to the current ligand list
update_ligand_list_start() {

    # Variables
    docking_start_time_ms=$(($(date +'%s * 1000 + %-N / 1000000')))
    ligand_list_entry=""

    # Updating the ligand-list file
    echo "${next_ligand} ${docking_scenario_index} ${docking_replica_index} processing" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/workflow/ligand-collections/ligand-lists/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}.status
}



env_file=${1}
next_ligand=${2}
docking_scenario_name=${3}
docking_scenario_program=${4}
docking_scenario_inputfolder=${5}
docking_replica_index=${6}
docking_scenario_index=${7}
docking_scenario_index_end=${8}
docking_replica_index_end=${9}

source ${env_file}

cpus_per_queue=1

# Setting the verbosity level
if [[ "${VF_VERBOSITY_LOGFILES}" == "debug" ]]; then
    set -x
fi

# Setting the error sensitivity
if [[ "${VF_ERROR_SENSITIVITY}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.
fi

update_ligand_list_start

pushd ${VF_CONTAINER_PATH}/tools


# Displaying the heading for the new iteration

echo
echo "   ***   Starting new docking run: docking type ${docking_scenario_index}/${docking_scenario_index_end} (${docking_scenario_name}), replica ${docking_replica_index}/${docking_replica_index_end}   ***   "
echo

# Running the docking program
trap 'error_response_docking' ERR
current_dir="$PWD"
case $docking_scenario_program in
	qvina02)
		{ bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/qvina02 --cpu ${cpus_per_queue} --config ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
		score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
		                    qvina_w)
                    { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/qvina_w --cpu ${cpus_per_queue} --config ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
                vina)
                    { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/vina --cpu ${cpus_per_queue} --config ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
                vina_carb)
                    { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/vina_carb --cpu ${cpus_per_queue} --config ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
                vina_xb)
                    { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/vina_xb --cpu ${cpus_per_queue} --config ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
                smina*)
                    { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/smina --cpu ${cpus_per_queue} --config ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} --out_flex ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.flexres.pdb --log ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} --atom_terms ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.atomterms 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    score_value=$(tac ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | grep -m 1 "^1    " | awk '{print $2}')
                    ;;
                gwovina*)
                        { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" bin/gwovina --cpu ${cpus_per_queue} --config ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/config.txt --ligand ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --out ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    score_value=$(grep " 1 " ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} | awk -F ' ' '{print $2}')
                    ;;
	         adfr)
                    adfr_configfile_options=$(cat ${docking_scenario_inputfolder}/config.txt | tr -d "\n")
                    { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" adfr -l ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --jobName adfr ${adfr_configfile_options} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    rename "_adfr_adfr.out" "" ${next_ligand}_replica-${docking_replica_index} ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}*
                    score_value=$(grep -m 1 "FEB" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} | awk -F ': ' '{print $(NF)}')
                    ;;
                 plants)
                    pushd ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}

                    # Checking ligand library format
                    if [[ "${ligand_library_format}" == "pdbqt" ]]; then
                        # On the fly conversion
                        obabel -i${ligand_library_format} ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} -opdb -O ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdb -ac -ab
                        $VF_WD/bin/spores --mode complete ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.pdb ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.mol2
                    fi

                    # Preparing the input files
                    if [[ "${ligand_index}" == "1" ]]; then
                        cp -r ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/input-files/${docking_scenario_inputfolder}/ ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/
                    fi
                    cp ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.mol2 ./
                    sed -i "s|.*${next_ligand/.mol2}|${next_ligand/.mol2}|g" ${next_ligand}.mol2
                    sed -i "s|ligand_file.*|ligand_file ${next_ligand}.mol2|g" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/${docking_scenario_inputfolder}/config.txt
                    sed -i "s|output_dir.*|output_dir ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}|g" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/${docking_scenario_inputfolder}/config.txt
                    sed -i "s|\.\.|${current_dir}/..|g" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/${docking_scenario_inputfolder}/config.txt
                    { $VF_WD/bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" $VF_WD/bin/plants --mode screen ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/${docking_scenario_inputfolder}/config.txt > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
                    cd "${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}/" || true
                    for file in *; do
                        mv $file ../${next_ligand}_replica-${docking_replica_index}_"${file}"
                    done
                    cd ..
                    rm -r ${next_ligand}_replica-${docking_replica_index}/ || true
                    mv *log *constraints* *correspondingNames* *descent* *optimizer* *plantsconfig* *skippedligands* ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/ || true
                    rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/${next_ligand}.mol2 || true
                    rm ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/*pid || true

                    score_value=$(grep -m 1 conf_01 ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/results/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}_bestranking.csv | awk -F ',' '{print $2}')
		    popd

                *)
                    error_response_docking_program $docking_scenario_program
esac





echo "${score_value}" >> ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.scores

update_ligand_list_end "true"

popd

#source 



