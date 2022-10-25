#!/usr/bin/env bash


# Copyright (C) 2019 Christoph Gorgulla
#
# This file is part of VirtualFlow.
#
# VirtualFlow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
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
# Usage: vf_report.sh workflow-status-mode virtual-screening-results-mode
#
# Description: Display current information about the workflow.
#
# ---------------------------------------------------------------------------

# Displaying the banner
echo
echo
. helpers/show_banner.sh
echo
echo

# Function definitions
# Standard error response 
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    echo -e "Cleaning up and exiting...\n\n"   
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Clean up
clean_up() {
    rm -r ${tempdir}/ 2>/dev/null || true
}
trap 'clean_up' EXIT

# Variables
usage="\nUsage: vf_report [-h] -c category [-v verbosity] [-d docking-type-name] [-s] [-n number-of-compounds]

Options:
    -h: Display this help
    -c: Possible categories are:
            workflow: Shows information about the status of the workflow and the batchsystem.
            vs: Shows information about the virtual screening results. Requires the -d option.
    -v: Specifies the verbosity level of the output. Possible values are 1-2 (default 1)
    -d: Specifies the docking type name (as defined in the workflow/control/all.ctrl file)
    -s: Specifies if statistical information should be shown about the virtual screening results (in the vs category)
        Possible values: true, false
        Default value: true
    -n: Specifies the number of highest scoring compounds to be displayed (in the vs category)
        Possible values: Non-negative integer
        Default value: 0

"
help_info="The -h option can be used to get more information on how to use this script."
controlfile="../workflow/control/all.ctrl"
collection_folder="$(grep -m 1 "^collection_folder=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
outputfiles_level="$(grep -m 1 "^outputfiles_level=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
batchsystem="$(grep -m 1 "^batchsystem=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
job_letter="$(grep -m 1 "^job_letter=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export LC_ALL=C
export LANG=C

# Determining the names of each docking type
docking_scenario_names="$(grep -m 1 "^docking_scenario_names=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_scenario_names <<< "$docking_scenario_names"

# Tempdir creation
vf_tempdir="$(grep -m 1 "^tempdir_default=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
tempdir=${vf_tempdir}/$USER/VFVS/${VF_JOBLETTER}/vf_report_$(date | tr " :" "_")
mkdir -p ${tempdir}

# Verbosity
verbosity="$(grep -m 1 "^verbosity_commands=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
if [ "${verbosity}" = "debug" ]; then
    set -x
fi

# Treating the input arguments
category_flag="false"
verbosity_flag="false"
docking_scenario_name_flag="false"
show_vs_statistics_flag="false"
number_highest_scores_flag="false"
while getopts ':hc:v:d:n:s:' option; do
    case "$option" in
        h)  echo -e "$usage"
            exit 0
            ;;
        c)  category=$OPTARG
            if ! [[ "${category}" == "workflow" || "${category}" == "vs" ]]; then
                echo -e "\nAn unsupported category (${category}) has been specified via the -c option."
                echo -e "${help_info}\n"
                echo -e "Cleaning up and exiting...\n\n"
                exit 1
            fi
            category_flag=true
            ;;
        v)  verbosity=$OPTARG
            if ! [[ "${verbosity}" == [1-2] ]]; then
                echo -e "\nAn unsupported verbosity level (${verbosity}) has been specified via the -v option."
                echo -e "${help_info}\n"
                echo -e "Cleaning up and exiting...\n\n"
                exit 1
            fi
            verbosity_flag=true
            ;;
        d)  docking_scenario_name=$OPTARG
            for name in ${docking_scenario_names[@]};do
                if [ "${docking_scenario_name}" == "${name}" ]; then
                    docking_scenario_name_flag="true"
                fi
            done

           if [[ "${docking_scenario_name_flag}" == "false" ]]; then
                echo -e "\nAn unsupported docking_scenario_name (${docking_scenario_name}) has been specified via the -d option."
                echo -e "In the control-file $controlfile the following docking type names are specified: ${docking_scenario_names[@]}"
                echo -e "${help_info}\n"
                echo -e "Cleaning up and exiting...\n\n"
                exit 1
            fi
            ;;
        s)  show_vs_statistics=$OPTARG
            if ! [[ "${show_vs_statistics}" == "true" || "${show_vs_statistics}" == "false"  ]]; then
                echo -e "\nAn invalid value (${show_vs_statistics}) has been specified via the -s option."
                echo -e "The value has to be true or false."
                echo -e "${help_info}\n"
                echo -e "Cleaning up and exiting...\n\n"
                exit 1
            fi
            show_vs_statistics_flag=true
            ;;
        n)  number_highest_scores=$OPTARG
            if ! [[ "${number_highest_scores[@]}" -gt 0  ]]; then
                echo -e "\nAn invalid number of highest scoring compounds (${number_highest_scores}) has been specified via the -n option."
                echo -e "The number has to be a non-negative integer."
                echo -e "${help_info}\n"
                echo -e "Cleaning up and exiting...\n\n"
                exit 1
            fi
            number_highest_scores_flag=true
            ;;
        :)  printf "\nMissing argument for option -%s\n" "$OPTARG" >&2
            echo -e "\n${help_info}\n"
            echo -e "Cleaning up and exiting...\n\n"
            exit 1
            ;;
        \?) printf "\nUnrecognized option: -%s\n" "$OPTARG" >&2
            echo -e "\n${help_info}\n"
            echo -e "Cleaning up and exiting...\n\n"
            exit 1
            ;;
        *)  echo "Unimplemented option: -$OPTARG" >&2;
            echo -e "\n${help_info}\n"
            exit 1
            ;;
    esac
done
if [ "${category_flag}" == "false" ]; then
    echo -e "\nThe mandatory option -c which specifies the category to report on was not specified."
    echo -e "${help_info}\n"
    echo -e "Cleaning up and exiting...\n\n"
    exit 1
elif [ "${category_flag}" == "true" ]; then
    if [[ "${category}" == "vs" &&  "${docking_scenario_name_flag}" == "false" ]]; then
        echo -e "\nThe option -d which specifies the docking type name was not specified, but it is required for this category (vs)."
        echo -e "In the control-file $controlfile the following docking type names are specified: ${docking_scenario_names[@]}"
        echo -e "${help_info}\n"
        echo -e "Cleaning up and exiting...\n\n"
        exit 1
    fi
fi
if [ "${verbosity_flag}" == "false" ]; then
    verbosity=1
fi
if [ "${number_highest_scores}" == "false" ]; then
    number_highest_scores=0
fi
if [ "${show_vs_statistics_flag}" == "false" ]; then
    show_vs_statistics="true"
fi

# Docking variables
docking_scenario_replicas_total="$(grep -m 1 "^docking_scenario_replicas=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
IFS=':' read -a docking_scenario_replicas_total <<< "$docking_scenario_replicas_total"
docking_runs_perligand=0
for value in ${docking_scenario_replicas_total[@]}; do
    docking_runs_perligand=$((docking_runs_perligand+value))
done


# Displaying date
echo
echo "                                  $(date)                                       "

# Checking the category
if [[ "${category}" = "workflow" ]]; then

    # Displaying the information
    echo
    echo
    echo "                                         Workflow Status                                        "
    echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    echo
    echo
    echo "                                             Joblines    "
    echo "................................................................................................"
    echo
    echo " Number of jobfiles in the workflow/jobfiles/main folder: $(ls ../workflow/job-files/main | wc -l)"
    if [[ "${batchsystem}" == "SLURM" || "${batchsystem}" == "LSF" ]]; then
        echo " Number of joblines in the batch system: $(bin/sqs 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -c "" 2>/dev/null || true)"
    fi
    if [ "${batchsystem}" = "SLURM" ]; then
        queues=$(squeue -l 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | awk '{print $2}' | sort | uniq | tr "\n" " " )
        echo " Number of joblines in the batch system currently running: $(squeue -l 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i "RUNNING" | grep -c "" 2>/dev/null || true)"
        for queue in ${queues}; do
            echo '  * Number of joblines in queue "'"${queue}"'"'" currently running: $(squeue -l | grep "${queue}.*RUN" | grep "${job_letter}\-" | grep ${USER:0:8} | wc -l)"
        done
        echo " Number of joblines in the batch system currently not running: $(squeue -l 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i -v "RUNNING" | grep -c "" 2>/dev/null || true)"
        for queue in ${queues}; do
            echo '  * Number of joblines in queue "'"${queue}"'"'" currently not running: $(squeue -l | grep ${USER:0:8} | grep "${job_letter}\-" | grep "${queue}" | grep -v RUN | grep -v COMPL | wc -l)"
        done 
    elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
        echo " Number of joblines in the batch system currently running: $(qstat 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i " R " | grep -c "" 2>/dev/null || true)"
        echo " Number of joblines in the batch system currently not running: $(qstat 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i -v " R " | grep -c "" 2>/dev/null || true)"

        queues=$(qstat 2>/dev/null | grep "${job_letter}\-" 2>/dev/null | grep "${USER:0:8}" | awk '{print $6}' | sort | uniq | tr "\n" " " )
        echo " Number of joblines in the batch system currently running: $(qstat 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i " R " | grep -c "" 2>/dev/null || true)"
        for queue in ${queues}; do
            echo '  * Number of joblines in queue "'"${queue}"'"'" currently running: $(qstat | grep ${USER:0:8} | grep "${job_letter}\-" | grep " R .*${queue}" | wc -l)"
        done
        echo " Number of joblines in the batch system currently not running: $(qstat 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i -v " R " | grep -c "" 2>/dev/null || true)"
        for queue in ${queues}; do
            echo '  * Number of joblines in queue "'"${queue}"'"'" currently not running: $(qstat | grep ${USER:0:8} | grep "${queue}" | grep "${job_letter}\-" | grep -v " R " | wc -l)"
        done 
    elif  [ "${batchsystem}" = "LSF" ]; then
        echo " Number of joblines in the batch system currently running: $(bin/sqs 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i "RUN" | grep -c "" 2>/dev/null || true)"
        queues=$(bin/sqs 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | awk '{print $4}' | sort | uniq | tr "\n" " " )
        for queue in ${queues}; do
            echo ' *  Number of joblines in queue "'"${queue}"'"'" currently running: $(bin/sqs | grep "RUN.*${queue}" | grep "${job_letter}\-" | wc -l)"
        done
        echo " Number of joblines in the batch system currently not running: $(bin/sqs 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i -v "RUN" | grep -c "" 2>/dev/null || true)"
        for queue in ${queues}; do
            echo ' *  Number of joblines in queue "'"${queue}"'"'" currently not running: $(bin/sqs | grep  -v "RUN" | grep "${queue}" | grep "${job_letter}\-" | wc -l)"
        done

    elif  [ "${batchsystem}" = "SGE" ]; then
        echo " Number of joblines in the batch system currently running: $(bin/sqs 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i " r " | grep -c "" 2>/dev/null || true)"
        queues=$(qconf -sql)
        for queue in ${queues}; do
            echo ' *  Number of joblines in queue "'"${queue}"'"'" currently running: $(bin/sqs | grep " r .*${queue}" | grep "${job_letter}\-" | wc -l)"
        done
        echo " Number of joblines in the batch system currently not running: $(bin/sqs 2>/dev/null | grep "${job_letter}\-" | grep "${USER:0:8}" | grep -i  " qw " | grep -c "" 2>/dev/null || true)"
    fi
    if [[ "$verbosity" -gt "2" ]]; then
        echo " Number of collections which are currently assigned to more than one queue: $(awk -F '.' '{print $1}' ../workflow/ligand-collections/current/*/*/* 2>/dev/null | sort -S 80% | uniq -c | grep " [2-9] " | grep -c "" 2>/dev/null || true)"
    fi
    if [[ "${batchsystem}" == "LSF" || "${batchsystem}" == "SLURM" || "{batchsystem}" == "SGE" ]]; then
        if [[ "${batchsystem}" == "SLURM" ]]; then
            squeue -o "%.18i %.9P %.8j %.8u %.8T %.10M %.9l %.6D %R %C" | grep RUN | grep "${USER:0:8}" | grep "${job_letter}\-" | awk '{print $10}' > ${tempdir}/report.tmp
        elif [[ "${batchsystem}" == "LSF" ]]; then
            bin/sqs | grep RUN | grep "${USER:0:8}" | grep "${job_letter}\-" | awk -F " *" '{print $6}' > ${tempdir}/report.tmp
        elif [[ "${batchsystem}" == "SGE" ]]; then
            bin/sqs | grep " r " | grep "${USER:0:8}" | grep "${job_letter}\-" | awk '{print $7}' > ${tempdir}/report.tmp
        fi
        sumCores='0'
        while IFS='' read -r line || [[ -n  "${line}" ]]; do 
            if [ "${line:0:1}" -eq "${line:0:1}" ] 2>/dev/null ; then
                coreNumber=$(echo $line | awk -F '*' '{print $1}')
            else 
                coreNumber=1
            fi
            sumCores=$((sumCores + coreNumber))
        done < ${tempdir}/report.tmp
        echo " Number of cores/slots currently used by the workflow: ${sumCores}"
        rm ${tempdir}/report.tmp  || true
    fi
    
    echo
    echo
    echo "                                            Collections    "
    echo "................................................................................................"
    echo
    echo " Total number of ligand collections: $(grep -c "" ../workflow/ligand-collections/var/todo.original 2>/dev/null || true )"

    ligand_collections_completed=0
    for folder1 in $(find ../workflow/ligand-collections/done/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/done/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            ligand_collections_completed_toadd="$(grep -ch "" ../workflow/ligand-collections/done/$folder1/$folder2/* 2>/dev/null | paste -sd+ 2>/dev/null | bc )"
            if [[ -z "${ligand_collections_completed_toadd// }" ]]; then
                ligand_collections_completed_toadd=0
            fi
            ligand_collections_completed=$((ligand_collections_completed + ligand_collections_completed_toadd))
        done
    done
    echo " Number of ligand collections completed: ${ligand_collections_completed}"

    ligand_collections_processing=0
    for folder1 in $(find ../workflow/ligand-collections/current/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/current/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            ligand_collections_processing_toadd=$(grep -ch "" ../workflow/ligand-collections/current/$folder1/$folder2/* 2>/dev/null | paste -sd+ 2>/dev/null | bc )
            if [[ -z "${ligand_collections_processing_toadd// }" ]]; then
                ligand_collections_processing_toadd=0
            fi
            ligand_collections_processing=$((ligand_collections_processing + ligand_collections_processing_toadd))
        done
    done
    echo " Number of ligand collections in state \"processing\": ${ligand_collections_processing}"

    ligand_collections_todo=0
    for folder1 in $(find ../workflow/ligand-collections/todo/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/todo/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            ligand_collections_todo_toadd=$(grep -ch "" ../workflow/ligand-collections/todo/$folder1/$folder2/* 2>/dev/null | paste -sd+ 2>/dev/null | bc )
            if [[ -z "${ligand_collections_todo_toadd// }" ]]; then
                ligand_collections_todo_toadd=0
            fi
            ligand_collections_todo=$((ligand_collections_todo + ligand_collections_todo_toadd))
        done
    done
    ligand_collections_todo_toadd=$(grep -ch "" ../workflow/ligand-collections/todo/todo.all.[0-9]* 2>/dev/null | paste -sd+ 2>/dev/null | bc )
    if [[ -z "${ligand_collections_todo_toadd// }" ]]; then
        ligand_collections_todo_toadd=0
    fi
    ligand_collections_todo=$((ligand_collections_todo + ligand_collections_todo_toadd))
    echo " Number of ligand collections not yet started: ${ligand_collections_todo}"
    echo
    echo

    echo "                                 Ligands (in completed collections)   "
    echo "................................................................................................"
    echo

    ligands_total=0
    if [ -s ../workflow/ligand-collections/var/todo.original ]; then
        ligands_total="$(awk '{print $2}' ../workflow/ligand-collections/var/todo.original | paste -sd+ | bc -l 2>/dev/null || true)"
        if [[ -z "${ligands_total// }" ]]; then
            ligands_total=0
        fi
    fi
    echo " Total number of ligands: ${ligands_total}"

    ligands_started=0
    for folder1 in $(find ../workflow/ligand-collections/done/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/done/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            ligands_started_to_add="$(grep -ho "Ligands-started:[0-9]\+" ../workflow/ligand-collections/done/$folder1/$folder2/* 2>/dev/null | awk -F ':' '{print $2}' | sed "/^$/d" |  paste -sd+ | bc -l 2>/dev/null || true)"
            if [[ -z "${ligands_started_to_add// }" ]]; then
                ligands_started_to_add=0
            fi
            ligands_started=$((ligands_started + ligands_started_to_add))
        done
    done
    echo " Number of ligands started: ${ligands_started}"

    ligands_success=0
    for folder1 in $(find ../workflow/ligand-collections/done/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/done/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            ligands_success_to_add="$(grep -ho "Ligands-succeeded:[0-9]\+" ../workflow/ligand-collections/done/$folder1/$folder2/* 2>/dev/null | awk -F ':' '{print $2}' | sed "/^$/d" |  paste -sd+ | bc -l 2>/dev/null || true)"
            if [[ -z "${ligands_success_to_add// }" ]]; then
                ligands_success_to_add=0
            fi
            ligands_success=$((ligands_success + ligands_success_to_add))
        done
    done
    echo " Number of ligands successfully completed: ${ligands_success}"

    ligands_failed=0
    for folder1 in $(find ../workflow/ligand-collections/done/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/done/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            ligands_failed_to_add="$(grep -ho "Ligands-failed:[0-9]\+" ../workflow/ligand-collections/done/$folder1/$folder2/* 2>/dev/null | awk -F ':' '{print $2}' | sed "/^$/d" | paste -sd+ | bc -l 2>/dev/null || true)"
            if [[ -z "${ligands_failed_to_add// }" ]]; then
                ligands_failed_to_add=0
            fi
            ligands_failed=$((ligands_failed + ligands_failed_to_add))
        done
    done
    echo " Number of ligands failed: ${ligands_failed}"

    echo
    echo

    echo "                                Dockings (in completed collections)   "
    echo "................................................................................................"
    echo
    echo " Docking runs per ligand: ${docking_runs_perligand}"

    dockings_started=0
    for folder1 in $(find ../workflow/ligand-collections/done/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/done/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            dockings_started_to_add="$(grep -ho "Dockings-started:[0-9]\+" ../workflow/ligand-collections/done/$folder1/$folder2/* 2>/dev/null | awk -F ':' '{print $2}' | sed "/^$/d" |  paste -sd+ | bc -l 2>/dev/null || true)"
            if [[ -z "${dockings_started_to_add// }" ]]; then
                dockings_started_to_add=0
            fi
            dockings_started=$((dockings_started + dockings_started_to_add))
        done
    done
    echo " Number of dockings started: ${dockings_started}"

    dockings_success=0
    for folder1 in $(find ../workflow/ligand-collections/done/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/done/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            dockings_success_to_add="$(grep -ho "Dockings-succeeded:[0-9]\+" ../workflow/ligand-collections/done/$folder1/$folder2/* 2>/dev/null | awk -F ':' '{print $2}' | sed "/^$/d" |  paste -sd+ | bc -l 2>/dev/null || true)"
            if [[ -z "${dockings_success_to_add// }" ]]; then
                dockings_success_to_add=0
            fi
            dockings_success=$((dockings_success + dockings_success_to_add))
        done
    done
    echo " Number of dockings successfully completed: ${dockings_success}"

    dockings_failed=0
    for folder1 in $(find ../workflow/ligand-collections/done/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
        for folder2 in $(find ../workflow/ligand-collections/done/$folder1/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n"); do
            dockings_failed_to_add="$(grep -ho "Dockings-failed:[0-9]\+" ../workflow/ligand-collections/done/$folder1/$folder2/* 2>/dev/null | awk -F ':' '{print $2}' | sed "/^$/d" | paste -sd+ | bc -l 2>/dev/null || true)"
            if [[ -z "${dockings_failed_to_add// }" ]]; then
                dockings_failed_to_add=0
            fi
            dockings_failed=$((dockings_failed + dockings_failed_to_add))
        done
    done
    echo " Number of dockings failed: ${dockings_failed}"

    echo
    echo
fi

# Displaying information about the results if desired
if [[ "${category}" = "vs" ]]; then
    echo
    echo
    echo "                              Preliminary Virtual Screening Results                             "
    echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    echo

    # Preparing the summary files and folders
    summary_folders=""
    rm -r ${tempdir} 2>/dev/null || true
    mkdir -p ${tempdir}

    # Complete collections
    folder=../output-files/complete/${docking_scenario_name}
    summary_flag="false"
    summary_folders="${tempdir}/output-files/${docking_scenario_name}/summaries/"
    if [ "${outputfiles_level}" == "tranche" ]; then
        if [ -d ${folder}/summaries/ ]; then
            if [ -n "$(ls -A ${folder}/summaries/)" ]; then
                summary_flag="true"
                for metatranch in $(ls ${folder}/summaries/ 2>/dev/null || true); do
                    mkdir -p ${tempdir}/output-files/${docking_scenario_name}/summaries/${metatranch}
                    for file in $(ls ${folder}/summaries/${metatranch}  2>/dev/null || true); do
                        tar -xf ${folder}/summaries/${metatranch}/${file} -C ${tempdir}/output-files/${docking_scenario_name}/summaries/${metatranch} || true
                    done
                done
                for metatranch in $(ls ${folder}/summaries/  2>/dev/null || true); do
                    for folder in $(ls ${tempdir}/output-files/${docking_scenario_name}/summaries/${metatranch}  2>/dev/null || true); do
                        folder=$(basename ${folder})
                        for file in $(ls ${tempdir}/output-files/${docking_scenario_name}/summaries/${metatranch}/${folder} 2>/dev/null || true); do
                            file=$(basename ${file} || true)
                            zcat ${tempdir}/output-files/${docking_scenario_name}/summaries/${metatranch}/${folder}/${file} 2>/dev/null | awk '{print $1, $2, $4}' >> ${tempdir}/summaries.all || true
                        done
                        rm -r ${tempdir}/output-files/${docking_scenario_name}/summaries/${metatranch}/${folder}
                    done
                done
            fi
        fi
    elif [ "${outputfiles_level}" == "collection" ]; then
        for metatranch in $(ls -A ${folder}/summaries/); do
            for tranch in $(ls -A ${folder}/summaries/${metatranch}); do
                for file in $(ls -A ${folder}/summaries/${metatranch}/${tranch}); do
                    zcat ${folder}/summaries/${metatranch}/${tranch}/${file} 2>/dev/null | awk '{print $1, $2, $4}' >> ${tempdir}/summaries.all 2>/dev/null || true
                    summary_flag="true"
                done
            done
        done
    else
        echo " * Error: The variable 'outputfiles_level' in the controlfile ${controlfile} has an invalid value (${outputfiles_level})"
        exit 1
    fi

    # Adding the incomplete collections
    folder=../output-files/incomplete/${docking_scenario_name}
    if [ -d ${folder}/summaries/ ]; then
        for metatranch in $(ls -A ${folder}/summaries/); do
            for tranch in $(ls -A ${folder}/summaries/${metatranch}); do
                for file in $(ls -A ${folder}/summaries/${metatranch}/${tranch}); do
                    zcat ${folder}/summaries/${metatranch}/${tranch}/${file}  2>/dev/null | awk '{print $1, $2, $4}' >> ${tempdir}/summaries.all 2>/dev/null || true
                    summary_flag="true"
                done
            done
        done
    fi

    # Checking if data already available
    if [[ "${summary_flag}" == "false" ]]; then
        echo -e "\nNo data yet available (probably all data still on the temporary filesystem). Try again later....\n\n\n"
        exit 0
    fi

    # Statistical information
    if [[ "${show_vs_statistics}" == "true" ]]; then
        # Printing some information
        echo
        echo "                                  Binding affinity - statistics    "
        echo "................................................................................................"
        echo
        # Classifying the scores
        for i in {0..23}; do
            ligands_no_tmp[i]=0
        done
        for folder in ${summary_folders}; do
            while IFS='' read -r line || [[ -n "$line" ]]; do
                read -a line_array <<< "${line}"
                if [ "${line_array[0]}" != "average-score" ] 2>/dev/null; then
                    score=${line_array[2]}
                    case $score in
                        [0-9]*)
                            ligands_no_tmp[23]=$((ligands_no_tmp[23] +1))
                            ;;
                        -[0-4].*)
                            ligands_no_tmp[0]=$((ligands_no_tmp[0] +1))
                            ;;
                        -5.[0-4])
                            ligands_no_tmp[1]=$((ligands_no_tmp[1] +1))
                            ;;
                        -5.[5-9])
                            ligands_no_tmp[2]=$((ligands_no_tmp[2] +1))
                            ;;
                        -6.[0-4])
                            ligands_no_tmp[3]=$((ligands_no_tmp[3] +1))
                            ;;
                        -6.[5-9])
                            ligands_no_tmp[4]=$((ligands_no_tmp[4] +1))
                            ;;
                        -7.[0-4])
                            ligands_no_tmp[5]=$((ligands_no_tmp[5] +1))
                            ;;
                        -7.[5-9])
                            ligands_no_tmp[6]=$((ligands_no_tmp[6] +1))
                            ;;
                        -8.[0-4])
                            ligands_no_tmp[7]=$((ligands_no_tmp[7] +1))
                            ;;
                        -8.[5-9])
                            ligands_no_tmp[8]=$((ligands_no_tmp[8] +1))
                            ;;
                        -9.[0-4])
                            ligands_no_tmp[9]=$((ligands_no_tmp[9] +1))
                            ;;
                        -9.[5-9])
                            ligands_no_tmp[10]=$((ligands_no_tmp[10] +1))
                            ;;
                        -10.[0-4])
                            ligands_no_tmp[11]=$((ligands_no_tmp[11] +1))
                            ;;
                        -10.[5-9])
                            ligands_no_tmp[12]=$((ligands_no_tmp[12] +1))
                            ;;
                        -11.[0-4])
                            ligands_no_tmp[13]=$((ligands_no_tmp[13] +1))
                            ;;
                        -11.[5-9])
                            ligands_no_tmp[14]=$((ligands_no_tmp[14] +1))
                            ;;
                        -12.[0-4])
                            ligands_no_tmp[15]=$((ligands_no_tmp[15] +1))
                            ;;
                        -12.[5-9])
                            ligands_no_tmp[16]=$((ligands_no_tmp[16] +1))
                            ;;
                        -13.[0-4])
                            ligands_no_tmp[17]=$((ligands_no_tmp[17] +1))
                            ;;
                        -13.[5-9])
                            ligands_no_tmp[18]=$((ligands_no_tmp[18] +1))
                            ;;
                        -14.[0-4])
                            ligands_no_tmp[19]=$((ligands_no_tmp[19] +1))
                            ;;
                        -14.[5-9])
                            ligands_no_tmp[20]=$((ligands_no_tmp[20] +1))
                            ;;
                        -1[5-9].*)
                            ligands_no_tmp[21]=$((ligands_no_tmp[21] +1))
                            ;;
                        -[2-9][0-9]*)
                            ligands_no_tmp[22]=$((ligands_no_tmp[22] +1))
                            ;;
                    esac
                fi
            done < "${tempdir}/summaries.all"
        done
        # Printing the scores
        echo " Number of ligands screened with binding affinity between     0  and   inf kcal/mole: ${ligands_no_tmp[23]}"
        echo " Number of ligands screened with binding affinity between  -0.1  and  -5.0 kcal/mole: ${ligands_no_tmp[0]}"
        echo " Number of ligands screened with binding affinity between  -5.0  and  -5.5 kcal/mole: ${ligands_no_tmp[1]}"
        echo " Number of ligands screened with binding affinity between  -5.5  and  -6.0 kcal/mole: ${ligands_no_tmp[2]}"
        echo " Number of ligands screened with binding affinity between  -6.0  and  -6.5 kcal/mole: ${ligands_no_tmp[3]}"
        echo " Number of ligands screened with binding affinity between  -6.5  and  -7.0 kcal/mole: ${ligands_no_tmp[4]}"
        echo " Number of ligands screened with binding affinity between  -7.0  and  -7.5 kcal/mole: ${ligands_no_tmp[5]}"
        echo " Number of ligands screened with binding affinity between  -7.5  and  -8.0 kcal/mole: ${ligands_no_tmp[6]}"
        echo " Number of ligands screened with binding affinity between  -8.0  and  -8.5 kcal/mole: ${ligands_no_tmp[7]}"
        echo " Number of ligands screened with binding affinity between  -8.5  and  -9.0 kcal/mole: ${ligands_no_tmp[8]}"
        echo " Number of ligands screened with binding affinity between  -9.0  and  -9.5 kcal/mole: ${ligands_no_tmp[9]}"
        echo " Number of ligands screened with binding affinity between  -9.5  and -10.0 kcal/mole: ${ligands_no_tmp[10]}"
        echo " Number of ligands screened with binding affinity between -10.0  and -10.5 kcal/mole: ${ligands_no_tmp[11]}"
        echo " Number of ligands screened with binding affinity between -10.5  and -11.0 kcal/mole: ${ligands_no_tmp[12]}"
        echo " Number of ligands screened with binding affinity between -11.0  and -11.5 kcal/mole: ${ligands_no_tmp[13]}"
        echo " Number of ligands screened with binding affinity between -11.5  and -12.0 kcal/mole: ${ligands_no_tmp[14]}"
        echo " Number of ligands screened with binding affinity between -12.0  and -12.5 kcal/mole: ${ligands_no_tmp[15]}"
        echo " Number of ligands screened with binding affinity between -12.5  and -13.0 kcal/mole: ${ligands_no_tmp[16]}"
        echo " Number of ligands screened with binding affinity between -13.0  and -13.5 kcal/mole: ${ligands_no_tmp[17]}"
        echo " Number of ligands screened with binding affinity between -13.5  and -14.0 kcal/mole: ${ligands_no_tmp[18]}"
        echo " Number of ligands screened with binding affinity between -14.0  and -14.5 kcal/mole: ${ligands_no_tmp[19]}"
        echo " Number of ligands screened with binding affinity between -14.5  and -15.0 kcal/mole: ${ligands_no_tmp[20]}"
        echo " Number of ligands screened with binding affinity between -15.0  and -20.0 kcal/mole: ${ligands_no_tmp[21]}"
        echo " Number of ligands screened with binding affinity between -20.0  and  -inf kcal/mole: ${ligands_no_tmp[22]}"
    fi

    # Printing the scores of the hightest scoring compounds
    if [[ "${number_highest_scores}" -gt "0" ]]; then
        echo
        echo
        echo "                          Binding affinity - highest scoring compounds    "
        echo "................................................................................................"
        echo
        ( echo -e "\n      Rank       Ligand           Collection       Highest-Score\n" & (zgrep -v "average-score" ${tempdir}/summaries.all 2>/dev/null ) | sort -T ${tempdir} -S 80% -k 3,3 -n | head -n ${number_highest_scores} | sed "s/\.txt//g" | awk -F '[: /]+' '{printf "    %5d    %10s     %s            %5.1f\n", NR, $2, $1, $3}' ) | column -t | sed "s/^/       /g" | sed "s/Score$/Score\n/g" # awk counts also the empty column in the beginning since there is a backslash
    fi
fi

echo -e "\n\n"