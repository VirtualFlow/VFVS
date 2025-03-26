#!/usr/bin/env python3

# Copyright (C) 2019 Christoph Gorgulla
# Copyright (C) 2024 Christopher Secker
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

import time
import argparse
import json
import os
import glob
import pandas as pd
import re
import subprocess
from tqdm import tqdm
from concurrent.futures import ProcessPoolExecutor


def parse_config(filename):
    with open(filename, "r") as read_file:
        config = json.load(read_file)

    return config


def wait_for_athena_completion(athena_client, s3_client, response_to_wait, delete=1, desc="unknown"):
    finished_states = ['SUCCEEDED', 'FAILED', 'CANCELLED']

    print(f"Waiting on {desc} ({response_to_wait['QueryExecutionId']})")
    while True:

        response = athena_client.get_query_execution(
            QueryExecutionId=response_to_wait['QueryExecutionId']
        )

        time.sleep(0.5)

        if (response['QueryExecution']['Status']['State'] in finished_states):

            if (delete == 1 and response['QueryExecution']['Status']['State'] == "SUCCEEDED"):
                # remove the old data
                obj_parts = response['QueryExecution']['ResultConfiguration']['OutputLocation'].split("/")
                obj_combined = "/".join(obj_parts[3:])

                del_response = s3_client.delete_object(
                    Bucket=obj_parts[2],
                    Key=obj_combined
                )

            break

    return response


def get_top_results_slurm_csv(docking_scenario_output_folder):
    files = glob.glob(os.path.join(docking_scenario_output_folder, 'csv', '*', '*.csv.gz'))

    if len(files) < 1:
        print(f"No results in {docking_scenario_output_folder} found, exiting...")
        return

    df_workunits = []
    pattern = re.compile(r'csv/(\d+)/(\d+)\.csv\.gz')

    for f in tqdm(files, desc='Collection results', unit=' files'):
        match = pattern.search(f)
        if match:
            workunit = int(match.group(1))
            task = int(match.group(2))
        else:
            workunit = 0
            task = 0
        df_workunit = pd.read_csv(f, compression='gzip', sep=',')
        df_workunit.insert(loc=3, column='workunit', value=workunit)
        df_workunit.insert(loc=4, column='task', value=task)
        df_workunits.append(df_workunit)

    df_all = pd.concat(df_workunits, axis=0, ignore_index=True)
    df_all = df_all.sort_values(by='score_min', ascending=True).reset_index(drop=True)
    return df_all


def extract_docking_pose(row):
    idx_row, row_data, args = row
    ligand = row_data['ligand']
    scenarios = [row_data[col] for col in row_data.index if col.startswith('scenario')]
    workunits = [row_data[col] for col in row_data.index if col.startswith('workunit')]
    tasks = [row_data[col] for col in row_data.index if col.startswith('task')]

    for idx, scenario in enumerate(scenarios):
        if len(scenarios) == 1:
            scores = [(col, row_data[col]) for col in row_data.index if re.match(r'score_\d+$', col)]
        else:
            scores = [(col, row_data[col]) for col in row_data.index if re.match(r'score_\d+_' + scenario + '$', col)]

        scores_valid = []
        for score in scores:
            if not pd.isna(score[1]):
                scores_valid.append(score)

        if len(scores_valid) == 0:
            print(f"No valid score for {ligand} in {scenario}, skipping...")
            continue
        score_min = min(scores_valid, key=lambda x: x[1])
        score_int = re.match(r"score_(\d+)", score_min[0]).group(1)

        cmd = ['tar', '-zxf',
               os.path.join('../output-files', scenario, 'logs', str(workunits[idx]), str(tasks[idx]) + '.tar.gz'),
               '-O', os.path.join(str(tasks[idx]), ligand, str(score_int), 'output')]

        # Fix when replicate does actually not contain the respective result
        i = 0
        for _ in range(len(scores) + 1):
            try:
                result = subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
                output = result.stdout.decode('utf-8')
            except subprocess.CalledProcessError as e:
                print(f"Subprocess error: {e}, skipping {ligand} in {scenario}...")
                output = ""
            except FileNotFoundError as e:
                print(f"File not found: {e}, skipping {ligand} in {scenario}...")
                output = ""
            except Exception as e:
                print(f"Unexpected error: {e}, skipping {ligand} in {scenario}...")
                output = ""

            if any(line.startswith("REMARK VINA RESULT") and str(score_min[1]) in line for line in output.splitlines()):
                break
            else:
                # If score_min does not match score in docking result, try all files
                score_int = i
                cmd = ['tar', '-zxf',
                       os.path.join('../output-files', scenario, 'logs', str(workunits[idx]), str(tasks[idx]) + '.tar.gz'),
                       '-O', os.path.join(str(tasks[idx]), ligand, str(score_int), 'output')]
                i += 1

        output_file = os.path.join(args.output_folder, f"{idx_row + 1}_{scenario}_{ligand}.pdbqt")
        if not os.path.isfile(output_file):
            with open(output_file, 'wb') as f:
                f.write(result.stdout)


def main():
    ctx = {}
    ctx['config'] = parse_config("../workflow/config.json")

    parser = argparse.ArgumentParser()

    parser.add_argument('--results_file', action='store', type=str, required=True)
    parser.add_argument('--mode', action='store', type=str, required=True)
    parser.add_argument('--f', action='store', type=int, required=True)
    parser.add_argument('--n', action='store', type=int, required=True)
    parser.add_argument('--output_folder', action='store', type=str, required=True)

    args = parser.parse_args()

    args_dict = vars(args)

    if os.path.isfile(args.results_file):
        ranking = pd.read_csv(args.results_file)
    else:
        print(f"File {args.results_file} not found, exiting...")
        exit(1)

    if not os.path.exists(args.output_folder):
        os.makedirs(args.output_folder)

    if args.mode == "top":
        ranking = ranking[args.f:args.f+args.n]
    elif args.mode == "random":
        ranking = ranking[args.f:].sample(n=args.n)
    else:
        print(f"Argument '--mode' has to be either top or random, but is '{args.mode}', exiting...")
        exit(1)

    tasks = ranking.iterrows()
    num_workers = os.cpu_count()

    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        with tqdm(total=len(ranking)) as pbar:
            for _ in executor.map(extract_docking_pose, [(idx_row, row_data, args) for idx_row, row_data in tasks]):
                pbar.update()


if __name__ == '__main__':
    main()
