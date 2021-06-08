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

# ---------------------------------------------------------------------------
#
# Description: Bash script for virtual screening of ligands with AutoDock Vina.
#
# ---------------------------------------------------------------------------

env_file=${1}
next_ligand=${2}
docking_scenario_name=${3}
docking_scenario_program=${4}
docking_scenario_inputfolder=${5}
docking_replica_index=${6}
docking_scenario_index=${7}
docking_scenario_index_end=${8}
docking_replica_index_end=${9}

source ${env_file}

mkdir -p ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}

/opt/vf/tools/templates/single_run.sh "$@" > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.output  2>&1
#/opt/vf/tools/templates/single_run.sh "$@" > ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/logs/${docking_scenario_name}/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.output  2>&1

