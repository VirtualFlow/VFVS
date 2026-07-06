#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Optional machine learning classifier for prioritizing candidate compounds before docking.

Implements the "Machine Learning Classifier for Tranche Prioritization" described in the
AdaptiveFlow manuscript (Methods section): a fully-connected feedforward neural network (FNN)
trained on Morgan fingerprints and prescreen docking scores, used to filter a large pool of
undocked candidate compounds down to those predicted to be high-confidence binders before they
are passed into the docking pipeline.

Shared between VFVS's two execution paths: imported directly by vf_aws_run.py (AWS Batch), and
invoked via the small CLI wrapper ml_classifier_predict.py from one-queue.sh (Slurm/HPC, which
cannot run PyTorch directly since it is a Bash script). Filtering operates on whatever ligands a
collection already contains -- this module has no knowledge of tranches, collections, or joblines.

@author: akshat
"""
import os
import random
import uuid

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import TensorDataset, DataLoader

from rdkit import Chem
from rdkit.Chem import AllChem


def get_device(device=None):
    """
    Resolves the torch device to use, preferring CUDA when available.

    Args:
        device (str or torch.device or None): explicit device to use. If None, 'cuda' is used
            when available, else 'cpu'.

    Returns:
        torch.device
    """
    if device is not None:
        return torch.device(device)
    return torch.device('cuda' if torch.cuda.is_available() else 'cpu')


def set_seed(seed):
    """
    Seeds python's random module, numpy, and torch (including CUDA, if available) for
    reproducibility.

    Args:
        seed (int): random seed to use.

    Returns:
        None
    """
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


class FNNClassifier(nn.Module):
    """
    Fully-connected feedforward neural network for binary binding-likelihood classification.

    Architecture (matches the manuscript exactly): an input layer of 1,024 nodes (matching the
    Morgan fingerprint length), followed by hidden layers of 512, 256, and 128 nodes, each using
    ReLU activation, followed by a single sigmoid-activated output node representing the
    predicted binding probability.
    """

    def __init__(self, input_dim=1024):
        super(FNNClassifier, self).__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, 512),
            nn.ReLU(),
            nn.Linear(512, 256),
            nn.ReLU(),
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.Linear(128, 1),
            nn.Sigmoid(),
        )

    def forward(self, x):
        return self.net(x)


def smi_to_fingerprint(smi, radius=2, n_bits=1024):
    """
    Converts a SMILES string into a Morgan fingerprint (radius 2, 1024 bits by default, as
    specified in the manuscript).

    Args:
        smi (str): SMILES string of the compound.
        radius (int): Morgan fingerprint radius.
        n_bits (int): Morgan fingerprint bit-vector length.

    Returns:
        np.ndarray of shape (n_bits,), dtype float32, or None if the SMILES could not be parsed
        (including an empty string, which VFVS uses to represent a ligand whose SMILES could not
        be extracted from its structure file).
    """
    if not smi:
        return None
    mol = Chem.MolFromSmiles(smi)
    if mol is None:
        print('WARNING: Invalid SMILES provided, skipping: {}'.format(smi))
        return None
    fp = AllChem.GetMorganFingerprintAsBitVect(mol, radius, nBits=n_bits)
    arr = np.zeros((n_bits,), dtype=np.float32)
    for bit in fp.GetOnBits():
        arr[bit] = 1.0
    return arr


def _fingerprint_all(smiles_list, radius=2, n_bits=1024):
    """
    Fingerprints a list of SMILES, dropping any that fail to parse.

    Returns:
        (kept_indices, fingerprint_matrix) where kept_indices maps rows of the matrix back to
        indices in the original smiles_list.
    """
    kept_indices = []
    fps = []
    for i, smi in enumerate(smiles_list):
        fp = smi_to_fingerprint(smi, radius=radius, n_bits=n_bits)
        if fp is not None:
            kept_indices.append(i)
            fps.append(fp)
    if len(fps) == 0:
        return [], np.zeros((0, n_bits), dtype=np.float32)
    return kept_indices, np.stack(fps, axis=0)


def label_by_top_percent(scores, top_percent=25):
    """
    Converts docking scores into binary labels via percentile thresholding.

    More negative docking scores indicate better (higher-affinity) binding. The top
    `top_percent` % of compounds with the most negative scores are labeled 1 ("high-confidence
    binder"); the rest are labeled 0. This is implemented directly as a percentile cutoff on the
    raw (ascending) scores to avoid any ambiguity about which "direction" a percentile is taken
    from.

    Args:
        scores (np.ndarray): docking scores (more negative = better).
        top_percent (float): percentage (0-100) of best (most negative) scores to label positive.

    Returns:
        (labels_ndarray, threshold_value): labels is an int array (0/1) aligned with `scores`,
            threshold_value is the score cutoff at/below which a compound is labeled positive.
    """
    threshold = np.percentile(scores, top_percent)
    labels = (scores <= threshold).astype(np.int64)
    return labels, float(threshold)


def undersample_majority(X, y, seed=42):
    """
    Randomly undersamples the majority class so that both classes are equally represented.

    Args:
        X (np.ndarray): feature matrix, shape (n_samples, n_features).
        y (np.ndarray): binary labels (0/1), shape (n_samples,).
        seed (int): random seed for reproducible undersampling.

    Returns:
        (X_balanced, y_balanced)
    """
    rng = np.random.RandomState(seed)
    pos_idx = np.where(y == 1)[0]
    neg_idx = np.where(y == 0)[0]

    if len(pos_idx) == 0 or len(neg_idx) == 0:
        return X, y

    if len(pos_idx) < len(neg_idx):
        minority_idx, majority_idx = pos_idx, neg_idx
    else:
        minority_idx, majority_idx = neg_idx, pos_idx

    sampled_majority_idx = rng.choice(majority_idx, size=len(minority_idx), replace=False)
    balanced_idx = np.concatenate([minority_idx, sampled_majority_idx])
    rng.shuffle(balanced_idx)
    return X[balanced_idx], y[balanced_idx]


def stratified_val_split(X, y, val_fraction=0.10, seed=42):
    """
    Splits a (class-balanced) dataset into train/validation partitions, preserving the class
    balance of each partition.

    Args:
        X (np.ndarray): feature matrix.
        y (np.ndarray): binary labels.
        val_fraction (float): fraction of samples to hold out for validation.
        seed (int): random seed.

    Returns:
        (X_train, y_train, X_val, y_val)
    """
    rng = np.random.RandomState(seed)
    train_idx_parts = []
    val_idx_parts = []
    for cls in np.unique(y):
        cls_idx = np.where(y == cls)[0]
        rng.shuffle(cls_idx)
        n_val = max(1, int(round(len(cls_idx) * val_fraction))) if len(cls_idx) > 1 else 0
        val_idx_parts.append(cls_idx[:n_val])
        train_idx_parts.append(cls_idx[n_val:])

    train_idx = np.concatenate(train_idx_parts)
    val_idx = np.concatenate(val_idx_parts)
    rng.shuffle(train_idx)
    rng.shuffle(val_idx)
    return X[train_idx], y[train_idx], X[val_idx], y[val_idx]


def train_classifier(smiles_list, scores, model_out_path, top_percent=25, val_fraction=0.10,
                      batch_size=256, max_epochs=50, patience=5, learning_rate=0.001,
                      seed=42, receptor=None, fp_radius=2, fp_nbits=1024, device=None,
                      verbose=True):
    """
    Trains the FNN tranche-prioritization classifier on prescreen docking results.

    Args:
        smiles_list (list of str): SMILES strings of the prescreen compounds.
        scores (list or np.ndarray of float): docking scores aligned with smiles_list (more
            negative = better binder), as produced by a prescreen run (see
            train_ml_classifier.py, which parses these out of VFVS's summary files).
        model_out_path (str): path to save the trained model (.pt file).
        top_percent (float): percentage of most-negative-scoring prescreen compounds labeled as
            positive ("high-confidence binder"). Default 25, per the manuscript.
        val_fraction (float): validation split fraction. Default 0.10, per the manuscript.
        batch_size (int): training batch size. Default 256, per the manuscript.
        max_epochs (int): maximum number of training epochs. Default 50, per the manuscript.
        patience (int): early-stopping patience (epochs without validation-loss improvement).
            Default 5, per the manuscript.
        learning_rate (float): Adam learning rate. Default 0.001, per the manuscript.
        seed (int): random seed for undersampling, splitting, and model initialization.
        receptor (str or None): optional receptor identifier/path stored as metadata, so a
            saved model can later be associated with the target it was trained for.
        fp_radius (int): Morgan fingerprint radius.
        fp_nbits (int): Morgan fingerprint length.
        device (str or None): torch device override. Auto-detected (CUDA if available) if None.
        verbose (bool): whether to print per-epoch training/validation loss.

    Returns:
        (model, history): the trained FNNClassifier (in eval mode, on `device`), and a dict with
            keys 'train_loss', 'val_loss' (lists, one entry per epoch actually run), and
            'best_epoch'.

    Raises:
        Exception: if fewer than 2 classes are present after labeling (cannot train a
            classifier), or if no SMILES in the prescreen data could be parsed.
    """
    set_seed(seed)
    device = get_device(device)

    scores = np.asarray(scores, dtype=np.float32)
    kept_indices, X_all = _fingerprint_all(smiles_list, radius=fp_radius, n_bits=fp_nbits)
    if X_all.shape[0] == 0:
        raise Exception('No valid SMILES found in prescreen data.')
    scores_kept = scores[kept_indices]

    labels, threshold = label_by_top_percent(scores_kept, top_percent=top_percent)
    if len(np.unique(labels)) < 2:
        raise Exception('Only one class present after labeling (top_percent={}); '
                         'cannot train a binary classifier. Provide more diverse prescreen '
                         'docking scores.'.format(top_percent))

    X_bal, y_bal = undersample_majority(X_all, labels, seed=seed)
    X_train, y_train, X_val, y_val = stratified_val_split(X_bal, y_bal, val_fraction=val_fraction,
                                                           seed=seed)

    train_ds = TensorDataset(torch.from_numpy(X_train), torch.from_numpy(y_train.astype(np.float32)))
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)

    X_val_t = torch.from_numpy(X_val).to(device)
    y_val_t = torch.from_numpy(y_val.astype(np.float32)).to(device)

    model = FNNClassifier(input_dim=fp_nbits).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    loss_fn = nn.BCELoss()

    history = {'train_loss': [], 'val_loss': []}
    best_val_loss = float('inf')
    best_state_dict = None
    best_epoch = 0
    epochs_without_improvement = 0

    for epoch in range(max_epochs):
        model.train()
        epoch_train_losses = []
        for xb, yb in train_loader:
            xb, yb = xb.to(device), yb.to(device)
            optimizer.zero_grad()
            preds = model(xb).squeeze(1)
            loss = loss_fn(preds, yb)
            loss.backward()
            optimizer.step()
            epoch_train_losses.append(loss.item())
        train_loss = float(np.mean(epoch_train_losses))

        model.eval()
        with torch.no_grad():
            val_preds = model(X_val_t).squeeze(1)
            val_loss = float(loss_fn(val_preds, y_val_t).item())

        history['train_loss'].append(train_loss)
        history['val_loss'].append(val_loss)
        if verbose:
            print('Epoch {}/{} - train_loss: {:.4f} - val_loss: {:.4f}'.format(
                epoch + 1, max_epochs, train_loss, val_loss))

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_state_dict = {k: v.clone() for k, v in model.state_dict().items()}
            best_epoch = epoch
            epochs_without_improvement = 0
        else:
            epochs_without_improvement += 1
            if epochs_without_improvement >= patience:
                if verbose:
                    print('Early stopping at epoch {} (patience={})'.format(epoch + 1, patience))
                break

    model.load_state_dict(best_state_dict)
    model.eval()

    metadata = {
        'input_dim': fp_nbits,
        'fp_radius': fp_radius,
        'fp_nbits': fp_nbits,
        'top_percent': top_percent,
        'train_threshold': threshold,
        'seed': seed,
        'receptor': receptor,
        'best_epoch': best_epoch,
        'best_val_loss': best_val_loss,
    }
    save_classifier(model, model_out_path, metadata)
    history['best_epoch'] = best_epoch

    return model, history


def save_classifier(model, out_path, metadata):
    """
    Saves a trained FNNClassifier's weights and associated metadata to disk.

    Args:
        model (FNNClassifier): the trained model.
        out_path (str): destination path (.pt file). Parent directories are created if needed.
        metadata (dict): metadata to store alongside the weights (fingerprint params, threshold,
            seed, receptor, etc.), retrievable via load_classifier().

    Returns:
        None

    Note:
        Written atomically (temp file + os.replace) so that concurrent readers -- e.g. many
        independent Slurm queue processes or AWS Batch array children calling load_classifier()
        on this same path -- never observe a partially-written checkpoint, even if this function
        is called again (retraining) while a previous screen using the model is still running.
    """
    out_dir = os.path.dirname(out_path)
    if out_dir != '' and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)
    checkpoint = {'state_dict': model.state_dict()}
    checkpoint.update(metadata)

    tmp_path = '{}.tmp-{}'.format(out_path, uuid.uuid4().hex)
    torch.save(checkpoint, tmp_path)
    os.replace(tmp_path, out_path)


def load_classifier(model_path, device=None):
    """
    Loads a previously trained FNNClassifier from disk.

    Args:
        model_path (str): path to a .pt file created by save_classifier()/train_classifier().
        device (str or None): torch device override. Auto-detected (CUDA if available) if None.

    Returns:
        (model, metadata): the FNNClassifier in eval mode on `device`, and the metadata dict
            saved alongside the weights.

    Raises:
        Exception: if model_path does not exist or is not a file.
    """
    if not os.path.isfile(model_path):
        raise Exception('Model path {} not found.'.format(model_path))
    device = get_device(device)
    checkpoint = torch.load(model_path, map_location=device)
    input_dim = checkpoint.get('input_dim', 1024)
    model = FNNClassifier(input_dim=input_dim).to(device)
    model.load_state_dict(checkpoint['state_dict'])
    model.eval()
    metadata = {k: v for k, v in checkpoint.items() if k != 'state_dict'}
    return model, metadata


def predict_proba(model, smiles_list, device=None, fp_radius=2, fp_nbits=1024):
    """
    Predicts binding probability for a list of SMILES using a trained classifier.

    Args:
        model (FNNClassifier): a trained (eval-mode) model, as returned by load_classifier() or
            train_classifier().
        smiles_list (list of str): SMILES strings to score.
        device (str or None): torch device override. Auto-detected (CUDA if available) if None.
        fp_radius (int): Morgan fingerprint radius (must match training).
        fp_nbits (int): Morgan fingerprint length (must match training).

    Returns:
        list of (smi, probability_or_None), aligned with `smiles_list` in order. Invalid or empty
        SMILES yield a probability of None.
    """
    device = get_device(device)
    model = model.to(device)
    model.eval()

    kept_indices, X = _fingerprint_all(smiles_list, radius=fp_radius, n_bits=fp_nbits)
    results = [None] * len(smiles_list)

    if X.shape[0] > 0:
        with torch.no_grad():
            X_t = torch.from_numpy(X).to(device)
            probs = model(X_t).squeeze(1).cpu().numpy()
        for local_i, orig_i in enumerate(kept_indices):
            results[orig_i] = float(probs[local_i])

    return [(smi, results[i]) for i, smi in enumerate(smiles_list)]


def filter_smiles_mask(model, smiles_list, probability_cutoff=0.5, device=None,
                        fp_radius=2, fp_nbits=1024):
    """
    Scores a list of SMILES and returns a keep/discard mask, for filtering an in-memory batch of
    candidate ligands before they are submitted for docking.

    Ligands whose SMILES could not be extracted/parsed (probability is None) are always treated
    as discards (fail-closed) -- if the ML classifier is enabled, an unscoreable ligand is an
    unexpected state and it is safer to not spend docking budget on it than to silently bypass
    the filter the user opted into.

    Args:
        model (FNNClassifier): a trained (eval-mode) model.
        smiles_list (list of str): SMILES strings to score.
        probability_cutoff (float): minimum predicted probability (exclusive) to retain a
            compound for docking. Default 0.5, per the manuscript.
        device (str or None): torch device override. Auto-detected (CUDA if available) if None.
        fp_radius (int): Morgan fingerprint radius (must match training).
        fp_nbits (int): Morgan fingerprint length (must match training).

    Returns:
        (keep_mask, probabilities): keep_mask is a list of bool aligned with smiles_list (True =
            retain for docking); probabilities is the aligned list of predicted probabilities
            (None for compounds with invalid/empty SMILES, which are always discarded).
    """
    scored = predict_proba(model, smiles_list, device=device, fp_radius=fp_radius, fp_nbits=fp_nbits)
    keep_mask = [prob is not None and prob > probability_cutoff for _, prob in scored]
    probabilities = [prob for _, prob in scored]
    return keep_mask, probabilities


if __name__ == '__main__':
    # Synthetic self-test: exercises train -> save -> load -> filter end-to-end without
    # requiring any real docking runs. Fabricated docking scores are correlated with a simple
    # RDKit descriptor (heavy-atom count) plus noise, so there is real learnable signal.
    from rdkit.Chem import Descriptors

    SCRATCH_DIR = './ml_classifier_selftest'
    os.makedirs(SCRATCH_DIR, exist_ok=True)

    demo_smiles = [
        'CCO', 'CCCO', 'CCCCO', 'CCCCCO', 'CCN', 'CCCN', 'CCCCN', 'c1ccccc1', 'c1ccccc1C',
        'c1ccccc1CC', 'c1ccccc1O', 'c1ccccc1N', 'CC(=O)O', 'CC(=O)N', 'CC(=O)OC', 'CC(=O)OCC',
        'CCOC(=O)C', 'c1ccncc1', 'c1ccoc1', 'c1ccsc1', 'C1CCCCC1', 'C1CCCCC1O', 'C1CCCCC1N',
        'CC(C)C', 'CC(C)CC', 'CC(C)(C)C', 'C1=CC(=CC=C1CSCC2C(C(C(O2)N3C=NC4=C(N=CN=C43)N)O)O)Cl',
        'CCCCCCCCCC', 'c1ccc2ccccc2c1', 'c1ccc2[nH]ccc2c1', 'CC(N)C(=O)O', 'NC(Cc1ccccc1)C(=O)O',
        'CC1CCC(C)CC1', 'OC1CCCCC1', 'NC1CCCCC1', 'FC1=CC=CC=C1', 'ClC1=CC=CC=C1',
        'BrC1=CC=CC=C1', 'CCOCC', 'CCSCC', 'CCC(=O)CC', 'CCC(=O)NCC', 'c1ccc(cc1)C(=O)O',
        'c1ccc(cc1)C(=O)N', 'CC(=O)Nc1ccccc1', 'COc1ccccc1', 'CSc1ccccc1', 'CNc1ccccc1',
        'CC1=CC=CC=C1C', 'CC1=CC=CC=C1CC', 'NCCc1ccccc1', 'OCCc1ccccc1', 'CC(C)Oc1ccccc1',
    ]

    rng = np.random.RandomState(42)

    def fabricate_score(smi):
        mol = Chem.MolFromSmiles(smi)
        heavy_atoms = Descriptors.HeavyAtomCount(mol)
        return -1.0 * heavy_atoms + rng.normal(0, 1.5)

    all_scores = [fabricate_score(s) for s in demo_smiles]

    prescreen_smiles = demo_smiles[:30]
    prescreen_scores = all_scores[:30]
    candidate_smiles = demo_smiles[30:] + ['not_a_smiles', 'also_invalid???', '']

    model_path = os.path.join(SCRATCH_DIR, 'classifier.pt')

    print('--- Step 1: training classifier on synthetic prescreen data ---')
    model, history = train_classifier(prescreen_smiles, prescreen_scores, model_path,
                                       receptor='receptor.pdbqt', seed=42, verbose=True)
    assert os.path.exists(model_path), 'Model file was not written.'
    assert history['best_epoch'] <= 49, 'Training ran past max_epochs=50.'

    labels_check, _ = label_by_top_percent(np.array(prescreen_scores, dtype=np.float32), top_percent=25)
    frac_positive = labels_check.mean()
    print('Fraction of prescreen labeled positive: {:.2f} (expected ~0.25)'.format(frac_positive))
    assert 0.10 < frac_positive < 0.40, 'Positive label fraction far from expected ~25%.'

    print('--- Step 2: loading saved classifier and checking architecture ---')
    loaded_model, metadata = load_classifier(model_path)
    shapes = [tuple(p.shape) for p in loaded_model.net.parameters() if p.dim() == 2]
    expected_shapes = [(512, 1024), (256, 512), (128, 256), (1, 128)]
    assert shapes == expected_shapes, 'Unexpected layer shapes: {}'.format(shapes)
    print('Layer shapes match spec: {}'.format(shapes))

    print('--- Step 3: filtering an in-memory candidate batch ---')
    keep_mask, probabilities = filter_smiles_mask(loaded_model, candidate_smiles, probability_cutoff=0.5)
    n_kept = sum(keep_mask)
    print('Filter stats: kept {}/{} candidates.'.format(n_kept, len(candidate_smiles)))
    assert n_kept < len(candidate_smiles), 'Expected some candidates to be filtered out.'
    for smi, keep, prob in zip(candidate_smiles, keep_mask, probabilities):
        if keep:
            assert prob is not None and prob > 0.5, '{} kept but prob={}'.format(smi, prob)
        else:
            assert prob is None or prob <= 0.5, '{} dropped but prob={}'.format(smi, prob)
    assert keep_mask[candidate_smiles.index('')] is False, 'Empty SMILES must always be discarded (fail-closed).'
    print('Threshold correctness verified for all candidates (kept iff prob > 0.5); empty SMILES fail-closed.')

    print('--- Step 4: determinism check (retrain with identical seed) ---')
    model_path_2 = os.path.join(SCRATCH_DIR, 'classifier_run2.pt')
    model_2, _ = train_classifier(prescreen_smiles, prescreen_scores, model_path_2,
                                   receptor='receptor.pdbqt', seed=42, verbose=False)
    for (n1, p1), (n2, p2) in zip(model.named_parameters(), model_2.named_parameters()):
        assert torch.equal(p1, p2), 'Parameter {} differs between identical-seed runs.'.format(n1)
    print('Determinism verified: identical seeds produce bit-identical weights.')

    print('--- Step 5: invalid SMILES handling ---')
    invalid_present = any(prob is None for _, prob in predict_proba(loaded_model, ['not_a_smiles', 'CCO']))
    assert invalid_present, 'Invalid SMILES should yield probability None.'
    print('Invalid SMILES correctly skipped with a warning rather than raising.')

    print('\nAll self-tests passed.')
