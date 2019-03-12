#!/bin/bash

# Copyright (C) 2019 Christoph Gorgulla
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
# Usage: . exchange-continue-jobline first_jobline_no last_jobline_no job_template [quiet]
#
# Description: Exchange jobfiles and continue a jobline which was already started.
#
# Option: quiet (optional)
#    Possible values:
#        quiet: No information is displayed on the screen.
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------
# Displaying help if the first argument is -h
usage="Usage: . exchange-continue-jobline first_jobline_no last_jobline_no job_template [quiet]"
if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [[ "$#" -ne "3" && "$#" -ne "4" ]]; then
   echo -e "\nWrong number of arguments. Exiting."
   echo -e "\n${usage}\n\n"
   exit 1
fi

# Standard error response
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
i=0
first_jobline_no=${1}
last_jobline_no=${2}
job_template=${3}
if [ -z  "${4}" ]; then
    quiet_mode="off"
else
    quiet_mode=${4}
fi

# Continuing the jobline
for jobline_no in $(seq ${first_jobline_no} ${last_jobline_no}); do
    i=$(( i + 1 ))
    . exchange-jobfile.sh ${job_template} ${jobline_no} ${quiet_mode}
    . continue-jobline.sh ${jobline_no} "sync"
done

# Displaying some information if no quiet option
if [[ ! "$*" = *"quiet"* ]]; then
    echo
    echo "Number of joblines which were continued: ${i}"
    echo
fi
