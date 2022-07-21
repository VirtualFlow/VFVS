#!/usr/bin/env python3

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
from botocore.config import Config
from pathlib import Path
import shutil
import pathlib


def parse_config(filename):
    with open(filename, "r") as read_file:
        config = json.load(read_file)

    return config


def extract_collections(response):
    keys = {}
    if('Contents' in response):
        for item in response['Contents']:
            keyname = item['Key'].split("/")[-1].split(".")[0]
            keys[keyname] = 1

    return keys;

def get_collection_list(ctx, collection_tranche, collection_name):

    s3_path = [
        ctx['config']['object_store_data_collection_prefix'],
        collection_tranche,
        collection_name,
    ]

    try:
        response = ctx['s3'].list_objects_v2(
                Bucket=ctx['config']['object_store_data_bucket'],
                Prefix="/".join(s3_path)
                )
    except ClientError as e:
        logging.error(e)
        return None

    keys = extract_collections(response)

    while('NextContinuationToken' in response):
        #print("again")
        try:
            response = ctx['s3'].list_objects_v2(
                    Bucket=ctx['config']['object_store_data_bucket'],
                    Prefix="/".join(s3_path),
                    ContinuationToken=response['NextContinuationToken']
                    )
        except ClientError as e:
            logging.error(e)
            return None

        keys = {**keys,  **extract_collections(response)}


    return keys


def process(ctx):

    config = ctx['config']

    total_lines = 0
    with open('templates/todo.all') as fp:
        for index, line in enumerate(fp):
            total_lines += 1


    collections = []

    with open('templates/todo.all') as fp:
        for line in fp:

            collection_full_name, collection_count = line.split()
            collection_tranche = collection_full_name[:2]
            collection_name, collection_number = collection_full_name.split("_", 1)
            collection_count = int(collection_count)

            collections.append([collection_full_name, collection_count])


    last_collection_name = ""

    #print(collections)
    collections.sort()

    not_found = []

    with open('templates/todo.all.found', "w") as fp:

        counter = 0;
        for collection_element in collections:
            collection_full_name, collection_count = collection_element


            collection_tranche = collection_full_name[:2]
            collection_name, collection_number = collection_full_name.split("_", 1)

            if(last_collection_name != collection_name):
                collection_list_cache = get_collection_list(ctx, collection_tranche, collection_name)
                last_collection_name = collection_name

            if(collection_number not in collection_list_cache):
                not_found.append(collection_full_name)
            else:
                fp.write(f"{collection_full_name} {collection_count}\n")

            counter += 1
            if(counter % 1000 == 0):
                percent_done = (counter / total_lines) * 100
                print(f"{percent_done:.2f}% completed.... ({counter}/{total_lines})")

    print("not found collections")
    for item in not_found:
        print(item)

    print("All collections found are in templates/todo.all.found")

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
