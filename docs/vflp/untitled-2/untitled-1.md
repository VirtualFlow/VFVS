# Input & Output Databases

The input and output ligand database are in the standard VirtualFlow format as described [here](../../principles-and-theory/naming-conventions.md).&#x20;

## Input Ligand Databases

In VFLP, the ligands (fourth hierarchical level) in the input databases are stored as plain text files in the SMILES format. The filename ending of each file has to be `.smi`.  Each ligand in the SMILES format only contains the SMILES, and no additional information.&#x20;

## Output Ligand Databases

In VFLP, the output ligand databases contain for each ligand a text file. The chemical file format depends on the target file format which is specified in the control file. Multiple output databases can be generated at the same time when specified so in the control file.
