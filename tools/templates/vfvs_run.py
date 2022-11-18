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
# 2022-04-20  Adding support for output into parquet format
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
import uuid
import shutil
import hashlib
import pandas as pd
from pathlib import Path
from botocore.config import Config


def read_config_line(line):
    key, sep, value = line.strip().partition("=")
    return key, value


def process_config(ctx):

    # Create absolute directories based on the other parameters

    ctx['main_config']['collection_working_path'] = os.path.join(
        ctx['temp_dir'], "collections")
    ctx['main_config']['output_working_path'] = os.path.join(
        ctx['temp_dir'], "output-files")

    # Determine full config.txt paths for scenarios
    ctx['main_config']['docking_scenarios'] = {}


    if('summary_formats' not in ctx['main_config']):
        ctx['main_config']['txt.gz']

    for index, scenario in enumerate(ctx['main_config']['docking_scenario_names']):

        program_long = ctx['main_config']['docking_scenario_programs'][index]
        program = program_long

        logging.debug(f"Processing scenario '{scenario}' at index '{index}' with {program}")

        # Special handing for smina* and gwovina*
        match = re.search(r'^(?P<program>smina|gwovina)', program_long)
        if(match):
            matches = match.groupdict()
            program = matches['program']
            logging.debug(f"Found {program} in place of {program_long}")
        else:
            logging.debug(f"No special match for '{program_long}'")

        ctx['main_config']['docking_scenarios'][scenario] = {
            'key': scenario,
            'config': os.path.join(ctx['temp_dir'], "vf_input", "input-files",
                                   ctx['main_config']['docking_scenario_inputfolders'][index],
                                   "config.txt"
                                   ),
            'program': program,
            'program_long': program_long,
            'replicas': int(ctx['main_config']['docking_scenario_replicas'][index])
        }


def get_workunit_from_s3(ctx, workunit_id, subjob_id, job_bucket, job_object, download_dir):
    # Download from S3

    download_to_workunit_file = "/".join([download_dir, "vfvs_input.tar.gz"])

    try:
        with open(download_to_workunit_file, 'wb') as f:
            ctx['s3'].download_fileobj(job_bucket, job_object, f)
    except botocore.exceptions.ClientError as error:
        logging.error(
            f"Failed to download from S3 {job_bucket}/{job_object} to {download_to_workunit_file}, ({error})")
        return None

    os.chdir(download_dir)

    # Get the file with the specific workunit we need to work on
    try:
        tar = tarfile.open(download_to_workunit_file)
        tar.extractall()
        file = tar.extractfile(f"vf_input/config.json")

        all_config = json.load(file)
        if(subjob_id in all_config['subjobs']):
            ctx['subjob_config'] = all_config['subjobs'][subjob_id]
        else:
            logging.error(f"There is no subjob ID with ID:{subjob_id}")
            # AWS Batch requires that an array job have at least 2 elements,
            # sometimes we only need 1 though
            if(subjob_id == "1"):
                exit(0)
            else:
                raise RuntimeError(f"There is no subjob ID with ID:{subjob_id}")

        tar.close()
    except Exception as err:
        logging.error(
            f"ERR: Cannot open {download_to_workunit_file}. type: {str(type(err))}, err: {str(err)}")
        return None


    ctx['main_config'] = all_config['config']



def get_workunit_from_sharedfs(ctx, workunit_id, subjob_id, job_tar, download_dir):
    # Download from sharedfs

    download_to_workunit_file = "/".join([download_dir, "vfvs_input.tar.gz"])

    shutil.copyfile(job_tar, download_to_workunit_file)

    os.chdir(download_dir)

    # Get the file with the specific workunit we need to work on
    try:
        tar = tarfile.open(download_to_workunit_file)
        tar.extractall()
        file = tar.extractfile(f"vf_input/config.json")

        all_config = json.load(file)
        if(subjob_id in all_config['subjobs']):
            ctx['subjob_config'] = all_config['subjobs'][subjob_id]
        else:
            logging.error(f"There is no subjob ID with ID:{subjob_id}")
            raise RuntimeError(f"There is no subjob ID with ID:{subjob_id}")

        tar.close()
    except Exception as err:
        logging.error(
            f"ERR: Cannot open {download_to_workunit_file}. type: {str(type(err))}, err: {str(err)}")
        return None


    ctx['main_config'] = all_config['config']


def get_smi(ligand_format, ligand_path):

    valid_formats = ['pdbqt', 'mol2']

    if ligand_format in valid_formats:
        with open(ligand_path, "r") as read_file:
            for line in read_file:
                line = line.strip()
                match = re.search(r"SMILES:\s*(?P<smi>.*)$", line)
                if(match):
                    return match.group('smi')

    return "N/A"



# Generate the run command for a given program

def program_runstring_array(task):

    cpus_per_program = str(task['threads_per_docking'])

    cmd = []

    if(task['program'] == "qvina02"
            or task['program'] == "qvina_w"
            or task['program'] == "vina"
            or task['program'] == "vina_carb"
            or task['program'] == "vina_xb"
            or task['program'] == "gwovina"
            or task['program'] == "AutodockVina_1.2"
       ):
        cmd = [
            f"{task['tools_path']}/{task['program']}",
            '--cpu', cpus_per_program,
            '--config', task['config_path'],
            '--ligand', task['ligand_path'],
            '--out', task['output_path']
        ]
    elif(task['program'] == "smina"):
        cmd = [
            f"{task['tools_path']}/smina",
            '--cpu', cpus_per_program,
            '--config', task['config_path'],
            '--ligand', task['ligand_path'],
            '--out', task['output_path'],
            '--log', f"task['output_path_base'].flexres.pdb",
            '--atom_terms', f"task['output_path_base'].atomterms"
        ]
    elif(task['program'] == "adfr"):
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        cmd = ['adfr', 
               '-t', '{}'.format(config_['receptor']), 
               '-l', '{}'.format(task['ligand_path']), 
               '--jobName', '{}'.format(task['output_path'])
               ]
    elif(task['program'] == "plants"):
        cmd = ['{}/PLANTS'.format(task['tools_path']), 
               '--mode', 'screen', 
                '{}.txt'.format(str(uuid.uuid4()))]
    elif(task['program'] == "AutodockZN"):
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
            else: continue 
        cmd = ['{}/AutodockVina_1.2'.format(task['tools_path']), 
               '--ligand', '{}'.format(task['ligand_path']), 
               '--maps', config_['afinit_maps_name'], 
               '--scoring', 'ad4', 
               '--exhaustiveness', '{}'.format(config_['exhaustiveness']), 
               '--out', '{}'.format(task['output_path'])]
    elif(task['program'] == "gnina"):
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
            else: continue 
        cmd = ['{}/gnina'.format(task['tools_path']), 
               '-r', config_['receptor'], 
               '-l', '{}'.format(task['ligand_path']), 
               '--exhaustiveness', '{}'.format(config_['exhaustiveness']), 
               '--center_x', '{}'.format(config_['center_x']),
               '--center_y', '{}'.format(config_['center_y']),
               '--center_z', '{}'.format(config_['center_z']),
               '--size_x',   '{}'.format(config_['size_x']),
               '--size_y',   '{}'.format(config_['size_y']),
               '--size_z',   '{}'.format(config_['size_z']),  
               '--out', '{}'.format(task['output_path'])]
    elif(task['program'] == "rDock"):
        
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
            else: continue 
        cmd = [ 'rbdock', 
                '-i', task['ligand_path'], 
                '-o', task['output_path'],
                '-r', config_['rdock_config'], 
                '-p', config_['dock_prm'],
                '-n', config_['runs']]
        
    elif(task['program'] == "M-Dock"):
        
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
        cmd = ['{}/MDock_Linux'.format(task['tools_path']), 
                config_['protein_name'], 
                task['ligand_path'],
               '-param', config_['mdock_config']
              ]
    elif(task['program'] == "MCDock"):
    
        cmd = ['{}/mcdock'.format(task['tools_path']), 
                '--target', config_['protein_name'], 
                '--ligand', task['ligand_path']]
    
    elif(task['program'] == "LigandFit"): 
        
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
        
        cmd = ['{}/ligandfit'.format(task['tools_path']), 
               'data=', config_['receptor_mtz'], 
               'model=', config_['receptor'], 
               'ligand', task['ligand_path'],
               'search_center=', config_['center_x'], config_['center_y'], config_['center_z']]
    
    elif(task['program'] == "ledock"): 
        cmd = ['{}/ledock'.format(task['tools_path']), '{}.in'.format(str(uuid.uuid4()))]
        
    elif(task['program'] == "gold"): 
        cmd = ['{}/gold_auto'.format(task['tools_path']), '{}.conf'.format(str(uuid.uuid4()))]

    elif(task['program'] == "iGemDock"): 
                
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
        
        cmd = ['{}/mod_ga'.format(task['tools_path']), 
               config_['exhaustiveness'], 
               config_['receptor'], 
               task['ligand_path'], 
               '-d', str(uuid.uuid4())]

    elif(task['program'] == "idock"): 
                
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
        
        cmd = ['{}/idock'.format(task['tools_path']), 
               '--receptor', config_['receptor'], 
               '--ligand', task['ligand_path'], 
               '--center_x', config_['center_x'],
               '--center_y', config_['center_y'],
               '--center_z', config_['center_z'],
               '--size_x', config_['size_x'],
               '--size_y', config_['size_y'],
               '--size_z', config_['size_z'], 
               '--out', '{}'.format(task['output_path'])]        
    
    elif(task['program'] == "GalaxyDock3"): 
        cmd = ['{}/GalaxyDock3'.format(task['tools_path']), 
               '{}.in'.format(str(uuid.uuid4()))]
        
    elif(task['program'] == "autodock_cpu"):
        
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
        
        cmd = ['{}/autodock_cpu'.format(task['tools_path']), 
               '--ffile', config_['receptor'], 
               '--lfile', task['ligand_path']]
        
    elif(task['program'] == "autodock_gpu"):
        with open(task['config_path']) as fd:
            config_ = dict(read_config_line(line) for line in fd)
        for item in config_: 
            if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
        
        cmd = ['{}/autodock_gpu'.format(task['tools_path']), 
               '--ffile', config_['receptor'], 
               '--lfile', task['ligand_path']]
        
    else:
        raise RuntimeError(f"Invalid program type of {task['program']}")

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

    if(task['get_smi'] == True):
        completion_event['smi'] = get_smi(task['ligand_format'], task['ligand_path'])

    try:
        cmd = program_runstring_array(task)
        
        if(task['program'] == "plants"):
            temp_file = cmd[-1]
            os.system('cp {} {}'.format(task['config_path'], temp_file))
            with open(temp_file, 'a+') as f: 
                f.writelines('ligand_file {}\n'.format(task['ligand_path']))
                f.writelines('output_dir {}\n'.format(task['output_path'])) 
                
        if(task['program'] == "M-Dock"):
            os.system('cp ./mdock_dock.mol2 {}'.format(task['output_path']))
            os.system('rm ./mdock_dock.mol2')
        
        if(task['program'] == 'LigandFit'): 
            os.system('rm -rf PDS')
            os.system('cp ./LigandFit_run_1_/ligand_fit_1.pdb {}'.format(task['output_path']))
        
        if(task['program'] == 'ledock'):
            
            with open(task['config_path']) as fd:
                config_ = dict(read_config_line(line) for line in fd)
            for item in config_: 
                if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
            
            docking_file = cmd[-1]
            ligand_list_file = docking_file.split('.')[0] + '.list'
            
            with open(docking_file, 'w') as f: 
                f.writelines(['Receptor'])
                f.writelines([config_['receptor'] + '\n'])
                f.writelines(['RMSD'])
                f.writelines([config_['rmsd'] + '\n'])
                f.writelines(['Binding pocket'])
                f.writelines(['{} {}'.format( config_['min_x'], config_['max_x']) ])
                f.writelines(['{} {}'.format( config_['min_y'], config_['max_y']) ])
                f.writelines(['{} {}\n'.format( config_['min_z'], config_['max_z']) ])
                f.writelines(['Number of binding poses'])
                f.writelines([config_['n_poses'] + '\n'])
                f.writelines(['Ligands list'])
                f.writelines([ligand_list_file + '\n'])
                f.writelines(['END'])
                
            with open(ligand_list_file, 'w') as f: 
                f.writelines(task['ligand_path'])
                
        if(task['program'] == 'gold'):
            
            with open(task['config_path']) as fd:
                config_ = dict(read_config_line(line) for line in fd)
            for item in config_: 
                if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
            
            conf_file = cmd[-1]
            
            with open(conf_file, 'a+') as f: 
                f.writelines(['  GOLD CONFIGURATION FILE\n'])        
                f.writelines(['  AUTOMATIC SETTINGS'])        
                f.writelines(['autoscale = 1\n'])        
                f.writelines(['  POPULATION']) 
                f.writelines(['popsiz = auto'])        
                f.writelines(['select_pressure = auto'])        
                f.writelines(['n_islands = auto'])        
                f.writelines(['maxops = auto'])        
                f.writelines(['niche_siz = auto\n'])        
                f.writelines(['  GENETIC OPERATORS'])        
                f.writelines(['pt_crosswt = auto'])        
                f.writelines(['allele_mutatewt = auto'])        
                f.writelines(['migratewt = auto\n'])        
                f.writelines(['  FLOOD FILL'])        
                f.writelines(['radius = {}'.format(config_['radius'])])        
                f.writelines(['origin = {}   {}   {}'.format(config_['center_x'], config_['center_y'], config_['center_z'])])
                f.writelines(['do_cavity = 0'])        
                f.writelines(['floodfill_center = point\n'])        
                f.writelines(['   DATA FILES'])        
                f.writelines(['ligand_data_file {} 10'.format(task['ligand_path'])])        
                f.writelines(['param_file = DEFAULT'])        
                f.writelines(['set_ligand_atom_types = 1'])        
                f.writelines(['set_protein_atom_types = 0'])        
                f.writelines(['directory = {}'.format(conf_file.split('.')[0])])        
                f.writelines(['tordist_file = DEFAULT'])        
                f.writelines(['make_subdirs = 0'])        
                f.writelines(['save_lone_pairs = 1'])        
                f.writelines(['fit_points_file = fit_pts.mol2'])        
                f.writelines(['read_fitpts = 0'])        
                f.writelines(['bestranking_list_filename = bestranking.lst\n'])        
                f.writelines(['   FLAGS'])        
                f.writelines(['internal_ligand_h_bonds = 1'])        
                f.writelines(['flip_free_corners = 1'])        
                f.writelines(['match_ring_templates = 1'])        
                f.writelines(['flip_amide_bonds = 0'])        
                f.writelines(['flip_planar_n = 1 flip_ring_NRR flip_ring_NHR'])        
                f.writelines(['flip_pyramidal_n = 0'])        
                f.writelines(['rotate_carboxylic_oh = flip'])        
                f.writelines(['use_tordist = 1'])        
                f.writelines(['postprocess_bonds = 1'])        
                f.writelines(['rotatable_bond_override_file = DEFAULT'])        
                f.writelines(['solvate_all = 1\n'])        
                f.writelines(['   TERMINATION'])        
                f.writelines(['early_termination = 1'])        
                f.writelines(['n_top_solutions = 3'])        
                f.writelines(['rms_tolerance = 1.5\n'])        
                f.writelines(['   CONSTRAINTS'])        
                f.writelines(['force_constraints = 0\n']) 
                f.writelines(['   COVALENT BONDING'])        
                f.writelines(['covalent = 0\n']) 
                f.writelines(['   SAVE OPTIONS'])        
                f.writelines(['save_score_in_file = 1'])        
                f.writelines(['save_protein_torsions = 1\n'])        
                f.writelines(['  FITNESS FUNCTION SETTINGS'])        
                f.writelines(['initial_virtual_pt_match_max = 4'])        
                f.writelines(['relative_ligand_energy = 1'])        
                f.writelines(['gold_fitfunc_path = goldscore'])        
                f.writelines(['score_param_file = DEFAULT\n'])        
                f.writelines(['  PROTEIN DATA'])    
                f.writelines(['protein_datafile = {}'.format(conf_file['receptor'])])  

        if(task['program'] == 'GalaxyDock3'):
            
            with open(task['config_path']) as fd:
                config_ = dict(read_config_line(line) for line in fd)
            for item in config_: 
                if '#' in config_[item]: config_[item] = config_[item].split('#')[0]
                            
            with open(cmd[-1], 'w') as f: 
                f.writelines(['!=============================================='])
                f.writelines(['! I/O Parameters'])
                f.writelines(['!=============================================='])
                f.writelines(['data_directory    ./'])
                f.writelines(['infile_pdb        {}'.format(config_['receptor'])])
                f.writelines(['infile_ligand        {}'.format(task['ligand_path'])])
                f.writelines(['top_type          polarh'])
                f.writelines(['fix_type          all'])
                f.writelines(['ligdock_prefix    {}'.format(cmd[-1].split('.')[0] )])
                f.writelines(['!=============================================='])
                f.writelines(['! Grid Options'])
                f.writelines(['!=============================================='])
                f.writelines(['grid_box_cntr     {} {} {}'.format(config_['grid_box_cntr'].split(' ')[0], config_['grid_box_cntr'].split(' ')[1], config_['grid_box_cntr'].split(' ')[2])])
                f.writelines(['grid_n_elem       {} {} {}'.format(config_['grid_n_elem'].split(' ')[0], config_['grid_n_elem'].split(' ')[1], config_['grid_n_elem'].split(' ')[2])]) 
                f.writelines(['grid_width        {}'.format(config_['grid_width'])])   
                f.writelines(['!=============================================='])
                f.writelines(['! Energy Parameters'])
                f.writelines(['!=============================================='])
                f.writelines(['weight_type              GalaxyDock3'])
                f.writelines(['!=============================================='])
                f.writelines(['! Initial Bank Parameters'])
                f.writelines(['!=============================================='])    
                f.writelines(['first_bank               rand'])
                f.writelines(['max_trial                {}'.format(config_['max_trial'])])
                f.writelines(['e0max                    1000.0'])
                f.writelines(['e1max                    1000000.0'])
                f.writelines(['n_proc 1'])

    except RuntimeError as err:
        logging.error(f"Invalid cmd generation for {task['ligand_key']} (program: '{task['program']}')")
        raise(err)

    try:
        ret = subprocess.run(cmd, capture_output=True,
                         text=True, cwd=task['input_files_dir'], timeout=task['timeout'])
        
    except subprocess.TimeoutExpired as err:
        logging.error(f"timeout on {task['ligand_key']}")
        end_time = time.perf_counter()
        completion_event['seconds'] = end_time - start_time
        return completion_event

    # Delete any temporary files generated for docking: 
    if(task['program'] == "plants"):
        os.system('rm {}'.format(cmd[-1]))

    if ret.returncode == 0:

        if(task['program'] == "qvina02"
                or task['program'] == "qvina_w"
                or task['program'] == "vina"
                or task['program'] == "vina_carb"
                or task['program'] == "vina_xb"
                or task['program'] == "gwovina"
                or task['program'] == "AutodockVina_1.2"
                or task['program'] == "AutodockZN"
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

        elif(task['program'] == "smina" or task['program'] == "gnina"):
            found = 0
            for line in reversed(ret.stdout.splitlines()):
                match = re.search(r'^1\s{4}\s*(?P<value>[-0-9.]+)\s*', line)
                if(match):
                    matches = match.groupdict()
                    completion_event['score'] = float(matches['value'])
                    completion_event['status'] = "success"
                    found = 1
                    break
            if(found == 0):
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")

        elif(task['program'] == "adfr"):
            try: 
                docking_out = ret.stdout.decode("utf-8")
                docking_scores = []
                for item in docking_out: 
                    A = item.split(' ')
                    A = [x for x in A if x != '']
                    try: 
                        _, a_2, _ = float(A[0]), float(A[1]), float(A[2])
                    except: 
                        continue
                    docking_scores.append(float(a_2))
                completion_event['score'] = min(docking_scores)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
                
        elif(task['program'] == "plants"):
            try: 
                plants_cmd = ret.stdout.decode("utf-8").split('\n')[-6]
                score_     = float(plants_cmd.split(' ')[-1])
                completion_event['score'] = score_
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
        elif(task['program'] == "rDOCK"):
            try:
                with open(task['output_path'], 'r') as f: 
                    lines = f.readlines()
                score = []
                for i,item in enumerate(lines):
                    if item.strip() == '>  <SCORE>': 
                        score.append(float(lines[i+1]))
                completion_event['score'] = min(score)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
        elif(task['program'] == "M-Dock"):
            try:
                docking_scores = []
                with open('./mdock_dock.out', 'r') as f: 
                    lines = f.readlines()
                for item in lines: 
                    docking_scores.append( float([x for x in item.split(' ') if x != ''][4]))
                completion_event['score'] = min(docking_scores)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
            os.system('rm ./mdock_dock.out')
        elif(task['program'] == "MCDock"):
            
            try: 
                with open('./out.xyz', 'r') as f: 
                    lines = f.readlines()
                lines = [x for x in lines if 'Binding Energy' in x]
                binding_energies = []
                for item in lines: 
                    binding_energies.append(float(item.split(' ')[2].split('\t')[0]))    
                completion_event['score'] = min(binding_energies)
                completion_event['status'] = "success"    
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
            # Delete/move auxillary files: 
            os.system('rm min.xyz')
            os.system('cp out.xyz {}'.format(task['output_path']))
            os.system('rm out.xyz conformers.xyz')
            
        elif(task['program'] == "LigandFit"): 

            try: 
                with open('./LigandFit_run_1_/ligand_1_1.log', 'r') as f: 
                    lines = f.readlines()
                lines = [x for x in lines if 'Best score' in x]
                scores = []
                for item in lines: 
                    scores.append( float([x for x in item.split(' ') if x != ''][-2]) )
                completion_event['score'] = min(scores)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
            os.system('rm -rf LigandFit_run_1_')
        
        elif(task['program'] == "ledock"): 
            try: 
                os.system('cp ./ligands/{}.dok {}'.format(task['ligand_path'].split('.')[0], task['output_path']))
                with open('{}.dok'.format(task['ligand_path'].split('.')[0]), 'r') as f: 
                    lines = f.readlines()
                lines = [x for x in lines if 'Score' in x]
                scores = []
                for item in lines: 
                    A = item.split('Score')[-1].strip().split(': ')[1].split(' ')[0]
                    scores.append(float(A))
                completion_event['score'] = min(scores)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
            os.system('rm {} {}'.format(cmd[-1], cmd[-1].split('.')[0]+'.list'))
        
        elif(task['program'] == "gold"): 
            
            try: 
                os.system('cp {}/gold_ligand_m1.mol2 {}'.format(cmd[-1].split('.')[0], task['output_path']))
                with open('./{}/ligand_m1.rnk'.format(cmd[-1].split('.')[0]), 'r') as f: 
                    lines = f.readlines()
                docking_score = float([x for x in lines[-1].split(' ') if x!=''][1])
                completion_event['score'] = min(docking_score)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
            os.system('rm -rf {} {}'.format(cmd[-1].split('.')[0], cmd[-1]))

        elif(task['program'] == "gold"): 
            try: 
                docked_pose = os.listdir('./{}/'.format(cmd[-1]))[0]
                os.system('cp {} {}'.format(docked_pose, task['output_path']))
                with open(task['output_path'], 'r') as f: 
                    lines = f.readlines()
                docking_score = lines[4]
                docking_score = float([x for x in docking_score.split(' ') if x!=''][1])
                
                os.system('rm -rf {}'.format(cmd[-1]))
                    
                completion_event['score'] = min(docking_score)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
    
        elif(task['program'] == "idock"): 
            try: 
                docking_out = ret.stdout.decode("utf-8")
                docking_out = float([x for x in docking_out.split(' ') if x != ''][-2])
                completion_event['score'] = min(docking_out)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
        
        elif(task['program'] == "GalaxyDock3"): 
            
            try: 
                prefix = cmd[-1].split('.')[0]
                with open('./{}_fb.E.info'.format(prefix), 'r') as f: 
                    lines = f.readlines()
                lines = lines[3: ]
                docking_scores = []
                for item in lines: 
                    try: 
                        A = item.split(' ')
                        A = [x for x in A if x != '']
                        docking_scores.append(float(A[5]))
                    except: 
                        continue
                
                # Remove auxillary files
                os.system('rm log {}_cl.E.info merged_ligand.mol2 {}_cl.size.info {}_co.info {}_fb.E.info {}_cl.mol2 {}_ib.E.info {}_ib.mol2'.format(prefix, prefix, prefix, prefix, prefix, prefix, prefix))
                # Transfer out_fb.mol2
                os.system('cp {} {}'.format('{}_fb.mol2'.format(prefix), task['output_path']))
                os.system('rm {}_fb.mol2'.format(prefix))
                completion_event['score'] = min(docking_scores)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
        
        elif(task['program'] == "autodock_cpu"): 
            try : 
                output = ret.stdout.decode("utf-8").split('\n')[-6]
                lines = [x.strip() for x in output if 'best energy' in x][0]
                docking_score = float(lines.split(',')[1].split(' ')[-2])
                completion_event['score'] = min(docking_scores)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")
            
        elif(task['program'] == "autodock_gpu"): 
            try : 
                output = ret.stdout.decode("utf-8").split('\n')[-6]
                lines = [x.strip() for x in output if 'best energy' in x][0]
                docking_score = float(lines.split(',')[1].split(' ')[-2])
                completion_event['score'] = min(docking_scores)
                completion_event['status'] = "success"
            except: 
                logging.error(
                    f"Could not find score for {task['collection_key']} {task['ligand_key']} {task['scenario_key']} {task['replica_index']}")

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

    logging.info(f"Finished {task['ligand_key']} in {completion_event['seconds']} sec")

    return completion_event

def get_collection_data(ctx, collection):
    
    ligands = {}

    # Make a place to put the data
    download_dir = Path(ctx['temp_dir']) / collection['collection_name']
    download_dir.mkdir(parents=True, exist_ok=True)
    collection_file = download_dir / f"{collection['collection_number']}.tar.gz"

    if(ctx['job_storage_mode'] == "s3"):
        
        try:
            with collection_file.open(mode = 'wb') as f:
                ctx['s3'].download_fileobj(collection['s3_bucket'], collection['s3_download_path'], f)
        except botocore.exceptions.ClientError as error:
            logging.error(f"Failed to download from S3 {collection['s3_bucket']}/{collection['s3_download_path']} to {str(collection_file)}, ({error})")
            raise
    else:
        shutil.copyfile(Path(collection['sharedfs_path']), collection_file)

    # Extract the ligands from the file

    os.chdir(download_dir)

    try:
        tar = tarfile.open(collection_file)
        for member in tar.getmembers():
            if(not member.isdir()):
                _, ligand = member.name.split("/", 1)

                ligands[ligand] = {
                    'path':  os.path.join(download_dir, collection['collection_number'], ligand)
                }

        tar.extractall()
        tar.close()
    except Exception as err:
        logging.error(
            f"ERR: Cannot open {collection_file} type: {str(type(err))}, err: {str(err)}")
        return None


    return ligands



def preprocess_collection(ctx, collection):
    collection['ligands'] = get_collection_data(ctx, collection)
    collection['log'] = []
    collection['log_json'] = []


def collection_output(ctx, collection, result_type, skip_num=0, tmp_prefix=0, append="", output_addressing="metatranche"):
    path_components = []

    if(tmp_prefix):
        path_components.append(ctx['temp_dir'])

    if(output_addressing == "hash"):

        if(skip_num != 1):
            hash_string = get_collection_hash(collection['collection_name'], collection['collection_number'])

            path_components = [
                hash_string[0:2],
                hash_string[2:4],
                ctx['main_config']['job_letter'],
                "output",
                result_type,
                collection['collection_name'],
                get_formatted_collection_number(collection['collection_number'])
            ]

        else:
            hash_string = get_collection_hash(collection['collection_name'], "0")

            path_components = [
                hash_string[0:2],
                hash_string[2:4],
                ctx['main_config']['job_letter'],
                "output",
                result_type,
                collection['collection_name']
            ]

    else:

        path_components.extend([
            "output", result_type,
            collection['collection_tranche'], collection['collection_name']
        ])

        if(skip_num != 1):
            path_components.append(collection['collection_number'])

    if(append != ""):
        path_components[-1] = f"{path_components[-1]}{append}"

    return path_components



def collection_output_directory_status_gz(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".status.gz"))

def collection_output_directory_status_gz_hash(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".status.gz", output_addressing=ctx['main_config']['object_store_job_addressing_mode']))

def collection_output_directory_status_json_gz(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".json.gz"))

def collection_output_directory_status_json_gz_hash(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".json.gz", output_addressing=ctx['main_config']['object_store_job_addressing_mode']))

def collection_output_directory(ctx, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*collection_output(ctx, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix))

def get_formatted_collection_number(collection_number):
    return f"{int(collection_number):07}"

def get_collection_hash(collection_name, collection_number):

    formatted_collection_number = get_formatted_collection_number(collection_number)
    string_to_hash = f"{collection_name}/{formatted_collection_number}"
    return hashlib.sha256(string_to_hash.encode()).hexdigest()


def scenario_collection_output(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0, append="", output_addressing="metatranche"):
    path_components = []

    if(tmp_prefix):
        path_components.append(ctx['temp_dir'])


    if(output_addressing == "hash"):

        if(skip_num != 1):
            hash_string = get_collection_hash(collection['collection_name'], collection['collection_number'])

            path_components = [
                hash_string[0:2],
                hash_string[2:4],
                ctx['main_config']['job_letter'],
                "output",
                scenario['key'],
                result_type,
                collection['collection_name'],
                get_formatted_collection_number(collection['collection_number'])
            ]

            if(append != ""):
                path_components[-1] = f"{path_components[-1]}{append}"
        else:
            hash_string = get_collection_hash(collection['collection_name'], "0")

            path_components = [
                hash_string[0:2],
                hash_string[2:4],
                ctx['main_config']['job_letter'],
                "output",
                scenario['key'],
                result_type,
                collection['collection_name']
            ]

            if(append != ""):
                path_components[-1] = f"{path_components[-1]}{append}"

    else:

        path_components.extend([
            "output", scenario['key'], result_type,
            collection['collection_tranche'], collection['collection_name']
        ])

        if(skip_num != 1):
            path_components.append(collection['collection_number'])

        if(append != ""):
            path_components[-1] = f"{path_components[-1]}{append}"


    return path_components


def scenario_collection_output_directory(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix))


def scenario_collection_output_directory_tgz(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".tar.gz"))


def scenario_collection_output_directory_tgz_hash(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=".tar.gz", output_addressing=ctx['main_config']['object_store_job_addressing_mode']))


def scenario_collection_output_directory_txt_gz(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0, summary_format="txt.gz"):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=f".{summary_format}"))


def scenario_collection_output_directory_txt_gz_hash(ctx, scenario, collection, result_type, skip_num=0, tmp_prefix=0, summary_format="txt.gz"):
    return os.path.join(*scenario_collection_output(ctx, scenario, collection, result_type, skip_num=skip_num, tmp_prefix=tmp_prefix, append=f".{summary_format}", output_addressing=ctx['main_config']['object_store_job_addressing_mode']))

def get_workunit_information():

    workunit_id = os.getenv('VFVS_WORKUNIT','') 
    subjob_id = os.getenv('VFVS_WORKUNIT_SUBJOB','')

    if(workunit_id == "" or subjob_id == ""):
        raise RuntimeError(f"Invalid VFVS_WORKUNIT and/or VFVS_WORKUNIT_SUBJOB")

    return workunit_id, subjob_id


def setup_job_storage_mode(ctx):

    ctx['job_storage_mode'] = os.getenv('VFVS_JOB_STORAGE_MODE', 'INVALID')

    if(ctx['job_storage_mode'] == "s3"):

        botoconfig = Config(
           region_name = os.getenv('VFVS_AWS_REGION'),
           retries = {
              'max_attempts': 50,
              'mode': 'standard'
           }
        )

        ctx['job_object'] = os.getenv('VFVS_CONFIG_JOB_OBJECT')
        ctx['job_bucket'] = os.getenv('VFVS_CONFIG_JOB_BUCKET')

        # Get the config information
        ctx['s3'] = boto3.client('s3', config=botoconfig)
    
    elif(ctx['job_storage_mode'] == "sharedfs"):
        ctx['job_tar'] = os.getenv('VFVS_CONFIG_JOB_TGZ')
    else:
        raise RuntimeError(f"Invalid jobstoragemode of {ctx['job_storage_mode']}. VFVS_JOB_STORAGE_MODE must be 's3' or 'sharedfs' ")


def get_subjob_config(ctx, workunit_id, subjob_id):

    if(ctx['job_storage_mode'] == "s3"):
        get_workunit_from_s3(ctx, workunit_id, subjob_id, 
            ctx['job_bucket'], ctx['job_object'], ctx['temp_dir'])
    elif(ctx['job_storage_mode'] == "sharedfs"):
        get_workunit_from_sharedfs(ctx, workunit_id, subjob_id,
            ctx['job_tar'], ctx['temp_dir'])
    else:
        raise RuntimeError(f"Invalid jobstoragemode of {ctx['job_storage_mode']}. VFVS_JOB_STORAGE_MODE must be 's3' or 'sharedfs' ")


def create_summary_file(ctx, scenario, collection, scenario_result, output_format="txt.gz", get_smi=False):

    # Open the summary file

    summary_dir = scenario_collection_output_directory(
        ctx, scenario, collection, "summaries", tmp_prefix=1, skip_num=1)

    os.makedirs(summary_dir, exist_ok=True)

    os.chdir(summary_dir)


    if(output_format == "txt.gz"):
        with gzip.open(f"{collection['collection_number']}.txt.gz", "wt") as summmary_fp:

            if(get_smi):
                summmary_fp.write(
                    "Tranche    Compound   SMILES   average-score maximum-score  number-of-dockings ")
            else:
                summmary_fp.write(
                    "Tranche    Compound   average-score maximum-score  number-of-dockings ")

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

                    if(get_smi):
                        summmary_fp.write(
                            f"{collection['collection_full_name']} {ligand_key}     {ligand['smi']}     {avg_score:3.1f}    {max_score:3.1f}     {len(ligand['scores']):5d}   ")
                    else:
                        summmary_fp.write(
                            f"{collection['collection_full_name']} {ligand_key}     {avg_score:3.1f}    {max_score:3.1f}     {len(ligand['scores']):5d}   ")


                    for replica_index in range(scenario['replicas']):
                        summmary_fp.write(
                            f"{ligand['scores'][replica_index]:3.1f}   ")
                    summmary_fp.write("\n")

        return os.path.join(summary_dir, f"{collection['collection_number']}.txt.gz")

    elif(output_format == "parquet"):
        output_filename = f"{collection['collection_number']}.parquet"

        columns = ['collection', 'compound', 'scenario', 'collection_number',
                    'average_score', 'maximum_score', 'minimum_score', 'number_of_dockings','s3_download_path']

        if(get_smi):
            columns.append("SMILES")

        for replica_index in range(scenario['replicas']):
            columns.append(f"score_replica_{replica_index}")

        df = pd.DataFrame(columns = columns)

        for ligand_key in scenario_result['ligands']:
            ligand = scenario_result['ligands'][ligand_key]

            if(len(ligand['scores']) > 0):

                record = {
                    'collection' : collection['collection_name'],
                    'compound' : ligand_key,
                    'scenario' : scenario['key'],
                    'collection_number' : collection['collection_number'],
                    'average_score' : sum(ligand['scores']) / len(ligand['scores']),
                    'maximum_score' : max(ligand['scores']),
                    'minimum_score' : min(ligand['scores']),
                    'number_of_dockings' : len(ligand['scores'])
                }

                if(get_smi):
                    record['SMILES'] = ligand['smi']

                if(ctx['job_storage_mode'] == "s3"):
                    record['s3_download_path'] = collection['s3_download_path']
                else:
                    record['s3_download_path'] = collection['sharedfs_path']

                for replica_index in range(scenario['replicas']):
                    record[f"score_replica_{replica_index}"] = ligand['scores'][replica_index]

            df = df.append(record, ignore_index = True)

        df.to_parquet(output_filename, compression='snappy')

        return os.path.join(summary_dir, output_filename)
    else:
        logging.error(f"Invalid summary format of {output_format}")
        exit(1)




def process(ctx):


    ctx['vcpus_to_use'] = int(os.getenv('VFVS_VCPUS', 1))
    ctx['run_sequential'] = int(os.getenv('VFVS_RUN_SEQUENTIAL', 0))

    # What job are we running?

    workunit_id, subjob_id =  get_workunit_information()

    # Setup paths appropriately depending on if we are using S3
    # or a shared FS
    
    setup_job_storage_mode(ctx)

    # This includes all of the configuration information we need
    # After this point ctx['main_config'] has the configuration options
    # and we have specific subjob information in ctx['subjob_config']

    get_subjob_config(ctx, workunit_id, subjob_id)

    # Update some of the path information

    process_config(ctx)

    print(ctx['temp_dir'])

    ligand_format = ctx['main_config']['ligand_library_format']

    get_smi = 0
    if('print_smi_in_summary' in ctx['main_config'] and int(ctx['main_config']['print_smi_in_summary']) == 1):
        get_smi = True


    # Need to expand out all of the collections in this subjob
    
    subjob = ctx['subjob_config']

    collections = {}
    for collection_key in subjob['collections']:
        collection = subjob['collections'][collection_key]
 
        collection_full_name = collection['collection_full_name']
        collection_count = collection['ligand_count']

        preprocess_collection(ctx, collection)
        collections[collection_full_name] = collection


    logging.info(f"Finished processing collections")

    # Setup the data structure where we will keep the summary information
    scenario_results = {}
    for scenario_key in ctx['main_config']['docking_scenarios']:
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

            logging.debug(f"pre-processing {ligand_key}")

            # Check to see if ligand contains B, Si, Sn or has duplicate coordinates
            with open(ligand['path'], "r") as read_file:
                for index, line in enumerate(read_file):
                    
                    if ctx['config']['run_atom_check']: 
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
    for scenario_key in ctx['main_config']['docking_scenarios']:
        scenario = ctx['main_config']['docking_scenarios'][scenario_key]

        logging.debug(f"Generating scenario information for '{scenario_key}', program '{scenario['program']}'")

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

                logging.debug(f"Adding {ligand_key} to tasklist")

                # For each replica
                for replica_index in range(scenario['replicas']):

                    task = {
                        'collection_key': collection_key,
                        'ligand_key': ligand_key,
                        'ligand_format': ligand_format,
                        'scenario_key': scenario_key,
                        'config_path': scenario['config'],
                        'program': scenario['program'],
                        'program_long': scenario['program_long'],
                        'replica_index': replica_index,
                        'ligand_path': ligand['path'],
                        'output_path_base': os.path.join(results_dir, f'{ligand_key}_replica-{replica_index}'),
                        'output_path': os.path.join(results_dir, f'{ligand_key}_replica-{replica_index}.{ligand_format}'),
                        'log_path': os.path.join(log_dir, f'{ligand_key}_replica-{replica_index}'),
                        'input_files_dir':  os.path.join(ctx['temp_dir'], "vf_input", "input-files"),
                        'timeout': int(ctx['main_config']['program_timeout']),
                        'tools_path': ctx['tools_path'],
                        'threads_per_docking': int(ctx['main_config']['threads_per_docking']),
                        'get_smi': get_smi,
                    }

                    tasklist.append(task)

    # At this point we have all of the individual tasks generated. The next step is to divide these up to
    # multiple processes in a pool. Each task will run independently and generate results

    logging.info(f"Starting processing ligands with {ctx['vcpus_to_use']} vcpus")

    with multiprocessing.Pool(processes=ctx['vcpus_to_use']) as pool:
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
            if 'smi' in task_result:
                scenario_results[scenario_key][collection_key]['ligands'][ligand_key]['smi'] = task_result['smi']
        else:
            collection['log'].append(
                f"{ligand_key} {scenario_key} {replica_index} {task_result['status']} total-time:{task_result['seconds']:.2f}")
            collection['log_json'].append({'ligand': ligand_key, 'scenario_key': scenario_key, 'replica_index': replica_index,
                                          'status': task_result['status'], 'seconds': f"{task_result['seconds']:.2f}"})

    # Now we can generate the summary files
    for scenario_key in ctx['main_config']['docking_scenarios']:
        scenario = ctx['main_config']['docking_scenarios'][scenario_key]
        for collection_key in collections:
            collection = collections[collection_key]
            scenario_result = scenario_results[scenario_key][collection_key]

            for summary_format in ctx['main_config']['summary_formats']:
                output_name = create_summary_file(
                    ctx, scenario, collection, scenario_result, output_format=summary_format, get_smi=get_smi)

    # Generate the compressed files

    for scenario_key in ctx['main_config']['docking_scenarios']:
        scenario = ctx['main_config']['docking_scenarios'][scenario_key]
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

    for scenario_key in ctx['main_config']['docking_scenarios']:
        scenario = ctx['main_config']['docking_scenarios'][scenario_key]
        for collection_key in collections:
            collection = collections[collection_key]

            logging.info(f"Completed scenario: {scenario_key}, collection: {collection_key}")

            # Copy the results..
            copy_output(ctx,
                        {
                            'src': scenario_collection_output_directory_tgz(ctx, scenario, collection, 'results', tmp_prefix=1),
                            'dest_path': scenario_collection_output_directory_tgz_hash(ctx, scenario, collection, 'results', tmp_prefix=0),
                        }
                        )

            copy_output(ctx,
                        {
                            'src': scenario_collection_output_directory_tgz(ctx, scenario, collection, 'logfiles', tmp_prefix=1),
                            'dest_path': scenario_collection_output_directory_tgz_hash(ctx, scenario, collection, 'logfiles', tmp_prefix=0),
                        }
                        )

            for summary_format in ctx['main_config']['summary_formats']:
                copy_output(ctx,
                            {
                                'src': scenario_collection_output_directory_txt_gz(ctx, scenario, collection, 'summaries', tmp_prefix=1, summary_format=summary_format),
                                'dest_path': scenario_collection_output_directory_txt_gz_hash(ctx, scenario, collection, 'summaries', tmp_prefix=0, summary_format=summary_format),
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
                        'dest_path': collection_output_directory_status_gz_hash(ctx, collection, "ligand-lists", tmp_prefix=0),
                    }
                    )

        with gzip.open(ligand_log_file_json, "wt") as summmary_fp:
            json.dump(collection['log_json'], summmary_fp, indent=4)

        # Now transfer over JSON file
        copy_output(ctx,
                    {
                        'src': ligand_log_file_json,
                        'dest_path': collection_output_directory_status_json_gz_hash(ctx, collection, "ligand-lists", tmp_prefix=0),
                    }
                    )


def copy_output(ctx, obj):


    if(ctx['job_storage_mode'] == "s3"):
        if(ctx['main_config']['object_store_job_addressing_mode'] == "hash"):
            object_name = f"{ctx['main_config']['object_store_job_prefix']}/{obj['dest_path']}"
        else:
            object_name = f"{ctx['main_config']['object_store_job_prefix_full']}/{obj['dest_path']}"

        try:
            response = ctx['s3'].upload_file(
                obj['src'], ctx['main_config']['object_store_job_bucket'], object_name)
        except botocore.exceptions.ClientError as e:
            logging.error(e)

            # We want to fail if this happens...
            raise(e)
            return False

        logging.info(f"Copied output to '{object_name}'' in bucket '{ctx['main_config']['object_store_job_bucket']}'")

    elif(ctx['job_storage_mode'] == "sharedfs"):

        copy_to_location = f"{ctx['main_config']['sharedfs_workflow_path']}/{obj['dest_path']}"

        parent_directory = Path(Path(copy_to_location).parent)
        parent_directory.mkdir(parents=True, exist_ok=True)

        shutil.copyfile(obj['src'], copy_to_location)

        logging.info(f"Copied output to '{copy_to_location}'")
    else:
        logging.error("invalid job storage mode")



    return True


def generate_tarfile(ctx, dir):
    os.chdir(str(Path(dir).parents[0]))

    with tarfile.open(f"{os.path.basename(dir)}.tar.gz", "x:gz") as tar:
        tar.add(os.path.basename(dir))

    return os.path.join(str(Path(dir).parents[0]), f"{os.path.basename(dir)}.tar.gz")


def main():

    ctx = {}

    log_level = os.environ.get('VFVS_LOGLEVEL', 'INFO').upper()
    logging.basicConfig(level=log_level)

    ctx['tools_path'] = os.getenv('VFVS_TOOLS_PATH', "/opt/vf/tools/bin")

    # Temp directory information
    temp_path = os.getenv('VFVS_TMP_PATH', None)
    if(temp_path):
        temp_path = os.path.join(temp_path, '')

    with tempfile.TemporaryDirectory(prefix=temp_path) as temp_dir:
        ctx['temp_dir'] = temp_dir

        # stat = shutil.disk_usage(path)
        stat = shutil.disk_usage(ctx['temp_dir'])
        if(stat.free < (1024 * 1024 * 1024 * 1)):
            raise RuntimeError(f"VFVS needs at least 1GB of space free in tmp dir ({ctx['temp_dir']}) free: {stat.free} bytes")


        print(ctx['temp_dir'])
        process(ctx)


if __name__ == '__main__':
    main()
