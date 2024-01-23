#!/bin/sh

#Checking the input arguments
usage="Usage: vfvs_prepare_atg-primaryscreen-screen.sh <jobname prefix> <size 1> <size 2> ...

Description: Preparing the folders for the ATG Primary Screens. For each docking scenario, and each specified screening size, one ATG Primary Screen folder will be created. The ATG Prescreen has to be postprocessed (with the command vfvs_postprocess_atg-prescreen.sh) before running this command with the same screening sizes. 

Arguments:
    <jobname prefix>: String that is used as prefix in the job output folders, e.g. abl1-vs1
    <size N>: Number of ligands that should be screened in the ATG Primary Screen. Multiple sizes can be spcified if multiple ATG Primary Screens are planned to be run with different screening sizes. N is typically set to 10000000 (10M) or 100000000 (100M)
"

if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -le "1" ]; then
   echo -e "\nWrong number of arguments. At two arguments are required."
   echo -e "\n${usage}\n\n"
   echo -e "Exiting..."
   exit 1
fi


# Prepare next stage foldersparent_dir=$(basename $(dirname $(pwd)))
prefix=$1
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do mkdir ../../atg-primaryscreen_${size}_${ds} ; cp -vr ../.git* ../input-files/ ../tools/ ../../atg-primaryscreen_${size}_${ds} ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s/job_name=.*/job_name=${prefix}-atg-primaryscreen_${size}_${ds}/g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s|athena_s3_location=.*|athena_s3_location=s3://sj-bskldt-useast2/VF2/VFVS/jobs/${prefix}-atg-primaryscreenq_${size}_${ds}/athena|g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s|data_collection_identifier=.*|data_collection_identifier=Enamine_REAL_Space_2022q12|g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s|sensor_screen_mode=.*|sensor_screeen_mode=0|g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s|docking_scenario_names=.*|docking_scenario_names=${ds}|g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s|docking_scenario_batchsizes=.*|docking_scenario_batchsizes=1|g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s|docking_scenario_replicas=.*|docking_scenario_replicas=1|g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do sed -i "s|docking_scenario_programs=.*|docking_scenario_programs=qvina02|g" ../../atg-primaryscreen_${size}_${ds}/tools/templates/all.ctrl ; done; done
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do cp -v ../output-files/${ds}.all.todo.${size} ../../atg-primaryscreen_${size}_${ds}/tools/templates/todo.all ; done; done



#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do ( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_prepare_folders.py ) ;  done; done
#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do echo "( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_prepare_workunits.py )" ; done; done | parallel -j 10 --ungroup
#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do ( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_build_docker.sh ) ; done; done
#for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do for size in ${@:2}; do ( cd ../../atg-primaryscreen_${size}_${ds}/tools; ./vfvs_submit_jobs.py 1 500 ) ; done; done
~

