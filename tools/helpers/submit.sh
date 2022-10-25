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
# Usage: . submit jobfile [quiet]

# Description: Submits a new job.
#
# Option: quiet (optional)
#    Possible values:
#        quiet: No information is displayed on the screen.
#
# Revision history
# 2015-12-05  Created (version 1.2)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
# 2017-03-18  Removing the partition as an argument (instead including it in the control file)
#
# ---------------------------------------------------------------------------

# Displaying help if the first argument is -h
usage="# Usage: . submit jobfile [quiet]"
if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   return 0
fi
if [[ "$#" -ne "1" && "$#" -ne "2" ]]; then
   echo -e "\nWrong number of arguments. Exiting."
   echo -e "\n${usage}\n\n"
   return 1
fi
# Standard error response
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error." | tee -a /dev/stderr
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})" | tee -a /dev/stderr
    echo "Error on line $1" | tee -a /dev/stderr
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
# Getting the batchsystem type
batchsystem="$(grep -m 1 "^batchsystem=" ../${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
jobfile=${1}
jobline=$(echo ${jobfile} | awk -F '[./]' '{print $(NF-1)}')

# Submitting the job
cd ../
if [ "${batchsystem}" == "SLURM" ]; then
    sbatch ${jobfile}
elif [[ "${batchsystem}" = "TORQUE" ]] || [[ "${batchsystem}" = "PBS" ]]; then
    msub ${jobfile}
elif [ "${batchsystem}" == "SGE" ]; then
    qsub ${jobfile}
elif [ "${batchsystem}" == "LSF" ]; then
    bsub < ${jobfile}
else
    echo
    echo "Error: The batch system (${batchsystem}) which was specified in the control file (${VF_CONTROLFILE}) is not supported."
    echo
    exit 1
fi

# Changing the directory
cd helpers

# Printing some information
if [ ! "$*" = *"quiet"* ]; then
    echo "The job for jobline ${jobline} has been submitted at $(date)."
    echo
fi
