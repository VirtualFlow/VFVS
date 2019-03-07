#!/bin/bash
# ---------------------------------------------------------------------------
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-03-06  Small improvements (version 2.3)
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------

# Displaying help if the first argument is -h
usage="Usage: . vf_prepare_folders.sh
"

if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi

if [[ "$#" -ne "0" ]]; then

    # Printing some information
    echo
    echo "The wrong number of arguments was provided."
    echo "Number of expected arguments: 0"
    echo "Number of provided arguments: ${#}"
    echo "Use the -h option to display basic usage information of the command."
    echo
    echo
    exit 1
fi

# Preparing the output-files folder
# Getting user confirmation
echo
while true; do
    read -p "Do you really wish prepare/reset the output-files folder? " answer
    case ${answer} in
        [Yy]* ) confirm="yes"; break;;
        [Nn]* ) confirm="no"; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Preparing the folder
if [ "${confirm}" = "yes" ]; then

    # Printing some information
    echo
    echo " * Preparing the output-files folder..."

    # Removing the folder if it exists
    if [ "$(ls -A ../output-files 2>/dev/null)" ]; then
        rm -r ../output-files/* 2>/dev/null
    fi

    # Creating the directory
    mkdir -p ../output-files/
fi

# Preparing the workflow folder
# Getting user confirmation
echo
while true; do
    read -p "Do you really wish to prepare/reset the workflow folder? " answer
    case ${answer} in
        [Yy]* ) confirm="yes"; break;;
        [Nn]* ) confirm="no"; break;;
        * ) echo "Please answer \"yes\" or \"no\".";;
    esac
done

# Preparing the folder
if [ "${confirm}" = "yes" ]; then

    # Printing some information
    echo
    echo " * Preparing the workflow folder..."

    # Removing the folders if they exists and creating new ones
    if [ "$(ls -A ../workflow/ligand-collections/todo/ 2>/dev/null)" ]; then
        rm -r ../workflow/ligand-collections/todo/ 2>/dev/null
    fi
    mkdir -p ../workflow/ligand-collections/todo/

    if [ "$(ls -A ../workflow/ligand-collections/current/ 2>/dev/null)" ]; then
        rm -r ../workflow/ligand-collections/current/ 2>/dev/null
    fi
    mkdir -p ../workflow/ligand-collections/current/

    if [ "$(ls -A ../workflow/ligand-collections/done/ 2>/dev/null)" ]; then
        rm -r ../workflow/ligand-collections/done/ 2>/dev/null
    fi
    mkdir -p ../workflow/ligand-collections/done/

    if [ "$(ls -A ../workflow/ligand-collections/ligand-lists/ 2>/dev/null)" ]; then
        rm -r ../workflow/ligand-collections/ligand-lists/ 2>/dev/null
    fi
    mkdir -p ../workflow/ligand-collections/ligand-lists/

    if [ "$(ls -A ../workflow/ligand-collections/var/ 2>/dev/null)" ]; then
        rm -r ../workflow/ligand-collections/var/ 2>/dev/null
    fi
    mkdir -p ../workflow/ligand-collections/var/

    if [ "$(ls -A ../workflow/output-files/jobs/ 2>/dev/null)" ]; then
        rm -r ../workflow/output-files/jobs/ 2>/dev/null
    fi
    mkdir -p ../workflow/output-files/jobs/

    if [ "$(ls -A ../workflow/output-files/queues/ 2>/dev/null)" ]; then
        rm -r ../workflow/output-files/queues/ 2>/dev/null
    fi
    mkdir -p ../workflow/output-files/queues/

    if [ "$(ls -A ../workflow/job-files/main/ 2>/dev/null)" ]; then
        rm -r ../workflow/job-files/main/ 2>/dev/null
    fi
    mkdir -p ../workflow/job-files/main/

    if [ "$(ls -A ../workflow/job-files/sub/ 2>/dev/null)" ]; then
        rm -r ../workflow/job-files/sub/ 2>/dev/null
    fi
    mkdir -p ../workflow/job-files/sub/

    if [ "$(ls -A ../workflow/control/ 2>/dev/null)" ]; then
        rm -r ../workflow/control/ 2>/dev/null
    fi
    mkdir -p ../workflow/control/

    # Copyinng the templates
    . slave/copy-templates.sh all
fi

