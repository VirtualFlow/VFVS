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
#
# ---------------------------------------------------------------------------


import tempfile
import tarfile
import os
import json
import re
import boto3
import logging
import sys


def parse_config(filename):

    config = {}

    with open(filename, "r") as read_file:
        for index, line in enumerate(read_file):
            match = re.search(
                r'^(?P<parameter>.*?)\s*=\s*(?P<parameter_value>.*?)\s*$', line)
            if(match):
                matches = match.groupdict()
                config[matches['parameter']] = matches['parameter_value']

    return config


def publish_workunit(ctx, index, workunit_subjobs, status):

    # Create a temporary directory
    temp_dir = tempfile.TemporaryDirectory()
    temp_dir_tar = tempfile.TemporaryDirectory()

    for subjob_index, subjob_key in enumerate(workunit_subjobs):

        with open(f'{temp_dir.name}/{subjob_index}', 'w') as fp:
            for collection, collection_count in workunit_subjobs[subjob_key]['collections']:
                fp.write(f'{collection} {collection_count}\n')
                status['collections'][collection] = {
                    'workunit_key': index, 'subjob_key': subjob_index, 'count': collection_count}

        with open(f'{temp_dir.name}/{subjob_index}.json', 'w') as json_out:
            json.dump(workunit_subjobs[subjob_key]
                      ['collections'], json_out, indent=4)

    # Generate the tarball

    out = tarfile.open(f'{temp_dir_tar.name}/{index}.tar.gz', mode='w')
    out.add(temp_dir.name, arcname="vf_tasks")
    out.close()

    # Upload it to S3....
    #
    object_path = [
        ctx['config']['object_store_job_data_prefix'],
        "input",
        "tasks",
        f"{index}.tar.gz"
    ]
    object_name = "/".join(object_path)

    try:
        response = ctx['s3'].upload_file(
            f'{temp_dir_tar.name}/{index}.tar.gz', ctx['config']['object_store_bucket'], object_name)
    except ClientError as e:
        logging.error(e)

    temp_dir.cleanup()
    temp_dir_tar.cleanup()


def process(ctx):

    config = ctx['config']

    status = {
        'overall': {},
        'workunits': {},
        'collections': {}
    }

    workunits = status['workunits']

    current_workunit_index = 1
    current_workunit_subjobs = {}
    current_subjob_index = 0

    leftover_count = 0
    leftover_subjob = []

    counter = 0

    total_lines = 0
    with open('templates/todo.all') as fp:
        for index, line in enumerate(fp):
            total_lines += 1

    print("Generating jobfiles....")

    with open('templates/todo.all') as fp:
        for index, line in enumerate(fp):
            collection_name, collection_count = line.split()

            collection_count = int(collection_count)

            if(collection_count >= int(config['ligands_todo_per_queue'])):
                # create a new collection just for this one
                #current_workunit.append([ (collection_name, collection_count) ])
                current_workunit_subjobs[current_subjob_index] = {
                    'collections': [(collection_name, collection_count)]}
                current_subjob_index += 1
            else:
                # add it to the 'leftover pile'
                leftover_count += collection_count
                leftover_subjob.append((collection_name, collection_count))

                if(leftover_count >= int(config['ligands_todo_per_queue'])):
                    # current_workunit.append(leftover_subjob)
                    current_workunit_subjobs[current_subjob_index] = {
                        'collections': leftover_subjob}
                    current_subjob_index += 1
                    leftover_subjob = []
                    leftover_count = 0

            if(len(current_workunit_subjobs) == int(config['aws_batch_array_job_size'])):
                publish_workunit(ctx, current_workunit_index,
                                 current_workunit_subjobs, status)
                workunits[current_workunit_index] = {
                    'subjobs': current_workunit_subjobs}

                current_workunit_index += 1
                current_subjob_index = 0
                current_workunit_subjobs = {}

            counter += 1

            if(counter % 250 == 0):
                print(".", end="", file=sys.stderr)
            if(counter % 2000 == 0):
                percent = (counter / total_lines) * 100
                print(f" ({percent: .2f}%)", file=sys.stderr)

    # If we have leftovers -- process them
    if(leftover_count > 0):
        # current_workunit.append(leftover_subjob)
        current_workunit_subjobs[current_subjob_index] = {
            'collections': leftover_subjob}

    # If the current workunit has any items in it, we need to publish it
    if(len(current_workunit_subjobs) > 0):
        publish_workunit(ctx, current_workunit_index,
                         current_workunit_subjobs, status)
        workunits[current_workunit_index] = {
            'subjobs': current_workunit_subjobs}

    print("Writing json")

    # Output all of the information about the workunits into JSON so we can easily grab this data in the future
    with open("../workflow/status.json", "w") as json_out:
        json.dump(status, json_out)

    os.system('cp ../workflow/status.json ../workflow/status.todolists.json')

    print(f"Generated {current_workunit_index} workunits")


def main():

    ctx = {}
    ctx['s3'] = boto3.client('s3')
    ctx['config'] = parse_config("../workflow/control/all.ctrl")
    process(ctx)


if __name__ == '__main__':
    main()
