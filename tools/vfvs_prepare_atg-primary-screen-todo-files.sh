#!/bin/sh

#Checking the input arguments
usage="Usage: vfvs_prepare_atg-primary-screen-todo-files.sh -m <tranche scoring method> [-r <tranche_filter_regex>] -s <size 1>:<size 2>:...

Description: Preparing the folders for the ATG Primary Screens. For each docking scenario, and each specified screening size, one ATG Primary Screen folder will be created. The ATG Prescreen has to be postprocessed (with the command vfvs_postprocess_atg-prescreen.sh) before running this command with the same screening sizes. The command will take a large amount of memory. It is not recommended to run the command multiple times in parallel therefore on the same machine (unless you are sure you have enough memory).

Arguments:
    -m <tranche_scoring_mode>: dimension_averaging, tranche_min_score or tranche_ave_score
    -r <tranche_filter_regex>: Regex to allow filtering of tranches. Only tranches that match the regex will pass. Use ''.*'' if no filters should be applied.
    -s <size1>[:<size2>:...]: Number of ligands that should be screened in the ATG Primary Screen. Multiple sizes can be specified if multiple ATG Primary Screens are planned to be run with different screening sizes. N is typically set to 10000000 (10M) or 100000000 (100M). Multiple sizes are specified with a colon.
"
# Parse options
while getopts "m:r:s:h" opt; do
    case $opt in
        m) tranche_scoring_mode=$OPTARG ;;
        r) tranche_filter_regex=$OPTARG ;;
        s) IFS=":" read -r -a sizes <<< "$OPTARG" ;;
        h) echo -e "\n${usage}\n" ; exit 0 ;;
        *) echo -e "\nInvalid option: -$OPTARG\n" ; echo -e "${usage}\n" ; exit 1 ;;
    esac
done

# Checking arguments
if [ -z "$tranche_scoring_mode" ]; then
    echo -e "\nError: Tranche scoring mode is required.\n"
    echo -e "${usage}\n"
    exit 1
elif [ -z "$sizes" ]; then
    echo -e "\nError: Screening sizes are required.\n"
    echo -e "${usage}\n"
    exit 1
elif [ -z "$tranche_filter_regex" ]; then
    tranche_filter_regex=".................."
fi

# Initial setup
cd ../output-files
tranche_scoring_mode=$1
echo "Tranche scoring mode: ${tranche_scoring_mode}"
tranche_filter_regex=$2

# Getting the score averages for each tranche
if [ "${tranche_scoring_mode}" == "dimension_averaging" ]; then
  for ds in $(cat ../workflow/config.json  | jq -r ".docking_scenario_names" | tr "," " " | tr -d '"\n[]' | tr -s " "); do
    inputfile=${ds}.ranking.subset-1.csv.gz
    echo "Generating the dimension averaged tranche scores for docking scenario ${ds} and stored it in ../output-files/${ds}.dimension-averaged-activity-map.csv ..."
    for i in {0..17}; do
      for a in {A..F}; do
        echo -n "${i},${a},"
        zgrep -E "^.{$i}$a" ${inputfile} | awk -F ',' '{ total += $NF; count++ } END { print total/count }' || echo
      done
    done | sed "1i\Tranche,Class,Score" | tee ${ds}.dimension-averaged-activity-map.csv &
  done
fi
wait

# Generating new todo files for the ATG Primary Screens
# requires conda
if [ "${tranche_scoring_mode}" == "dimension_averaging" ]; then
  for size in "${sizes[@]}"; do
    for file in *dimension-averaged-activity-map.csv; do
      echo "echo Generating the todo file for the ATG Primary Screens for docking scenario ${file//.*} with ${size} ligands and storing it in ../output-files/${file/.*}.todo.$size ..."
      echo python ../tools/templates/create_todofile_atg-primaryscreen.py $file ~/Enamine_REAL_Space_2022q12.collections.parquet ~/Enamine_REAL_Space_2022q12.tranches.parquet ${tranche_scoring_mode} ${file/.*}.todo.$size $size
    done
  done | parallel -j 10
elif [[ "${tranche_scoring_mode}" == "tranche_min_score" ]] ||  [[ "${tranche_scoring_mode}" == "tranche_ave_score" ]] ; then
  for size in "${sizes[@]}"; do
    for file in *ranking.subset-1.csv.gz; do
      echo "echo Generating the todo file for the ATG Primary Screens for docking scenario ${file//.*} with ${size} ligands and storing it in ../output-files/${file/.*}.todo.$size ..."
      echo python ../tools/templates/create_todofile_atg-primaryscreen.py $file ~/Enamine_REAL_Space_2022q12.collections.parquet ~/Enamine_REAL_Space_2022q12.tranches.parquet ${tranche_scoring_mode} ${file/.*}.todo.$size $size $tranche_filter_regex
    done
  done | parallel -j 2 # depends on memory size mostly, each instance requires around 20GB of memory
fi
wait

cd ../tools
