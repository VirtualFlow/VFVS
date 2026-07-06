#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Trains the optional ML tranche-prioritization classifier (see tools/templates/ml_classifier.py) on
the results of a prescreen run of VFVS.

Usage: run VFVS's existing, unmodified workflow (all.ctrl + submit/AWS Batch + one-queue.sh or
vf_aws_run.py) on a small representative "prescreen" set of collections first, to produce real
docking scores. This generates the usual per-collection summary files under
output-files/{complete,incomplete}/<scenario>/summaries/. Then, run this script once (a single
interactive invocation from the tools/ directory -- no Slurm/AWS Batch job needed, since training
the classifier only takes seconds):

    python3 train_ml_classifier.py --scenario <docking_scenario_name>

This reads ml_classifier_model_path from workflow/control/all.ctrl, collects every summary file
for the given docking scenario, extracts (SMILES, docking score) pairs, and trains+saves the
classifier. Once saved, set use_ml_classifier=true in all.ctrl and run the primary screen as usual
-- both the Slurm and AWS Batch paths will load this classifier and filter collections before
docking.

Both VFVS execution paths write the same summary schema (Tranch Compound SMILES average-score
maximum-score number-of-dockings score-replica-*), so this script works identically regardless of
whether the prescreen ran on Slurm or AWS Batch.

@author: akshat
"""
import os
import sys
import glob
import gzip
import argparse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates'))
# ml_classifier.py lives in templates/ (not alongside this script) so that it is automatically
# bundled into the AWS Batch Docker image (which ADDs the whole tools/ tree) and importable via a
# relative path from one-queue.sh's cwd. This script is not part of that runtime path, so it needs
# to add templates/ to sys.path explicitly.
from ml_classifier import train_classifier, load_classifier  # noqa: E402


def read_config_file(filename):
    """
    Minimal, standalone re-implementation of VFVS's `key=value` control-file convention (see
    all.ctrl). Deliberately not shared with one-queue.sh/vf_aws_run.py's own config-reading code
    (bash grep-idiom / parse_config()), since neither is meant to be invoked from a plain
    standalone Python script like this one; a few lines of duplication here is simpler and safer
    than trying to reuse either.
    """
    params = {}
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' not in line:
                continue
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.split('#', 1)[0].strip()
            if key:
                params[key] = value
    return params


def parse_summary_files(summaries_glob):
    """
    Parses VFVS summary files (gzip'd, whitespace-columnar) into (smiles, docking_score) pairs.

    Expected columns (both Slurm and AWS Batch write this same schema): Tranch, Compound, SMILES,
    average-score, maximum-score, number-of-dockings, score-replica-0, .... The "maximum-score"
    column is (despite its name) the best/most-negative docking score across replicas -- used
    here as the training label, per the manuscript's "docking scores obtained during the
    prescreen" definition. The header line (starting with "Tranch") is skipped. Malformed lines
    (wrong column count, non-numeric score) are skipped with a warning rather than aborting the
    whole run.

    Args:
        summaries_glob (str): glob pattern matching gzip'd summary files, e.g.
            '../output-files/complete/<scenario>/summaries/**/*.txt.gz'.

    Returns:
        (smiles_list, scores_list)

    Raises:
        Exception: if no matching summary files are found, or no valid rows could be parsed.
    """
    summary_files = sorted(glob.glob(summaries_glob, recursive=True))
    if len(summary_files) == 0:
        raise Exception('No summary files found matching: {}'.format(summaries_glob))

    smiles_list = []
    scores_list = []
    n_malformed = 0
    for summary_file in summary_files:
        with gzip.open(summary_file, 'rt') as f:
            for line_number, line in enumerate(f, start=1):
                line = line.strip()
                if not line or line.startswith('Tranch'):
                    continue
                fields = line.split()
                if len(fields) < 5:
                    n_malformed += 1
                    print('WARNING: Skipping malformed line {}:{}: {}'.format(
                        summary_file, line_number, line))
                    continue
                smi = fields[2]
                try:
                    score = float(fields[4])
                except ValueError:
                    n_malformed += 1
                    print('WARNING: Skipping malformed line {}:{}: {}'.format(
                        summary_file, line_number, line))
                    continue
                smiles_list.append(smi)
                scores_list.append(score)

    print('Parsed {} summary files: {} valid docking scores, {} malformed lines skipped.'.format(
        len(summary_files), len(smiles_list), n_malformed))

    if len(smiles_list) == 0:
        raise Exception('No valid docking scores found in summary files matching: {}'.format(summaries_glob))

    return smiles_list, scores_list


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scenario', required=True,
                        help='Docking scenario name whose prescreen summaries to train on.')
    parser.add_argument('--ctrl-file', default='../workflow/control/all.ctrl',
                        help='Path to all.ctrl (for ml_classifier_model_path).')
    parser.add_argument('--summaries-glob', default=None,
                        help='Glob pattern for prescreen summary files. Defaults to '
                             '../output-files/{complete,incomplete}/<scenario>/summaries/**/*.txt.gz')
    parser.add_argument('--top-percent', type=float, default=25,
                        help='Percentage of most-negative-scoring prescreen compounds labeled positive.')
    parser.add_argument('--seed', type=int, default=42, help='Random seed.')
    args = parser.parse_args()

    config_params = read_config_file(args.ctrl_file)
    model_relative_path = config_params.get('ml_classifier_model_path', 'ml_classifier/model.pt')
    model_out_path = os.path.join('..', 'input-files', model_relative_path)

    if args.summaries_glob is not None:
        summaries_globs = [args.summaries_glob]
    else:
        summaries_globs = [
            '../output-files/complete/{}/summaries/**/*.txt.gz'.format(args.scenario),
            '../output-files/incomplete/{}/summaries/**/*.txt.gz'.format(args.scenario),
        ]

    smiles_list = []
    scores_list = []
    for summaries_glob in summaries_globs:
        try:
            smi_part, score_part = parse_summary_files(summaries_glob)
            smiles_list.extend(smi_part)
            scores_list.extend(score_part)
        except Exception as e:
            print('NOTE: {}'.format(e))

    if len(smiles_list) == 0:
        raise Exception('No valid docking scores found across any of: {}'.format(summaries_globs))

    if os.path.isfile(model_out_path):
        try:
            _, existing_metadata = load_classifier(model_out_path)
            existing_receptor = existing_metadata.get('receptor')
            if existing_receptor is not None and existing_receptor != args.scenario:
                print('WARNING: {} already exists and was trained for scenario "{}". '
                      'Overwriting with a model trained for scenario "{}".'.format(
                          model_out_path, existing_receptor, args.scenario))
        except Exception:
            pass  # existing file is unreadable/corrupt; fine to overwrite

    model, history = train_classifier(smiles_list, scores_list, model_out_path,
                                       top_percent=args.top_percent, receptor=args.scenario, seed=args.seed)

    print('Classifier trained on {} prescreen compounds (best epoch {}, best val loss {:.4f}).'.format(
        len(smiles_list), history['best_epoch'] + 1, min(history['val_loss'])))
    print('Saved to: {}'.format(model_out_path))
    print('To use it for the primary screen, set use_ml_classifier=true and ml_classifier_model_path={} '
          'in {}.'.format(model_relative_path, args.ctrl_file))
