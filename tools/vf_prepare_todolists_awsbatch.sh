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

export VF_CONTROLFILE="../workflow/control/all.ctrl"

export VF_TMPDIR="$(grep -m 1 "^tempdir_default=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_TMPDIR_FAST="$(grep -m 1 "^tempdir_fast=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_JOBLETTER="$(grep -m 1 "^job_letter=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_JOBLINE_NO=0

export max_batch_chunk="$(grep -m 1 "^aws_batch_array_job_size=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

# Creating the working directory
mkdir -p ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/${VF_JOBLINE_NO}/prepare-todolists/

# Copying the control to temp
vf_controlfile_temp=${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/${VF_JOBLINE_NO}/prepare-todolists/controlfile
cp ${VF_CONTROLFILE} ${vf_controlfile_temp}

# Variables
collection_folder="$(grep -m 1 "^collection_folder=" ${vf_controlfile_temp} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
collection_folder=${collection_folder%/}
ligands_todo_per_queue="$(grep -m 1 "^ligands_todo_per_queue=" ${vf_controlfile_temp} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
ligands_per_refilling_step="$(grep -m 1 "^ligands_per_refilling_step=" ${vf_controlfile_temp} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
initial_todolist=true

batchsystem="$(grep -m 1 "^batchsystem=" ${vf_controlfile_temp} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_type="$(grep -m 1 "^object_store_type=" ${vf_controlfile_temp} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_bucket="$(grep -m 1 "^object_store_bucket=" ${vf_controlfile_temp} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_job_data="$(grep -m 1 "^object_store_job_data_prefix=" ${vf_controlfile_temp} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

min_items=${ligands_per_refilling_step}

batch_chunk=1
queue_number=1
total_items=0

if [ -d ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/input ]; then
	rm -r ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/input
fi
mkdir -p ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/input


create_workunit() {
	if [ -d ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks ]; then
		rm -rf ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks
	fi
	mkdir -p ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks

	workunit_total_ligands=0
}

finish_workunit() {

	if [ "${queue_number}" -gt "0" ]; then
		pushd ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER} > /dev/null

        	mkdir -p input

		if [ -f vf_tasks.tar.gz ]; then
			rm vf_tasks.tar.gz
		fi

		tar cf vf_tasks.tar vf_tasks
		gzip vf_tasks.tar

        	mv vf_tasks.tar.gz  input/${batch_chunk}.tar.gz

		popd > /dev/null

		mkdir -p ../workflow/workunits
		echo "${queue_number}" > ../workflow/workunits/${batch_chunk}

		average_size=$((workunit_total_ligands / queue_number))
		echo "${queue_number}" > ../workflow/workunits/${batch_chunk}
		echo "${average_size}" > ../workflow/workunits/${batch_chunk}.size

		echo "Finished ${batch_chunk}"
		((batch_chunk++))
	fi

}

increment_queue() {


	if [ "${queue_number}" -eq "${max_batch_chunk}" ]; then
		finish_workunit
		create_workunit
		queue_number=1
	else
		((queue_number++))
	fi 

}

if [[ "${batchsystem}" != "AWSBATCH" ]]; then

    # Printing some information
    echo
    echo "This script is used only when the batch scheduler is set to AWSBATCH (currently set to '${batchsystem}')"
    echo
    exit
fi

if [[ "${object_store_type}" != "s3" ]]; then

    # Printing some information
    echo
    echo "S3 is required as the object store when using AWS Batch as the scheduler"
    echo
    exit
fi


rm ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/tmp-workunit
create_workunit
queue_number=1

for file in $(ls -d ../workflow/ligand-collections/todo/todo.all.*);
do
	echo "Processing from ${file}...."
	while read -r line
	do
		items=$(echo "$line" | awk '{print $2}')

		if [ ${items} -ge ${min_items} ]; then
			echo "$line" >> "${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks/${queue_number}"
			echo "${items}" >> "${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks/${queue_number}.ligand_count"
			workunit_total_ligands=$((workunit_total_ligands + items))
			increment_queue
		else
			total_items=$((total_items+items))

			echo $line >> ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/tmp-workunit

			if [ ${total_items} -ge ${min_items} ]; 
			then
				mv ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/tmp-workunit  ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks/${queue_number}
				echo "${total_items}" >> "${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks/${queue_number}.ligand_count"
				workunit_total_ligands=$((workunit_total_ligands + total_items))
				increment_queue
				total_items=0
			fi
		fi

	done < "${file}"
done

if [ -f ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/tmp-workunit ]; then
	lines_in_tmp=$(wc -l ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/tmp-workunit)
	if [ ${total_items} -gt 0 ]; then
		mv ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/tmp-workunit  ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks/${queue_number}
		echo "${total_items}" >> "${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/vf_tasks/${queue_number}.ligand_count"
		increment_queue
	fi
fi

finish_workunit


cd ${VF_TMPDIR_FAST}/${USER}/VFVS/${VF_JOBLETTER}/input
aws s3 sync . s3://${object_store_bucket}/${object_store_job_data}/input/tasks/
cd -


batch_chunk=$((batch_chunk - 1))
echo "${batch_chunk} joblines created"

# Clean up


