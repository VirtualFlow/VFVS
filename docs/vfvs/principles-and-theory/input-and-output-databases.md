# Input & Output Databases

The input and output ligand database are in the standard VirtualFlow format as described [here](../../principles-and-theory/naming-conventions.md).&#x20;

## Input Ligand Databases

In VFVS, the ligands (fourth hierarchical level) in the input databases are stored as plain text files a ready-do-dock format. All docking programs supported so far by VirtualFlow support the PDBQT format, thus the PDBQT format is at the moment the only supported. The filename ending of each file has to be `.pdbqt`.  Each ligand in the PDBQT format only contains the SMILES, and no additional information.&#x20;

The output ligand databases of VFLP can directly be used with VFVS for the virtual screening procedures, provided that VFLP was set up to generate the output ligand database in the PDBQT format.&#x20;

### REAL Database of Enamine

We provide on the VirtualFlow the REAL database of Enamine in a ready-to-dock format, ready for direct employment with VFVS. It contains over 1.4 billion distinct molecules.&#x20;

It was prepared with VFLP, and can be downloaded here on the VirtualFlow homepage:&#x20;

* [https://virtual-flow.org/real-library](https://virtual-flow.org/real-library)

Specific subsets can be easily chosen on the website via an interactive interface.

## Output Databases

In VFVS, the output databases contain for each ligand a tar-archive, which contains all the docking output files for each ligand.&#x20;
