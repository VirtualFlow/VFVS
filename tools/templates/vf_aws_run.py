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
# Description: Main runner for the individual workunits/job lines
#
# Revision history:
# 2021-06-29  Original version
# 2021-08-02  Added additional handling for case where there is only 
#             a single subjob in a job
#
# ---------------------------------------------------------------------------


import tempfile
import tarfile
import gzip
import os
import json
import re
import boto3
import multiprocessing
import subprocess
import botocore
import logging
import time
from pathlib import Path


# Given a config file, parse out all of the configuration options

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


def process_config(ctx):

    new_config = ctx['config.temp']

    # Split up any items first

    new_config['docking_scenario_names'] = ctx['config.temp']['docking_scenario_names'].split(
        ":")
    new_config['docking_scenario_programs'] = ctx['config.temp']['docking_scenario_programs'].split(
        ":")
    new_config['docking_scenario_replicas'] = ctx['config.temp']['docking_scenario_replicas'].split(
        ":")
    new_config['docking_scenario_inputfolders'] = ctx['config.temp']['docking_scenario_inputfolders'].split(
        ":")

    # Create absolute directories based on the other parameters

    new_config['collection_working_path'] = os.path.join(
        ctx['temp_dir'], "collections")
    new_config['output_working_path'] = os.path.join(
        ctx['temp_dir'], "output-files")

    # Determine full config.txt paths for scenarios
    new_config['docking_scenarios'] = {}

    for index, scenario in enumerate(new_config['docking_scenario_names']):
        new_config['docking_scenarios'][scenario] = {
            'key': scenario,
            'config': os.path.join(ctx['temp_dir'], "vf_input", "input-files",
                                   new_config['docking_scenario_inputfolders'][index],
                                   "config.txt"
                                   ),
            'program': new_config['docking_scenario_programs'][index],
            'replicas': int(new_config['docking_scenario_replicas'][index])
        }

    return new_config

# Retrieve the config file (eventually can be non-S3)


def get_config_file(temp_dir, s3, bucket_name, object_name):

    try:
        with open(f'{temp_dir}/vf_input.tar.gz', 'wb') as f:
            s3.download_fileobj(bucket_name, object_name, f)
    except botocore.exceptions.ClientError as err:
        logging.error(
            "Failed to download from S3 {bucket_name}/{object_name} to {temp_dir}/vf_input.tar.gz, ({err})")
        raise(error)
        exit(1)

    os.chdir(f"{temp_dir}")

    try:
        tar = tarfile.open("vf_input.tar.gz")
        tar.extractall()
        tar.close()
    except Exception as err:
        logging.error(
            f"ERR: Cannot open vf_input.tar.gz type: {str(type(err))}, err: {str(err)}")
        raise(err)
        exit(1)

    return f"{temp_dir}/vf_input/all.ctrl"


# Get only the collection information with the subjob specified

def get_subjob(ctx, workunit_id, subjob_id):
    # Download from S3

    input_path = [
        ctx['config']['object_store_job_data_prefix'],
        "input",
        "tasks",
        f"{workunit_id}.tar.gz"
    ]
    object_name = "/".join(input_path)

    try:
        with open(f"{ctx['temp_dir']}/{workunit_id}.tar.gz", 'wb') as f:
            ctx['s3'].download_fileobj(
                ctx['config']['object_store_bucket'], object_name, f)
    except botocore.exceptions.ClientError as error:
        logging.error(
            f"Failed to download from S3 {ctx['config']['object_store_bucket']}/{object_name} to {ctx['temp_dir']}/{workunit_id}.tar.gz, ({error})")
        return None

    os.chdir(f"{ctx['temp_dir']}")

    # Get the file with the specific workunit we need to work on
    try:
        tar = tarfile.open(f"{workunit_id}.tar.gz")
        file = tar.extractfile(f"vf_tasks/{subjob_id}.json")
        subjob = json.load(file)
        tar.close()
    except Exception as err:
        logging.error(
            f"ERR: Cannot open {workunit_id}.tar.gz. type: {str(type(err))}, err: {str(err)}")
        return None

    return subjob

# Generate the run command for a given program
#


def program_runstring_array(task):

    cpus_per_program = "1"

    cmd = []
    time_cmd = ['/opt/vf/tools/bin/time_bin', '-f',
                ' Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n']

    if(task['program'] == "qvina02"
            or task['program'] == "qvina_w"
            or task['program'] == "vina"
            or task['program'] == "vina_carb"
            or task['program'] == "vina_xb"
            or task['program'] == "gwovina"
       ):
        cmd = [
            *time_cmd,
            f"/opt/vf/tools/bin/{task['program']}",
            '--cpu', cpus_per_program,
            '--config', task['config_path'],
            '--ligand', task['ligand_path'],
            '--out', task['output_path']
        ]
    elif(task['program'] == "smina"):
        # TODO: setup the appropriate paths
        cmd = [
            *time_cmd,
            '/opt/vf/tools/bin/smina',
            '--cpu', cpus_per_program,
            '--config', task['config_path'],
            '--ligand', task['ligand_path'],
            '--out', task['output_path'],
            '--log',
            '--atom_terms'
            # .atomterms
            # .flexres.pdb
        ]
    elif(task['program'] == "adfr"):
        # TODO: convert config.txt and remove all newlines and pass in

        adfr_config_options = ""

        cmd = [
            *time_cmd,
            'adfr',
            '-l', task['ligand_path'],
            '--jobName', 'adfr',
            adfr_config_options
        ]
        #                     adfr_configfile_options=$(cat ${docking_scenario_inputfolder}/config.txt | tr -d "\n")
    #            { bin/time_bin -f " Docking timings \n-------------------------------------- \n user real system \n %U %e %S \n------------------------------------- \n" adfr -l ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/input-files/ligands/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}.${ligand_library_format} --jobName adfr ${adfr_configfile_options} 2> >(tee ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output.tmp 1>&2) ; } 2>&1
    #            rename "_adfr_adfr.out" "" ${next_ligand}_replica-${docking_replica_index} ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}*
    #
    #            score_value=$(grep -m 1 "FEB" ${VF_TMPDIR}/${USER}/VFVS/${VF_JOBLETTER}/${VF_QUEUE_NO_12}/${VF_QUEUE_NO}/output-files/incomplete/${docking_scenario_name}/logfiles/${next_ligand_collection_metatranch}/${next_ligand_collection_tranch}/${next_ligand_collection_ID}/${next_ligand}_replica-${docking_replica_index}.${ligand_library_format} | awk -F ': ' '{print $(NF)}')
    elif(task['program'] == "plants"):
        # TODO implement plants
        adfr_config_options = ""

    return cmd

# Individual tasks that will be completed in parallel


def process_ligand(task):

    start_time = time.perf_counter()

    completion_event = {
        'collection_key': task['collection_key'],
        'ligand_key': task['ligand_key'],
        'scenario_key': task['scenario_key'],
        'replica_index': task['replica_index'],
        'ligand_path': task['ligand_path'],
        'output_path': task['output_path'],
        'log_path': task['log_path'],
        'status': "failed(docking)"
    }

    cmd = program_runstring_array(task)
    logging.debug(cmd)

    ret = subprocess.run(cmd, capture_output=True,
                         text=True, cwd=task['input_files_dir'])
    if ret.returncode == 0:

        if(task['program'] == "qvina02"
                or task['program'] == "qvina_w"
                or task['program'] == "vina"
                or task['program'] == "vina_carb"
                or task['program'] == "vina_xb"
                or task['program'] == "gwovina"
           ):

            match = re.search(
                r'^\s+1\s+(?P<value>[-0-9.]+)\s+', ret.stdout, flags=re.MULTILINE)
            if(match):
                matches = match.groupdict()
                completion_event['score'] = float(matches['value'])
                completion_event['status'] = "success"
            else:
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")

        elif(task['program'] == "smina"):
            for line in reversed(ret.stdout.splitlines()):
                match = re.search(r'^1\s{4}\s*(?P<value>[-0-9.]+)\s+', line)
        elif(task['program'] == "adfr"):
            logging.error(
                f"adfr not implemented {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
        elif(task['program'] == "plants"):
            logging.error(
                f"plants not implemented {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")

    else:
        logging.error(
            f"Non zero return code for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
        logging.error(f"stdout:\n{ret.stdout}\nstderr:{ret.stderr}\n")

    # Place output into files
    with open(task['log_path'], "w") as output_f:
        output_f.write(f"STDOUT:\n{ret.stdout}\n")
        output_f.write(f"STDERR:\n{ret.stderr}\n")

    end_time = time.perf_counter()

    completion_event['seconds'] = end_time - start_time

    return completion_event


def preprocess_collection(ctx, collection_full_name, collection_count):

    subtasklist = []

    collection_tranche = collection_full_name[:2]
    collection_name, collection_number = collection_full_name.split("_", 1)

    specific_collection_path = os.path.join(
        ctx['config']['collection_working_path'], f"{collection_name}")
    os.makedirs(specific_collection_path, exist_ok=True)

    this_collection = {
        'key': collection_full_name,
        'tranche': collection_tranche,
        'name': collection_name,
        'number': collection_number,
        'count': collection_count,
        'path': specific_collection_path,
        'ligands': {},
        'log': [],
        'log_json': []
    }

    logging.info(f"Initial Processing of {collection_tranche}/{collection_name}/{collection_number}")

    # Download the collection information

    object_path = [
        ctx['config']['object_store_ligands_prefix'],
        collection_tranche,
        collection_name,
        f"{collection_number}.tar.gz"
    ]

    object_name = "/".join(object_path)

    s3_obj = f"{ctx['config']['object_store_ligands_prefix']}/{collection_tranche}/{collection_name}/{collection_number}.tar.gz"

    try:
        with open(os.path.join(specific_collection_path, f"{collection_number}.tar.gz"), 'wb') as f:
            ctx['s3'].download_fileobj(
                ctx['config']['object_store_bucket'], object_name, f)
    except botocore.exceptions.ClientError as error:
        local_path = os.path.join(
            specific_collection_path, f"{collection_number}.tar.gz")
        logging.error(
            f"Failed to download from S3 {ctx['config']['object_store_bucket']}/{object_name} to {local_path} ({error})")
        return None

    os.chdir(specific_collection_path)

    try:
        tar = tarfile.open(f"{collection_number}.tar.gz")
        for member in tar.getmembers():
            if(not member.isdir()):
                _, ligand = member.name.split("/", 1)

                this_collection['ligands'][ligand] = {
                    'path':  os.path.join(specific_collection_path, collection_number, ligand)
                }

        tar.extractall()
        tar.close()
    except Exception as err:
        logging.error(
            f"ERR: Cannot open {collection_number}.tar.gz. type: {str(type(err))}, err: {str(err)}")
        return None

    return this_collection


def create_summary_file(ctx, scenario, collection, scenario_result):

    # Open the summary file

    summary_dir = scenario_collection_output_directory(
        ctx, scenario, collection, "summaries", tmp_prefix=1, skip_num=1)
    os.makedirs(summary_dir, exist_ok=True)

    os.chdir(summary_dir)

    with gzip.open(f"{collection['number']}.txt.gz", "wt") as summmary_fp:
        summmary_fp.write(
            "Tranch    Compound   average-score maximum-score  number-of-dockings ")

        for replica_index in range(scenario['replicas']):
            replica_str = f"score-replica-{replica_index}"
            summmary_fp.write(f"{replica_str}")
        summmary_fp.write("\n")

        # Now we need to go through each ligand
        for ligand_key in scenario_result['ligands']:
            ligand = scenario_result['ligands'][ligand_key]

            if(len(ligand['scores']) > 0):

                max_score = max(ligand['scores'])
                avg_score = sum(ligand['scores']) / len(ligand['scores'])

                summmary_fp.write(
                    f"{collection['key']} {ligand_key}     {avg_score:3.1f}    {max_score:3.1f}     {len(ligand['scores']):5d}   ")
                for replica_index in range(scenario['replicas']):
                    summmary_fp.write(
                        f"{ligand['scores'][replica_index]:3.1f}   ")
                summmary_fp.write("\n")

    return os.path.join(summary_dir, f"{collection['number']}.txt.gz")


def collection_output(ctx, collection, result_type, skip_num=0, tmp_prefix=0, append=""):
    path_components = []

    if(tmp_prefix):
        path_components.append(ctx['temp_dir'])

    path_components.extend([
        "output", result_type,
        collection['tranche'], collection['name']
    ])

    if(skip_num != 1):
        path_components.append(collection['number'])

    if(append != ""):
        path_components[-1] = f"{path_components[-1]}{append}"

    return path_components


def collection_output_directory_status_gz(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".status.gz"))


def collection_output_directory_status_json_gz(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".json.gz"))


def collection_output_directory(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix))


def scenario_collection_output(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0, append=""):
    path_components = []

    if(tmp_prefix):
        path_components.append(ctx['temp_dir'])

    path_components.extend([
        "output", scenario['key'], result_type,
        collection['tranche'], collection['name']
    ])

    if(skip_num != 1):
        path_components.append(collection['number'])

    if(append != ""):
        path_components[-1] = f"{path_components[-1]}{append}"

    return path_components


def scenario_collection_output_directory(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix))


def scenario_collection_output_directory_tgz(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".tar.gz"))


def scenario_collection_output_directory_txt_gz(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".txt.gz"))


def process(ctx):

    # Figure out who I am...
    workunit_id = os.getenv('VF_QUEUE_NO_1')
    subjob_id = os.getenv('AWS_BATCH_JOB_ARRAY_INDEX')
    vcpus_to_use = os.getenv('VF_CONTAINER_VCPUS')
    actual_subjobs_count = int(os.getenv('VF_MAX_SUBJOBS'))

    # AWS Batch only allows array jobs with at least 2 elements. Since we can end 
    # up with a single job, let's see if we can exit gracefully if we are the 
    # second job that has no work

    if(actual_subjobs_count == 1 and int(subjob_id) == 1):
        logging.error("There is only one subjob required and this is an extra required for AWS Batch.")
        exit(0)


    subjob = get_subjob(ctx, workunit_id, subjob_id)
    if(subjob == None):
        logging.error("Could not open subjob information")
        exit(1)

    ligand_format = ctx['config']['ligand_library_format']

    # Need to expand out all of the collections in this subjob

    collections = {}
    for collection in subjob:
        collection_full_name, collection_count = collection

        collection_obj = preprocess_collection(
            ctx, collection_full_name, collection_count)
        if(collection_obj == None):
            logging.error(
                f"Could not get the ligands part of {collection_full_name}. Skipping.")
        else:
            collections[collection_full_name] = collection_obj

    # Setup the data structure where we will keep the summary information
    scenario_results = {}
    for scenario_key in ctx['config']['docking_scenarios']:
        scenario_results[scenario_key] = {}

        for collection_key in collections:
            collection = collections[collection_key]

            scenario_results[scenario_key][collection_key] = {'ligands': {}}

            for ligand_key in collection['ligands']:
                scenario_results[scenario_key][collection_key]['ligands'][ligand_key] = {
                }
                scenario_results[scenario_key][collection_key]['ligands'][ligand_key]['scores'] = [
                ]

    # See if any of the ligands in the collections are invalid for processing

    for collection_key in collections:
        collection = collections[collection_key]

        ligands_to_skip = []

        for ligand_key in collection['ligands']:
            ligand = collection['ligands'][ligand_key]

            coords = {}
            skip_ligand = 0
            skip_reason = ""
            skip_reason_json = ""

            # Check to see if ligand contains B, Si, Sn or has duplicate coordinates
            with open(ligand['path'], "r") as read_file:
                for index, line in enumerate(read_file):

                    match = re.search(r'(?P<letters>\s+(B|Si|Sn)\s+)', line)
                    if(match):
                        matches = match.groupdict()
                        logging.error(
                            f"Found {matches['letters']} in {collection_full_name}/{ligand_key}. Skipping.")
                        skip_reason = f"failed(ligand_elements:{matches['letters']})"
                        skip_reason_json = f"ligand includes elements: {matches['letters']})"
                        skip_ligand = 1
                        break

                    match = re.search(r'^ATOM', line)
                    if(match):
                        parts = line.split()
                        coord_str = ":".join(parts[5:8])

                        if(coord_str in coords):
                            logging.error(
                                f"Found duplicate coordinates in {collection_full_name}/{ligand_key}. Skipping.")
                            skip_reason = f"failed(ligand_coordinates)"
                            skip_reason_json = f"duplicate coordinates"
                            skip_ligand = 1
                            break
                        coords[coord_str] = 1

            if skip_ligand:
                collection['log'].append(f"{ligand_key} {skip_reason}")
                collection['log_json'].append(
                    {'ligand': ligand_key, 'status': 'failed', 'info': skip_reason_json})
                ligands_to_skip.append(ligand_key)

        for ligand_key in ligands_to_skip:
            collection['ligands'].pop(ligand_key, None)

    # Create the task list based on the scenarios and replicas required
    tasklist = []
    for scenario_key in ctx['config']['docking_scenarios']:
        scenario = ctx['config']['docking_scenarios'][scenario_key]

        # For each collection
        for collection_key in collections:
            collection = collections[collection_key]

            # Setup the directories for this scenario / collection combination

            results_dir = scenario_collection_output_directory(
                ctx, scenario, collection, "results", tmp_prefix=1)
            log_dir = scenario_collection_output_directory(
                ctx, scenario, collection, "logfiles", tmp_prefix=1)

            os.makedirs(results_dir, exist_ok=True)
            os.makedirs(log_dir, exist_ok=True)

            # For each ligand, iterate through each replica and generate a task that can be
            # parallel processed

            for ligand_key in collection['ligands']:
                ligand = collection['ligands'][ligand_key]

                # For each replica
                for replica_index in range(scenario['replicas']):

                    task = {
                        'collection_key': collection_key,
                        'ligand_key': ligand_key,
                        'scenario_key': scenario_key,
                        'config_path': scenario['config'],
                        'program': scenario['program'],
                        'replica_index': replica_index,
                        'ligand_path': ligand['path'],
                        'output_path': os.path.join(results_dir, f'{ligand_key}_replica-{replica_index}'),
                        'log_path': os.path.join(log_dir, f'{ligand_key}_replica-{replica_index}'),
                        'input_files_dir':  os.path.join(ctx['temp_dir'], "vf_input", "input-files")
                    }

                    tasklist.append(task)

    # At this point we have all of the individual tasks generated. The next step is to divide these up to
    # multiple processes in a pool. Each task will run independently and generate results

    with multiprocessing.Pool(processes=int(vcpus_to_use)) as pool:
        res = pool.map(process_ligand, tasklist)

    # We are done with all of the docking now, we need to summarize them all

    # For each task get the data collected

    for task_result in res:
        collection_key = task_result['collection_key']
        scenario_key = task_result['scenario_key']
        ligand_key = task_result['ligand_key']
        replica_index = task_result['replica_index']

        collection = collections[collection_key]

        # Check to see if it was successful or not...
        if(task_result['status'] == "success"):
            score = task_result['score']
            scenario_results[scenario_key][collection_key]['ligands'][ligand_key]['scores'].append(
                score)
            collection['log'].append(
                f"{ligand_key} {scenario_key} {replica_index} succeeded total-time:{task_result['seconds']:.2f}")
            collection['log_json'].append({
                'ligand': ligand_key, 'scenario_key': scenario_key, 'replica_index': replica_index,
                'status': 'succeeded', 'seconds': f"{task_result['seconds']:.2f}", 'score': score
            })
        else:
            collection['log'].append(
                f"{ligand_key} {scenario_key} {replica_index} {task_result['status']} total-time:{task_result['seconds']:.2f}")
            collection['log_json'].append({'ligand': ligand_key, 'scenario_key': scenario_key, 'replica_index': replica_index,
                                          'status': task_result['status'], 'seconds': f"{task_result['seconds']:.2f}"})

    # Now we can generate the summary files
    for scenario_key in ctx['config']['docking_scenarios']:
        scenario = ctx['config']['docking_scenarios'][scenario_key]
        for collection_key in collections:
            collection = collections[collection_key]
            scenario_result = scenario_results[scenario_key][collection_key]

            output_name = create_summary_file(
                ctx, scenario, collection, scenario_result)

    # Generate the compressed files

    for scenario_key in ctx['config']['docking_scenarios']:
        for collection_key in collections:
            collection = collections[collection_key]

            # Generate the tarfile of all results
            tarpath = generate_tarfile(ctx, scenario_collection_output_directory(
                ctx, scenario, collection, "results", tmp_prefix=1))

            # Generate the tarfile of all logs
            tarpath = generate_tarfile(ctx, scenario_collection_output_directory(
                ctx, scenario, collection, "logfiles", tmp_prefix=1))

            # Summaries are already gzipped when written

    # Now we need to move these data files -- S3 or elsewhere on the filesystem

    for scenario_key in ctx['config']['docking_scenarios']:
        for collection_key in collections:
            collection = collections[collection_key]


            logging.info(f"Completed scenario: {scenario_key}, collection: {collection_key}")

            # Copy the results..
            copy_output(ctx,
                        {
                            'src': scenario_collection_output_directory_tgz(ctx, scenario, collection, 'results', tmp_prefix=1),
                            'dest_path': scenario_collection_output_directory_tgz(ctx, scenario, collection, 'results', tmp_prefix=0),
                        }
                        )

            copy_output(ctx,
                        {
                            'src': scenario_collection_output_directory_tgz(ctx, scenario, collection, 'logfiles', tmp_prefix=1),
                            'dest_path': scenario_collection_output_directory_tgz(ctx, scenario, collection, 'logfiles', tmp_prefix=0),
                        }
                        )

            copy_output(ctx,
                        {
                            'src': scenario_collection_output_directory_txt_gz(ctx, scenario, collection, 'summaries', tmp_prefix=1),
                            'dest_path': scenario_collection_output_directory_txt_gz(ctx, scenario, collection, 'summaries', tmp_prefix=0),
                        }
                        )

    # We also have one file at the collection level
    for collection_key in collections:
        collection = collections[collection_key]

        ligand_log_dir = collection_output_directory(
            ctx, collection, "ligand-lists", tmp_prefix=1, skip_num=1)
        ligand_log_file = collection_output_directory_status_gz(
            ctx, collection, "ligand-lists", tmp_prefix=1)
        ligand_log_file_json = collection_output_directory_status_json_gz(
            ctx, collection, "ligand-lists", tmp_prefix=1)

        os.makedirs(ligand_log_dir, exist_ok=True)
        os.chdir(ligand_log_dir)

        with gzip.open(ligand_log_file, "wt") as summmary_fp:
            for log_entry in collection['log']:
                summmary_fp.write(f"{log_entry}\n")

        # Now transfer over txt file
        copy_output(ctx,
                    {
                        'src': ligand_log_file,
                        'dest_path': collection_output_directory_status_gz(ctx, collection, "ligand-lists", tmp_prefix=0),
                    }
                    )

        with gzip.open(ligand_log_file_json, "wt") as summmary_fp:
            json.dump(collection['log_json'], summmary_fp, indent=4)

        # Now transfer over JSON file
        copy_output(ctx,
                    {
                        'src': ligand_log_file_json,
                        'dest_path': collection_output_directory_status_json_gz(ctx, collection, "ligand-lists", tmp_prefix=0),
                    }
                    )


def copy_output(ctx, obj):

    object_name = f"{ctx['config']['object_store_job_data_prefix']}/{obj['dest_path']}"

    try:
        response = ctx['s3'].upload_file(
            obj['src'], ctx['config']['object_store_bucket'], object_name)
    except botocore.exceptions.ClientError as e:
        logging.error(e)

        # We want to fail if this happens...
        raise(e)
        return False

    return True


def generate_tarfile(ctx, dir):
    os.chdir(str(Path(dir).parents[0]))

    with tarfile.open(f"{os.path.basename(dir)}.tar.gz", "x:gz") as tar:
        tar.add(os.path.basename(dir))

    return os.path.join(str(Path(dir).parents[0]), f"{os.path.basename(dir)}.tar.gz")


def main():

    ctx = {}

    log_level = os.environ.get('VF_LOGLEVEL', 'INFO').upper()
    logging.basicConfig(level=log_level)


    # Get the initial bootstrap information
    object_name = os.getenv('VF_CONFIG_OBJECT')
    bucket_name = os.getenv('VF_CONFIG_BUCKET')
    temp_dir_path = os.path.join(os.getenv('VF_TMP_PATH'), '')  

    # Get the config information
    ctx['s3'] = boto3.client('s3')
    with tempfile.TemporaryDirectory(prefix=temp_dir_path) as temp_dir:
        config_file = get_config_file(
            temp_dir, ctx['s3'], bucket_name, object_name)




        ctx['config.temp'] = parse_config(config_file)
        ctx['temp_dir'] = temp_dir
        ctx['config'] = process_config(ctx)
        process(ctx)


if __name__ == '__main__':
    main()
