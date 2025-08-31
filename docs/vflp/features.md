# Features

## **Desalting and Neutralization**

Molecules which are provided in salt-form can be automatically desalted and neutralized via ChemAxon's JChem suite.

## **Tautomerization**

Often multiple tautomeric states of the same compounds exist at a given pH. VFLP can automatically generate the tautomers using the cxcalc tool of ChemAxons JChem Suite, with the possibility to specify all options which the tautomer plugin of cxcalc provides. This can lead to a substantial increase in the size of the library.

## **Extremely Fast**

VFLP has an substantial additional speedup in addition to the perfect scaling behavior of VirtualFlow due to the use of Nailgun, which runs a persistent JVM during the runtime of the workflow.

## **Multiple Output Formats**

Any number of distinct output formats can be generated during a single workflow.

## **Any Target Format**

Almost every chemical file format (i.e.all formats supported by Open Babel) can be chosen for the final output files of the ligands. Among these file types are all the well known formats such as SDF or PDB, but also specialized ones such as PDBQT which is used by most AutoDock-based docking programs.

## **Ligand Protonation at any pH**

During the preparation of the ligands with VFLP, they can be protonated at a freely choosable pH value. Ligand protonation is an optional step in the workflow, which does not have to be employed. It can be carried out either by ChemAxons cxcalc or by Open Babel.

## **3D Conformation Generation**

Docking programs normally require three-dimensional conformations of the molecules. VFLP can prepare them when required, either by using OpenBabel or by using ChemAxon's molconvert.

## **Fallback Modes**

Sometimes, one molecular conversion programs like OpenBabel or the tools from ChemAxon fail for certain molecules during one of the processing steps such as protonation. In VFLP one can specify a backup program in the case that the primary conversion program should fail during the conversion of some ligands.
