#!/usr/bin/env python3

# Copyright (C) 2019 Christoph Gorgulla
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
# Description: Generate run files for AWS Batch
#
# Revision history:
# 2021-06-29  Original version
# 2022-01-18  Updating to allow for hash-based prefixes
# ---------------------------------------------------------------------------


import tempfile
import tarfile
import os
import json
import re
import boto3
import logging
import sys
from botocore.config import Config
from pathlib import Path
import shutil
import pathlib
import hashlib


def parse_config(filename):
    with open(filename, "r") as read_file:
        config = json.load(read_file)

    return config

def get_collection_list(filename):
    with open(filename, "r") as read_file:
        collections = json.load(read_file)

    return collections


def get_formatted_collection_number(collection_number):
    return f"{int(collection_number):07}"


def get_collection_hash(collection_name, collection_number):
    formatted_collection_number = get_formatted_collection_number(collection_number)
    string_to_hash = f"{collection_name}/{formatted_collection_number}"
    return hashlib.sha256(string_to_hash.encode()).hexdigest()


def publish_workunit(ctx, index, workunit_subjobs):

    temp_path = ctx['config']['tempdir_default']
    if(temp_path and temp_path != ""):
        temp_path = os.path.join(temp_path, '')
    else:
        temp_path = None

    # Create temporary directories
    temp_dir = tempfile.TemporaryDirectory(prefix=temp_path)
    temp_dir_tar = tempfile.TemporaryDirectory(prefix=temp_path)

    # Write out the config JSON information

    output_structure = {
        'config': ctx['config'],
        'subjobs': workunit_subjobs
    }

    with open(f'{temp_dir.name}/config.json', 'w') as json_out:
        json.dump(output_structure, json_out, indent=4)


    # We need to add in the input-files directory
    shutil.copytree(f"{ctx['config']['docking_scenario_basefolder']}", f"{temp_dir.name}/input-files")


    # Generate the tarball

    out = tarfile.open(f'{temp_dir_tar.name}/{index}.tar.gz', mode='x:gz')
    out.add(temp_dir.name, arcname="vf_input")
    out.close()

    if(ctx['config']['job_storage_mode'] == "s3"):

        if(ctx['config']['object_store_job_addressing_mode'] == "hash"):
            hash_string = get_collection_hash(ctx['config']['job_letter'], index)

            object_path = [
                ctx['config']['object_store_job_prefix'],
                hash_string[0:2],
                hash_string[2:4],
                ctx['config']['job_letter'],
                "input",
                "tasks",
                f"{index}.tar.gz"
            ]

        else:
            object_path = [
                ctx['config']['object_store_job_prefix_full'],
                "input",
                "tasks",
                f"{index}.tar.gz"
            ]

        object_name = "/".join(object_path)

        # Upload to S3

        try:
            response = ctx['s3'].upload_file(
                f'{temp_dir_tar.name}/{index}.tar.gz', ctx['config']['object_store_data_bucket'], object_name)
        except ClientError as e:
            logging.error(e)


        temp_dir.cleanup()
        temp_dir_tar.cleanup()

        return {'subjobs': compress_subjobs(ctx, workunit_subjobs), 's3_download_path': object_name}

    elif(ctx['config']['job_storage_mode'] == "sharedfs"):
        
        # TODO: Update the hash setup

        sharedfs_workunit_path = Path(ctx['config']['sharedfs_workunit_path']) / f"{index}.tar.gz"
        shutil.copyfile(f'{temp_dir_tar.name}/{index}.tar.gz', sharedfs_workunit_path)
        
        temp_dir.cleanup()
        temp_dir_tar.cleanup()

        return {'subjobs': compress_subjobs(ctx, workunit_subjobs), 'download_path': sharedfs_workunit_path.as_posix()}


def compress_subjobs(ctx, subjobs):
    new_subjobs = {}
    completions_per_ligand = get_dockings_per_ligand(ctx['config'])

    for subjob_id, subjob in subjobs.items():
        new_subjobs[subjob_id] = {
            'ligands_expected': 0
        }

        for collection_key, collection in subjob['collections'].items():
            new_subjobs[subjob_id]['ligands_expected'] += (collection['count'] * completions_per_ligand)

    return new_subjobs

def generate_subjob_init():

    subjob_init = {
        'collections': { 
        }
     }

    return subjob_init


def gen_s3_download_path(ctx, collection_name, collection_number):

    # Two different structures (hash-based on meta-tranche based)
    if(ctx['config']['object_store_data_collection_addressing_mode'] == "hash"):
        format_type = ctx['config']['ligand_library_format']

        hash_string = get_collection_hash(collection_name, int(collection_number))

        if(ctx['config']['object_store_data_collection_identifier'] != ""):
            remote_dir = [
                    ctx['config']['object_store_data_collection_prefix'],
                    hash_string[0:2],
                    hash_string[2:4],
                    ctx['config']['object_store_data_collection_identifier'],
                    format_type,
                    collection_name
                    ]
        else:
            remote_dir = [
                    ctx['config']['object_store_data_collection_prefix'],
                    hash_string[0:2],
                    hash_string[2:4],
                    format_type,
                    collection_name
                    ]

        # Remote path
        object_name = "/".join(remote_dir) + f"/{int(collection_number):07}.tar.gz"
        return object_name

    else:

        object_path = [
            ctx['config']['object_store_data_collection_prefix'],
            collection_name,
            f"{collection_number}.tar.gz"
        ]
        object_name = "/".join(object_path)

        return object_name


def gen_sharedfs_path(ctx, collection_name, collection_number):

    # Two different structures (hash-based on meta-tranche based)
    if(ctx['config']['object_store_data_collection_addressing_mode'] == "hash"):
        format_type = ctx['config']['ligand_library_format']

        hash_string = get_collection_hash(collection_name, int(collection_number))

        if(ctx['config']['object_store_data_collection_identifier'] != ""):
            remote_dir = [
                    ctx['config']['sharedfs_collection_path'],
                    hash_string[0:2],
                    hash_string[2:4],
                    ctx['config']['object_store_data_collection_identifier'],
                    format_type,
                    collection_name
                    ]
        else:
            remote_dir = [
                    ctx['config']['sharedfs_collection_path'],
                    hash_string[0:2],
                    hash_string[2:4],
                    format_type,
                    collection_name
                    ]

        # Remote path
        object_name = "/".join(remote_dir) + f"/{int(collection_number):07}.tar.gz"
        return object_name

    else:

        sharedfs_path = [
            ctx['config']['sharedfs_collection_path'],
            collection_name,
            f"{collection_number}.tar.gz"
        ]
        sharedfs_path_file = "/".join(sharedfs_path)
        return sharedfs_path_file


def add_collection_to_subjob(ctx, subjob, collection_key, collection_obj):

    dockings_per_ligand = get_dockings_per_ligand(ctx['config'])

    subjob['collections'][collection_key] = collection_obj

    collection_name, collection_number = collection_key.split("_", maxsplit=1)


    if(ctx['config']['job_storage_mode'] == "s3"):
        subjob['collections'][collection_key]['s3_bucket'] = ctx['config']['object_store_data_bucket']
        subjob['collections'][collection_key]['s3_download_path'] = gen_s3_download_path(ctx, collection_name, collection_number)

    elif(ctx['config']['job_storage_mode'] == "sharedfs"):
        subjob['collections'][collection_key]['sharedfs_path'] = gen_sharedfs_path(ctx, collection_name, collection_number)

    else:
        print(f"job_storage_mode must be either s3 or sharedfs (currently: {ctx['config']['job_storage_mode']})")
        exit(1)

    subjob['collections'][collection_key]['dockings'] = dockings_per_ligand * collection_obj['count']


def process(ctx):

    config = ctx['config']

    condense = {
        'summary': {
           'total_dockings' : 0,
           'docking_succeeded' : 0,
           'docking_failed' : 0,
           'skipped_ligands' : 0,
           'vcpu_seconds': 0,
           'vcpu_seconds_interrupted': 0,
           'failed_downloads': 0,
           'failed_downloads_dockings': 0
        },
        'workunits': {}
    }


    dockings_per_ligand = get_dockings_per_ligand(config)

    workunits = condense['workunits']

    current_workunit_index = 1
    current_workunit_subjobs = {}
    current_subjob_index = 0

    leftover_count = 0
    leftover_subjob = generate_subjob_init()

    counter = 0
    collections = get_collection_list("../workflow/collections.json")
    total_lines = len(collections)

    print("Generating jobfiles....")

    # Max array size depends on if we are using Batch or Slurm

    if(config['batchsystem'] == "awsbatch"):
        max_array_job_size = int(config['aws_batch_array_job_size'])
    elif(config['batchsystem'] == "slurm"):
        max_array_job_size = int(config['slurm_array_job_size'])


    for collection_key, collection_obj in collections.items():

        collection_count = collection_obj['count'] * dockings_per_ligand

        if(collection_count >= int(config['dockings_per_subjob'])):
            current_workunit_subjobs[current_subjob_index] = generate_subjob_init()
            add_collection_to_subjob(
                ctx,
                current_workunit_subjobs[current_subjob_index],
                collection_key,
                collection_obj
                )

            current_subjob_index += 1
        else:
            # add it to the 'leftover pile'
            leftover_count += collection_count

            add_collection_to_subjob(
                ctx,
                leftover_subjob,
                collection_key,
                collection_obj
                )

            if(leftover_count >= int(config['dockings_per_subjob'])):
                # current_workunit.append(leftover_subjob)
                current_workunit_subjobs[current_subjob_index] =  leftover_subjob

                current_subjob_index += 1
                leftover_subjob = generate_subjob_init()
                leftover_count = 0

        if(len(current_workunit_subjobs) == max_array_job_size):
            workunits[current_workunit_index] = publish_workunit(ctx, current_workunit_index,
                             current_workunit_subjobs)

            current_workunit_index += 1
            current_subjob_index = 0
            current_workunit_subjobs = {}

        counter += 1

        if(counter % 50 == 0):
            percent = (counter / total_lines) * 100
            print(f"* {percent: .2f}% ({counter}/{total_lines})", file=sys.stderr)

    # If we have leftovers -- process them
    if(leftover_count > 0):
        current_workunit_subjobs[current_subjob_index] = leftover_subjob

    # If the current workunit has any items in it, we need to publish it
    if(len(current_workunit_subjobs) > 0):
        workunits[current_workunit_index] = publish_workunit(ctx,current_workunit_index, current_workunit_subjobs)
    else:
        # This is so we print the number of completed workunits at the end
        current_workunit_index -= 1



    # Condense to only what we need
    print("Writing json")


    # Output all of the information about the workunits into JSON so we can easily grab this data in the future
    with open("../workflow/status.json", "w") as json_out:
        json.dump(condense, json_out)

    os.system('cp ../workflow/status.json ../workflow/status.todolists.json')

    print(f"Generated {current_workunit_index} workunits")


def get_dockings_per_ligand(config):

    completions_per_ligand = 0
    for scenario_key, scenario in config['docking_scenarios_internal'].items():
        for replica_index in range(scenario['replicas']):
            completions_per_ligand += 1

    return completions_per_ligand


def main():

    ctx = {}
    ctx['config'] = parse_config("../workflow/config.json")
    aws_config = Config(
        region_name=ctx['config']['aws_region']
    )
    ctx['s3'] = boto3.client('s3', config=aws_config)

    ctx['base_dir'] = pathlib.Path(__file__).parent.resolve()




    process(ctx)


if __name__ == '__main__':
    main()
