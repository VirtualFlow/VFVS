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
# Description: Get status of the AWS Batch jobs
#
# Revision history:
# 2021-06-29  Original version
#
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


batch_job_statuses = {
    'SUBMITTED': {
        'check_parent': 1,
        'check_subjobs': 0,
        'completed': 0,
        'order': 1
    },
    'PENDING': {
        'check_parent': 1,
        'check_subjobs': 1,
        'completed': 0,
        'order': 2
    },
    'RUNNABLE': {
        'check_parent': 1,
        'check_subjobs': 0,
        'completed': 0,
        'order': 3
    },
    'STARTING': {
        'check_parent': 1,
        'check_subjobs': 1,
        'completed': 0,
        'order': 4
    },
    'RUNNING': {
        'check_parent': 1,
        'check_subjobs': 1,
        'completed': 0,
        'order': 5
    },
    'SUCCEEDED': {
        'check_parent': 0,
        'check_subjobs': 1,
        'completed': 1,
        'order': 6
    },
    'FAILED': {
        'check_parent': 0,
        'check_subjobs': 1,
        'completed': 1,
        'order': 7
    },
}


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


def process(config):

    aws_config = Config(
        region_name=config['aws_region']
    )

    client = boto3.client('batch', config=aws_config)

    # load the status file that is keeping track of the data
    with open("../workflow/status.json", "r") as read_file:
        status = json.load(read_file)

    collections = status['collections']
    workunits = status['workunits']

    workunits_to_check = []

    for workunit_key in workunits:
        current_workunit = workunits[workunit_key]

        # Has this even been submitted?
        if 'status' in current_workunit and current_workunit['status']['vf_job_status'] == "SUBMITTED":
            if('aws_batch_status' not in current_workunit['status']
               or batch_job_statuses[current_workunit['status']['aws_batch_status']]['check_parent'] == 1):
                workunits_to_check.append(workunit_key)

    # Check the parent status of each one to see if anything has changed.
    # AWS Batch can handle up to 100 at a time

    print("Looking for updated jobline status - starting")

    workunit_subjobs_to_check = []

    for status_index in range(0, len(workunits_to_check), 100):

        job_keys_to_check = []
        job_key_mapping = {}

        for workunit_key in workunits_to_check[status_index:(status_index + 100)]:
            workunit = workunits[workunit_key]
            job_key_mapping[workunit['status']['job_id']] = workunit_key
            job_keys_to_check.append(workunit['status']['job_id'])

        response = client.describe_jobs(jobs=job_keys_to_check)

        if 'jobs' in response:
            for job in response['jobs']:

                current_workunit = workunits[job_key_mapping[job['jobId']]]

                # Do we need to check the overall subjob status? We don't need to unless the job has started
                # and it's different than the last time we checked

                # This status is one we should check the subjobs
                if(batch_job_statuses[job['status']]['check_subjobs'] == 1):
                    # If we have never checked it before or it's different than what it was the
                    # last time we checked
                    if(('aws_batch_status' not in current_workunit['status'] or
                            job['arrayProperties']['statusSummary'] != current_workunit['status']['aws_batch_status_array'])
                       ):
                        workunit_subjobs_to_check.append(
                            job_key_mapping[job['jobId']])

                # Update the status
                current_workunit['status']['aws_batch_status'] = job['status']
                current_workunit['status']['aws_batch_status_array'] = job['arrayProperties']['statusSummary']

    print("\nLooking for updated jobline status - done\n")

    print("Looking for updated subtask status - starting")

    subjobids_to_check = []

    # For each case where the subjob information may have changed, add to the list to lookup
    for workunit_key in workunit_subjobs_to_check:
        workunit = workunits[workunit_key]

        # Ignore ones that we already know are complete (SUCCEEDED and FAILED) from a previous run
        for subjob_key in current_workunit['subjobs']:
            subjob = workunit['subjobs'][subjob_key]

            if 'status' not in subjob:
                subjob['status'] = 'UNKNOWN'

            if(subjob['status'] != "SUCCEEDED" and subjob['status'] != "FAILED"):
                subjobids_to_check.append(
                    {'workunit_key': workunit_key, 'subjob_key': subjob_key})

    # Lookup status in batches of 100
    counter = 0
    for status_index in range(0, len(subjobids_to_check), 100):

        job_keys_to_check = []
        job_key_mapping = {}

        for unit in subjobids_to_check[status_index:(status_index + 100)]:

            workunit = workunits[unit['workunit_key']]

            job_key_mapping[f"{workunit['status']['job_id']}:{unit['subjob_key']}"] = unit
            job_keys_to_check.append(
                f"{workunit['status']['job_id']}:{unit['subjob_key']}")

        response = client.describe_jobs(jobs=job_keys_to_check)

        if 'jobs' in response:
            for job in response['jobs']:

                workunit_key = job_key_mapping[job['jobId']]['workunit_key']
                subjob_key = job_key_mapping[job['jobId']]['subjob_key']

                workunit = workunits[workunit_key]
                subjob = workunit['subjobs'][subjob_key]

                subjob['status'] = job['status']
                subjob['detailed_status'] = {
                    'container': {
                        'vcpus': job['container']['vcpus']
                    },
                    'attempts': job['attempts']
                }

        counter += 100

        if(counter % 1000 == 0):
            percent = (counter / len(subjobids_to_check)) * 100
            print(f".... {percent: .2f}%")

    print("\nLooking for updated subtask status - done")

    print("Generating summary")

    # Update all of the status information
    # -- ligands being processed
    # -- current number of workunits running
    # 	-- current number of subworkunits runnning
    #	-- total vCPUs running
    #	-- total vCPU hours consumed by completed ligands and average time

    total_stats = {
        'active_vcpus': 0,
        'vcpu_min_from_completed': 0.0,
        'vcpu_min_from_failed_tasks': 0.0,
        'vcpu_min_from_successful_tasks': 0.0,
        'vcpu_min_from_retried': 0.0,
        'total_reattempts': 0
    }

    total_stats_by_status = {}

    for category in ("ligands", "jobs", "subjobs", "vcpu_min"):
        total_stats_by_status[category] = {}
        for key in batch_job_statuses:
            total_stats_by_status[category][key] = 0

    for workunit_key in workunits:

        workunit = workunits[workunit_key]

        if 'status' not in workunit:
            continue

        # Update workunit status
        total_stats_by_status['jobs'][workunit['status']
                                      ['aws_batch_status']] += 1

        for subjob_key in workunit['subjobs']:
            subjob = workunit['subjobs'][subjob_key]

            # How many ligands are there in this subjob
            total_ligands_in_subjob = 0
            for collection_record in subjob['collections']:
                collection_key, collection_count = collection_record
                total_ligands_in_subjob += collection_count

            # What status is it in?

            # If we already have it set ... use that
            subjob_status = "UNKNOWN"
            if('status' in subjob):
                subjob_status = subjob['status']
            elif('aws_batch_status' in workunit['status']):
                parent_status = workunit['status']['aws_batch_status']
                subjob_status = parent_status

            # Update Subjob status
            total_stats_by_status['subjobs'][subjob_status] += 1
            total_stats_by_status['ligands'][subjob_status] += int(
                total_ligands_in_subjob)

            # Determine the cores used for this
            if(batch_job_statuses[subjob_status]['completed'] == 1):

                # How many vcpus?
                vcpus = int(subjob['detailed_status']['container']['vcpus'])

                vcpu_total_min = 0.0
                vcpu_successful_attempt_min = 0.0

                # Look at each attempt
                for attempt in subjob['detailed_status']['attempts']:
                    if 'startedAt' not in attempt:
                        continue

                    start_msec = int(attempt['startedAt'])
                    stop_msec = int(attempt['stoppedAt'])

                    vcpu_min = ((stop_msec - start_msec) / 1000) * vcpus / 60

                    if(attempt['statusReason'] == "Essential container in task exited"):
                        vcpu_successful_attempt_min = vcpu_min

                    vcpu_total_min += vcpu_min

                # Update attempts #
                total_stats['total_reattempts'] += len(
                    subjob['detailed_status']['attempts']) - 1

                # Update the summary
                total_stats['vcpu_min_from_completed'] += vcpu_total_min
                total_stats['vcpu_min_from_retried'] += vcpu_total_min - \
                    vcpu_successful_attempt_min
                total_stats_by_status['vcpu_min'][subjob_status] += vcpu_total_min

                subjob['stats'] = {
                    'vcpu_min_from_completed': vcpu_total_min,
                    'vcpu_min_from_retried': vcpu_total_min - vcpu_successful_attempt_min
                }

            elif(subjob_status == "RUNNING"):
                # How many vcpus?
                vcpus = int(subjob['detailed_status']['container']['vcpus'])
                total_stats['active_vcpus'] += vcpus

    for category in ("ligands", "jobs", "subjobs", "vcpu_min"):
        total_stats_by_status[category]['TOTAL'] = 0
        for key in batch_job_statuses:
            total_stats_by_status[category]['TOTAL'] += total_stats_by_status[category][key]

    total_stats_by_status['vcpu_hours'] = {}
    for key in total_stats_by_status['vcpu_min']:
        if(key == "SUCCEEDED" or key == "FAILED" or key == "TOTAL"):
            total_stats_by_status['vcpu_hours'][key] = f"{(total_stats_by_status['vcpu_min'][key] / 60):.2f}"
        else:
            total_stats_by_status['vcpu_hours'][key] = "-"

    print("SUMMARY BASED ON AWS BATCH COMPLETION STATUS (different than actual docking status):\n")

    job_print = {}

    print(f'{"category":>14}', end="")
    for key, value in sorted(batch_job_statuses.items(), key=lambda x: x[1]['order']):
        print(f'{key:>14}', end="")

    print(f'{"TOTAL":>14}')

    for category in ("ligands", "jobs", "subjobs", "vcpu_hours"):

        print(f'{category:>14}', end="")

        job_print[category] = [total_stats_by_status[category]['TOTAL']]

        for key, value in sorted(batch_job_statuses.items(), key=lambda x: x[1]['order']):
            job_print[category].append(total_stats_by_status[category][key])
            print(f'{total_stats_by_status[category][key]:>14}', end="")

        job_print[f'{category}.str'] = [str(s) for s in job_print[category]]
        print(f"{total_stats_by_status[category]['TOTAL']:>14}")

    # Also provide more information on VCPU hours

    print("")
    print(f"vCPU hours total: {total_stats_by_status['vcpu_hours']['TOTAL']}")
    print(
        f"vCPU hours interrupted: {total_stats['vcpu_min_from_retried'] / 60:0.2f}")

    if(total_stats_by_status['ligands']['SUCCEEDED'] != 0):
        vcpu_seconds_per_successful_ligand = total_stats_by_status['vcpu_min'][
            'SUCCEEDED'] * 60 / total_stats_by_status['ligands']['SUCCEEDED']
        print(
            f"vCPU seconds per ligand: {vcpu_seconds_per_successful_ligand:0.2f} [excludes failed count and time]")
    print("")
    print(f"Active vCPUs: {total_stats['active_vcpus']}")

    # Now get the data from each of the runs and see how successful we have been

    print("Processing results files")

    storage_workdir = "../workflow/completed_status"
    os.makedirs(storage_workdir, exist_ok=True)

    s3 = boto3.client('s3')

    # Start by getting the completed collection information

    ligands_removed = 0
    ligands_failed_docking = 0
    ligands_succeeded_docking = 0
    unknown_event = 0

    counter = 0

    for workunit_key in workunits:
        workunit = workunits[workunit_key]

        counter += 1

        if(counter % 10 == 0):
            percent = (counter / len(workunits)) * 100
            print(f".... {percent: .2f}%")

        if 'status' not in workunit:
            continue

        # Look at each subjob
        for subjob_key in workunit['subjobs']:

            subjob = workunit['subjobs'][subjob_key]

            if('status' not in subjob):
                continue

            if(subjob['status'] == "SUCCEEDED" or subjob['status'] == "FAILED"):

                if('processed' not in subjob or subjob['processed'] == 0):

                    for collection_string in subjob['collections']:

                        collection_full_name, collection_count = collection_string

                        collection_tranche = collection_full_name[:2]
                        collection_name, collection_number = collection_full_name.split(
                            "_", 1)

                        collection = collections[collection_full_name]
                        if('status' not in collection):
                            collection['status'] = {
                                'ligands_removed': 0,
                                'ligands_failed_docking': 0,
                                'ligands_succeeded_docking': 0,
                                'unknown_event': 0,
                            }

                        collection_status_path = os.path.join(
                            storage_workdir, collection_tranche, collection_name, f"{collection_number}.json.gz")

                        # Have we already downloaded the file?
                        if(not os.path.exists(collection_status_path)):

                            os.makedirs(os.path.join(
                                storage_workdir, collection_tranche, collection_name), exist_ok=True)
                            src_location = f"{config['object_store_job_data_prefix']}/output/ligand-lists/{collection_tranche}/{collection_name}/{collection_number}.json.gz"

                            try:
                                with open(collection_status_path, 'wb') as f:
                                    s3.download_fileobj(
                                        config['object_store_bucket'], src_location, f)
                            except Exception as err:
                                print(
                                    f"Error downloading {src_location} [this is likely temporary]")
                                print(
                                    f"--> jobline: {workunit_key}, subjob_index: {subjob_key}, jobid: {workunit['status']['job_id']}:{subjob_key}")

                                if os.path.exists(collection_status_path):
                                    os.remove(collection_status_path)

                                continue

                        try:
                            with gzip.open(collection_status_path, 'rt') as f:
                                log_events = json.load(f)

                                for event in log_events:
                                    if(event['status'] == "failed"):
                                        collection['status']['ligands_removed'] += 1
                                    elif(event['status'] == "failed(docking)"):
                                        collection['status']['ligands_failed_docking'] += 1
                                    elif(event['status'] == "succeeded"):
                                        collection['status']['ligands_succeeded_docking'] += 1
                                    else:
                                        collection['status']['unknown_event'] += 1

                            subjob['processed'] = 1

                        except Exception as err:
                            print(f"Error opening {collection_status_path}")
                            print(
                                f"--> jobline: {workunit_key}, subjob_index: {subjob_key}, jobid: {workunit['status']['job_id']}:{subjob_key}")
                            if os.path.exists(collection_status_path):
                                os.remove(collection_status_path)

    # Roll up information from all collections

    total_collections = {
        'status': {
            'ligands_removed': 0,
            'ligands_failed_docking': 0,
            'ligands_succeeded_docking': 0,
            'unknown_event': 0,
        },
        'status_percent': {}
    }

    for collection_key in collections:
        collection = collections[collection_key]
        if('status' in collection):
            for event_type in collection['status']:
                total_collections['status'][event_type] += collection['status'][event_type]

    total_events = 0
    for event_type in total_collections['status']:
        total_events += total_collections['status'][event_type]

    # Get the percentages
    for event_type in total_collections['status']:
        if(total_events > 0):
            metric = (total_collections['status']
                      [event_type] / total_events) * 100
            total_collections['status_percent'][event_type] = f"{metric: .2f}"
        else:
            total_collections['status_percent'][event_type] = "--"

    print("")
    for category in ['ligands_succeeded_docking', 'ligands_removed', 'ligands_failed_docking', 'unknown_event']:
        metric = total_collections['status'][category]
        metric_percent = total_collections['status_percent'][category]
        print(f"{category}: {metric} ({metric_percent}%)")
    print("")


#	vcpu_seconds = total_stats_by_status['vcpu_min']['SUCCEEDED'] * 60 / ligands_succeeded_docking
#	print(f"vCPU seconds per ligand: {vcpu_seconds:0.2f} [excludes failed and removed - based on actual]")
#

    print("Writing the json status file out")

    # Output all of the information about the workunits into JSON so we can easily grab this data in the future
    with open("../workflow/status.json", "w") as json_out:
        json.dump(status, json_out)


def main():

    config = parse_config("../workflow/control/all.ctrl")
    process(config)


if __name__ == '__main__':
    main()
