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



import os
import json
import boto3
import botocore
import re
import tempfile
import gzip
import time
from botocore.config import Config



def parse_config(filename):
    
    with open(filename, "r") as read_file:
        config = json.load(read_file)

    return config


def process(config):

    aws_config = Config(
        region_name=config['aws_region']
    )

    running_states = ['RUNNING', 'STARTING']
    finished_states = ['SUCCEEDED', 'FAILED']
    pending_states = ['PENDING', 'RUNNABLE', 'SUBMITTED']


    client = boto3.client('batch', config=aws_config)

    # load the status file that is keeping track of the data
    with open("../workflow/status.json", "r") as read_file:
        status = json.load(read_file)

    workunits = status['workunits']

    workunits_to_check = []

    for workunit_key, workunit in workunits.items():
        if 'status' not in workunit:
            continue

        if workunit['status'] in finished_states:
            continue

        jobid = workunit['job_id']
        print(f"Killing {jobid}")
        try:
            response = client.terminate_job(
                jobId=jobid,
                reason="killed by vfvs_killall"
            )
        except botocore.exceptions.ClientError as error:
            print("invalid")
            raise error



    for workunit_key, workunit in workunits.items():
        if 'status' not in workunit:
            continue

        if workunit['status'] in finished_states:
            continue

        for subjob_id, subjob in workunit['subjobs'].items():
            if 'status' in subjob:
                subjob_id = f"{workunit['job_id']}:{subjob_id}"

                if subjob['status'] in finished_states:
                    continue

                if(subjob['status'] in running_states):
                    print(f"Killing {subjob_id}")
                    try:
                        response = client.terminate_job(
                            jobId=subjob_id,
                            reason="killed by vfvs_killall"
                        )
                    except botocore.exceptions.ClientError as error:
                        print("invalid")
                        raise error

                elif(subjob['status'] in pending_states):
                    print(f"Cancelling {subjob_id}")
                    try:
                        response = client.cancel_job(
                            jobId=subjob_id,
                            reason="killed by vfvs_killall"
                        )
                    except botocore.exceptions.ClientError as error:
                        print("invalid")
                        raise error




def main():

    config = parse_config("../workflow/config.json")
    process(config)


if __name__ == '__main__':
    main()
