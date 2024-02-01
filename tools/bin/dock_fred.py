from openeye import oechem, oeiupac, oedocking, oeomega, oequacpac
from pathlib import Path
import argparse
import numpy as np


def normalize_molecule(molecule):
    """Code taken from: https://github.com/choderalab/openmoltools/blob/master/openmoltools/openeye.py
    Normalize a copy of the molecule by checking aromaticity, adding explicit hydrogens, and
    (if possible) renaming by IUPAC name.
    Parameters
    ----------
    molecule : OEMol
        the molecule to be normalized.
    Returns
    -------
    molcopy : OEMol
        A (copied) version of the normalized molecule
    """
    if not oechem.OEChemIsLicensed():
        raise (ImportError("Need License for OEChem!"))
    has_iupac = oeiupac.OEIUPACIsLicensed()

    molcopy = oechem.OEMol(molecule)

    # Assign aromaticity.
    oechem.OEAssignAromaticFlags(molcopy, oechem.OEAroModelOpenEye)

    # Add hydrogens.
    oechem.OEAddExplicitHydrogens(molcopy)

    # Set title to IUPAC name.
    if has_iupac:
        name = oeiupac.OECreateIUPACName(molcopy)
        molcopy.SetTitle(name)

    # Check for any missing atom names, if found reassign all of them.
    if any([atom.GetName() == '' for atom in molcopy.GetAtoms()]):
        oechem.OETriposAtomNames(molcopy)

    return molcopy


def generate_conformers(molecule,
                        max_confs=800,
                        strictStereo=True,
                        ewindow=15.0,
                        rms_threshold=1.0,
                        strictTypes=True):
    """Code taken from: https://github.com/choderalab/openmoltools/blob/master/openmoltools/openeye.py
    Generate conformations for the supplied molecule
    Parameters
    ----------
    molecule : OEMol
        Molecule for which to generate conformers
    max_confs : int, optional, default=800
        Max number of conformers to generate.  If None, use default OE Value.
    strictStereo : bool, optional, default=True
        If False, permits smiles strings with unspecified stereochemistry.
    strictTypes : bool, optional, default=True
        If True, requires that Omega have exact MMFF types for atoms in molecule; otherwise, allows the closest atom type of the same element to be used.
    Returns
    -------
    molcopy : OEMol
        A multi-conformer molecule with up to max_confs conformers.
    Notes
    -----
    Roughly follows
    http://docs.eyesopen.com/toolkits/cookbook/python/modeling/am1-bcc.html
    """
    if not oechem.OEChemIsLicensed():
        raise (ImportError("Need License for OEChem!"))
    if not oeomega.OEOmegaIsLicensed():
        raise (ImportError("Need License for OEOmega!"))

    molcopy = oechem.OEMol(molecule)
    omega = oeomega.OEOmega()

    # These parameters were chosen to match http://docs.eyesopen.com/toolkits/cookbook/python/modeling/am1-bcc.html
    omega.SetMaxConfs(max_confs)
    omega.SetIncludeInput(True)
    omega.SetCanonOrder(False)

    omega.SetSampleHydrogens(
        True
    )  # Word to the wise: skipping this step can lead to significantly different charges!
    omega.SetEnergyWindow(ewindow)
    omega.SetRMSThreshold(
        rms_threshold
    )  # Word to the wise: skipping this step can lead to significantly different charges!

    omega.SetStrictStereo(strictStereo)
    omega.SetStrictAtomTypes(strictTypes)

    omega.SetIncludeInput(False)  # don't include input
    if max_confs is not None:
        omega.SetMaxConfs(max_confs)

    status = omega(molcopy)  # generate conformation
    if not status:
        raise (RuntimeError("omega returned error code %d" % status))

    return molcopy


def create_receptor(protein_pdb_path, box):
    """ Code taken from: https://github.com/choderalab/yank-benchmark/blob/master/scripts/docking.py
    Create an OpenEye receptor from a PDB file.
    Parameters
    ----------
    protein_pdb_path : str
        Path to the receptor PDB file.
    box : 1x6 array of float
        The minimum and maximum values of the coordinates of the box
        representing the binding site [xmin, ymin, zmin, xmax, ymax, zmax].
    Returns
    -------
    receptor : openeye.oedocking.OEReceptor
        The OpenEye receptor object.
    """
    input_mol_stream = oechem.oemolistream(protein_pdb_path)
    protein_oemol = oechem.OEGraphMol()
    oechem.OEReadMolecule(input_mol_stream, protein_oemol)

    box = oedocking.OEBox(*box)
    receptor = oechem.OEGraphMol()
    oedocking.OEMakeReceptor(receptor, protein_oemol, box)

    return receptor


def molecule_to_mol2(molecule,
                     tripos_mol2_filename=None,
                     conformer=None,
                     residue_name="MOL",
                     standardize=True):
    """Adapted from: https://github.com/choderalab/openmoltools/blob/master/openmoltools/openeye.py
    Convert OE molecule to tripos mol2 file.
    Parameters
    ----------
    molecule : openeye.oechem.OEGraphMol
        The molecule to be converted.
    tripos_mol2_filename : str
        Output filename.  If None, will create a filename similar to
        name.tripos.mol2, where name is the name of the OE molecule.
    conformer : int, optional, default=0
        Save this frame
        If None, save all conformers
    residue_name : str, optional, default="MOL"
        OpenEye writes mol2 files with <0> as the residue / ligand name.
        This chokes many mol2 parsers, so we replace it with a string of
        your choosing.
    standardize: bool, optional, default=True
        Use a high-level writer, which will standardize the molecular properties.
        Set this to false if you wish to retain things such as atom names.
        In this case, a low-level writer will be used.
    Returns
    -------
    tripos_mol2_filename : str
        Filename of output tripos mol2 file
    """

    if not oechem.OEChemIsLicensed():
        raise (ImportError("Need License for oechem!"))

    ofs = oechem.oemolostream(tripos_mol2_filename)
    ofs.SetFormat(oechem.OEFormat_MOL2H)
    for k, mol in enumerate(molecule.GetConfs()):
        if k == conformer or conformer is None:
            # Standardize will override molecular properties(atom names etc.)
            if standardize:
                oechem.OEWriteMolecule(ofs, mol)
            else:
                oechem.OEWriteMol2File(ofs, mol)

    ofs.close()

    # Replace <0> substructure names with valid text.
    infile = open(tripos_mol2_filename, 'r')
    lines = infile.readlines()
    infile.close()
    newlines = [line.replace('<0>', residue_name) for line in lines]
    outfile = open(tripos_mol2_filename, 'w')
    outfile.writelines(newlines)
    outfile.close()


def read_ligand_fn(ligand_fn):
    ifs = oechem.oemolistream(ligand_fn)
    oe_comp = oechem.OEGraphMol()
    if not oechem.OEReadMolecule(ifs, oe_comp):
        raise ValueError()
    return oe_comp


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--receptor-fn",
                        type=Path,
                        help="PDB file of the protein receptor")
    parser.add_argument("--ligand-fn",
                        type=Path,
                        help="MOL2 file of the ligand")
    parser.add_argument("--center-x",
                        type=float,
                        help="X-coordinate of box center")
    parser.add_argument("--center-y",
                        type=float,
                        help="Y-coordinate of box center")
    parser.add_argument("--center-z",
                        type=float,
                        help="Z-coordinate of box center")
    parser.add_argument("--radius",
                        type=float,
                        default=10.0,
                        help="Radius of box (default: 10 A)")
    parser.add_argument("--num-poses",
                        type=int,
                        default=100,
                        help="Number of poses to keep")
    parser.add_argument("--output-fn",
                        type=Path,
                        help="Output file of docked ligand poses")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    ligand_fn = args.ligand_fn
    receptor_fn = args.receptor_fn
    # read in ligand mol2 file
    ligand = read_ligand_fn(ligand_fn.as_posix())
    # add hydrogens and standardize aromaticity
    ligand = normalize_molecule(ligand)
    # generate conformers
    ligand_confs = generate_conformers(ligand,
                                       max_confs=800,
                                       strictStereo=True,
                                       ewindow=15.0,
                                       rms_threshold=1.0,
                                       strictTypes=True)
    x, y, z = args.center_x, args.center_y, args.center_z
    pocket_center = np.asarray([x, y, z])
    pocket_radius = args.radius
    box = np.concatenate(
        ((pocket_center - pocket_radius), (pocket_center + pocket_radius)))
    receptor = create_receptor(receptor_fn.as_posix(), box)
    dock = oedocking.OEDock()
    dock.Initialize(receptor)
    docked_oemol = oechem.OEMol()
    dock.DockMultiConformerMolecule(docked_oemol, ligand_confs, args.num_poses)
    # write out mol2 file
    output_fn = args.output_fn
    molecule_to_mol2(docked_oemol, output_fn.as_posix())
