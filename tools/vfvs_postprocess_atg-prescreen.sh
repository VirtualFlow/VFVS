#!/bin/sh

#Checking the input arguments
usage="Usage: vfvs_postprocess_atg-prescreen.sh <size 1> <size 2> ...

Description: Postprocessing the ATG Prescreen, and preparing the todo files for the ATG Primary Screens. The script can handle multiple docking scenarios in the ATG Prescreen.

Arguments:
    <size N>: Number of ligands that should be screened in the ATG Primary Screen. Multiple sizes can be spcified if multiple ATG Primary Screens are planned to be run with different screening sizes. N is typically set to 10000000 (10M) or 100000000 (100M)
"

if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -e "0" ]; then
   echo -e "\nWrong number of arguments. At least one screening size required."
   echo -e "\n${usage}\n\n"
   echo -e "Exiting..."
   exit 1
fi

# Output-files directory
mkdir -p ../output-files
cd ../output-files

# Getting the CSV files with the ligand rankings
for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do ../tools/vfvs_get_top_results.py --scenario-name $ds --download ; done

# Cleaning the CSV files
for file in *csv; do awk -F ',' '{print $2,$1,$5}' $file | tr -d '"' > ${file/csv/clean.txt} & done

wait 

# Getting the score averages for each tranche
for file in *clean.txt; do for i in {0..17}; do for a in {A..F}; do echo -n "${i},${a}," ;  grep -E "^.{$i}$a" $file | awk '{ total += $NF; count++ } END { print total/count }' || echo; done; done | sed "1i\Tranche,Class,Score" | tee ${file//.*}.sparse-metrics & done

wait

# Generating new todo files for the ATG Primary Screens
# requires conda 
for size in $@; do for file in *sparse-metrics; do echo python ~/scripts/vfvs_atg_prepare_stage1.py $file ~/Enamine_REAL_Space_2022q12.todo.csv ~/Enamine_REAL_Space_2022q12.count.csv ${file/.*}.all.todo.$size $size ; done ; done | parallel -j 10

wait

cd ../tools
