#!/bin/bash
# ---------------------------------------------------------------------------
#
# Usage: . reset-folders.sh folders_to_reset [quiet]
#
# Description: Cleans the specified folders and resets them to the initial state.
#
# Option: folders_to_reset
#    Possible values: 
#        workflow: Cleans the workflow folder
#        output: Cleans the output-files folder
#        templates: Copies all the template files
#        all: Cleans the workflow and the output-files folder
#        none: no cleaning
#        Concatenating of the above values is possible, eg output-workflow
#
# Option: quiet (optional)
#    Possible values: 
#        quiet: No information is displayed on the screen.
#
# Revision history:
# 2015-12-05  Created (version 1.2)
# 2015-12-12  Various improvements (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-03-06  Small improvements (version 2.3)
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------

# Displaying help if the first argument is -h
usage="Usage: . reset-folders.sh folders_to_reset [quiet]"
if [ "${1}" = "-h" ]; then
    echo "${usage}"
    return
fi


# Resetting the output folder if specified
if [[ "$1" = *"output"* || "$1" = *"all"* ]]; then

    # Ask if really resetting the output folder
    echo
    while true; do
        read -p "Do you really wish clean the output folder? " answer
        case ${answer} in
            [Yy]* ) confirm="yes"; break;;
            [Nn]* ) confirm="no"; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    
    # Cleaning
    if [ "${confirm}" = "yes" ]; then
        if [[ ! "$*" = *"quiet"* ]]; then
            echo
            echo "Cleaning the output-files folder."
        fi
        if [ "$(ls -A ../../output-files 2>/dev/null)" ]; then
            rm -r ../../output-files/* 2>/dev/null
        fi
        mkdir -p ../../output-files/
    fi
fi

# Resetting the workflow folder if specified
if [[ "$1" = *"workflow"* || "$1" = *"all"* ]]; then
    # Ask if really resetting the workflow folder
    echo
    while true; do
        read -p "Do you really wish clean the workflow folder? " answer
        case ${answer} in
            [Yy]* ) confirm="yes"; break;;
            [Nn]* ) confirm="no"; break;;
            * ) echo "Please answer \"yes\" or \"no\".";;
        esac
    done
    
    # Cleaning
    if [ "${confirm}" = "yes" ]; then
        if [[ ! "$*" = *"quiet"* ]]; then
            echo
            echo "Cleaning the workflow folder."
        fi

        if [ "$(ls -A ../../workflow/ligand-collections/todo/ 2>/dev/null)" ]; then
            rm -r ../../workflow/ligand-collections/todo/ 2>/dev/null
        fi
        mkdir -p ../../workflow/ligand-collections/todo/

        if [ "$(ls -A ../../workflow/ligand-collections/current/ 2>/dev/null)" ]; then
            rm -r ../../workflow/ligand-collections/current/ 2>/dev/null
        fi
        mkdir -p ../../workflow/ligand-collections/current/

        if [ "$(ls -A ../../workflow/ligand-collections/done/ 2>/dev/null)" ]; then
            rm -r ../../workflow/ligand-collections/done/ 2>/dev/null
        fi
        mkdir -p ../../workflow/ligand-collections/done/

        if [ "$(ls -A ../../workflow/ligand-collections/ligand-lists/ 2>/dev/null)" ]; then
            rm -r ../../workflow/ligand-collections/ligand-lists/ 2>/dev/null
        fi
        mkdir -p ../../workflow/ligand-collections/ligand-lists/

        if [ "$(ls -A ../../workflow/ligand-collections/var/ 2>/dev/null)" ]; then
            rm -r ../../workflow/ligand-collections/var/ 2>/dev/null
        fi
        mkdir -p ../../workflow/ligand-collections/var/

        if [ "$(ls -A ../../workflow/output-files/jobs/ 2>/dev/null)" ]; then
            rm -r ../../workflow/output-files/jobs/ 2>/dev/null
        fi
        mkdir -p ../../workflow/output-files/jobs/

        if [ "$(ls -A ../../workflow/output-files/queues/ 2>/dev/null)" ]; then
            rm -r ../../workflow/output-files/queues/ 2>/dev/null
        fi
        mkdir -p ../../workflow/output-files/queues/

        if [ "$(ls -A ../../workflow/job-files/main/ 2>/dev/null)" ]; then
            rm -r ../../workflow/job-files/main/ 2>/dev/null
        fi
        mkdir -p ../../workflow/job-files/main/

        if [ "$(ls -A ../../workflow/job-files/sub/ 2>/dev/null)" ]; then
            rm -r ../../workflow/job-files/sub/ 2>/dev/null
        fi
        mkdir -p ../../workflow/job-files/sub/

        if [ "$(ls -A ../../workflow/control/ 2>/dev/null)" ]; then
            rm -r ../../workflow/control/ 2>/dev/null
        fi
        mkdir -p ../../workflow/control/
    fi
fi

# Copying the new template files
if [[ "$1" = *"templates"* || "$1" = *"all"* ]]; then
    # Ask if really copying the template files
    echo
    while true; do
        read -p "Do you really wish copy all the template files? " answer
        case ${answer} in
            [Yy]* ) confirm="yes"; break;;
            [Nn]* ) confirm="no"; break;;
            * ) echo "Please answer \"yes\" or \"no\".";;
        esac
    done
    
    # Cleaning
    if [ "${confirm}" = "yes" ]; then
        . copy-templates.sh all
    fi
fi
