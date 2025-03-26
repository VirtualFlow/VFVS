#!/bin/sh

#Checking the input arguments
usage="Usage: vfvs_prepare_atg-primary-screen-folders.sh screening_sizes:<size 1>,<size 2>,... replica_counts:<replica count 1>,<replica count 2>,... <docking method>

Description: Preparing the folders for the ATG Primary Screens folders. For each docking scenario, and each specified screening size and replica count, one ATG Primary Screen folder will be created. Before running this script, the todo files have to be prepared for each screening size.

Arguments:
    screening_sizes:<size 1>:<size 2>:...: Number of ligands that should be screened in the ATG Primary Screen. Multiple sizes can be specified if multiple ATG Primary Screens are planned to be run with different screening sizes.
    replica_counts:<replica count 1>,<replica count 2>,... Replica counts that should be used in the ATG Primary Screen. Multiple counts can be specified if multiple ATG Primary Screens are planned to be run with different replica counts.
    <docking method>: The docking program to be used.
"

# Checking arguments
if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -ne "3" ]; then
   echo -e "\nWrong number of arguments. Three arguments are required."
   echo -e "\n${usage}\n\n"
   echo -e "Exiting..."
   exit 1
fi


# Extract the arguments
screening_sizes="$1"
replica_counts="$2"
docking_scenario_method="$3"

# Checking argument contents
# First argument
if [[ "$screening_sizes" == screening_sizes:* ]]; then
  # Remove the "size:" prefix
  screening_sizes=${screening_sizes#screening_sizes:}

  # Convert the comma-separated sizes into an array
  IFS=',' read -r -a screening_sizes <<< "$screening_sizes"
else
  echo "Error: First argument does not start with 'screening_sizes:'. Exiting..."
  exit 1
fi
# Second argument
if [[ "$replica_counts" == replica_counts:* ]]; then
  # Remove the "size:" prefix
  replica_counts=${replica_counts#replica_counts:}

  # Convert the comma-separated sizes into an array
  IFS=',' read -r -a replica_counts <<< "$replica_counts"
else
  echo "Error: Second argument does not start with 'replica_counts:'. Exiting..."
  exit 1
fi

# Initial setup
cd ../output-files
echo

# Prepare next stage foldersparent_dir=$(basename $(dirname $(pwd)))
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do
  for screening_size in "${screening_sizes[@]}"; do
    for replica_count in "${replica_counts[@]}"; do
      new_vf_root_folder="../../atg-primaryscreen_${ds}_${screening_size}_repl${replica_count}"
      echo "Creating new VF directory (${new_vf_root_folder}) for the ATG Primary Screen of docking scenrio ${ds} for screening size ${screening_size}, and ${replica_count} replicas"
      mkdir ${new_vf_root_folder}
      mkdir ${new_vf_root_folder}/input-files/
      cp -r ../.git* ../tools/ ${new_vf_root_folder}/
      cp -r ../input-files/receptors/ ${new_vf_root_folder}/input-files/
      cp -r ../input-files/${ds}/ ${new_vf_root_folder}/input-files/
      echo "Copying the newly created todo file for docking scenario ${ds}: cp ../output-files/${ds}.todo.${screening_size} ${new_vf_root_folder}/tools/templates/todo.all"
      cp ../output-files/${ds}.todo.${screening_size} ${new_vf_root_folder}/tools/templates/todo.all
      echo "Setting job_name in the all.ctrl file to atg-primaryscreen_${ds}_${screening_size}_repl${replica_count}"
      sed -i "s/job_name=.*/job_name=atg-primaryscreen_${ds}_${screening_size}_repl${replica_count}/g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo "Setting data_collection_identifier in the all.ctrl file to Enamine_REAL_Space_2022q12"
      sed -i "s|data_collection_identifier=.*|data_collection_identifier=Enamine_REAL_Space_2022q12|g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo "Setting prescreen_mode in the all.ctrl file to 0"
      sed -i "s|prescreen_mode=.*|prescreen_mode=0|g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo "Setting dynamic_tranche_filtering in the all.ctrl file to 0"
      sed -i "s|dynamic_tranche_filtering=.*|dynamic_tranche_filtering=0|g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo "Setting docking_scenario_names in the all.ctrl file to ${ds}"
      sed -i "s|docking_scenario_names=.*|docking_scenario_names=${ds}|g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo "Setting docking_scenario_batchsizes in the all.ctrl file to 1"
      sed -i "s|docking_scenario_batchsizes=.*|docking_scenario_batchsizes=1|g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo "Setting docking_scenario_replicas in the all.ctrl file to ${replica_count}"
      sed -i "s|docking_scenario_replicas=.*|docking_scenario_replicas=${replica_count}|g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo "Setting docking_scenario_methods in the all.ctrl file to ${docking_scenario_method}"
      sed -i "s|docking_scenario_methods=.*|docking_scenario_methods=${docking_scenario_method}|g" ${new_vf_root_folder}/tools/templates/all.ctrl
      echo
    done
  done
done

# Changing to original directory
echo
cd ../tools

#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do ( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_prepare_folders.py ) ;  done; done
#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do echo "( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_prepare_workunits.py )" ; done; done | parallel -j 10 --ungroup
#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do ( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_build_docker.sh ) ; done; done
#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do ( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_submit_jobs.py 1 500 ) ; done; done

