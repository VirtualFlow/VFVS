# Input & Output Databases

## General

The input and output ligand databases consist of a hierarchical file structure, which contains up to 5 levels:

0 - Database root directory\
&#x20;     1 - Meta-tranches\
&#x20;           2 - Tranches\
&#x20;                 3 - Collections\
&#x20;                       4 - Ligands\
&#x20;                             5 - Multiple files per ligand (VFVS only)



## Level 0: Root database location

* Is a directory with any name.
* Contains the meta-tranche folders.

## Level 1: Meta-tranches

* Are directories consisting of two letters.
* Meta-tranches contain the tranche tar-archives.
* The first two letters of a tranche defines its meta-tranche.

## Level 2: Tranches

* Tranches are either tar-archives or folders
* They contain the collections as tar.gz archives
* The names of the tranches consist normally of a fixed number of capital letters, such as ABCA. The number of letters depends on the database, but has to be at least 3. Often the tranche letters are used to encode information about the properties of the compounds within that tranche. For instance the first letter of a tranche name could encode the molecular weight.

## Level 3: Collections

* Are compressed tar-archives (tar.gz files)
* Contain the ligands
* The names of the collections are usually numbers, such as 01234. Usually, the collection number does not encode information about the compounds.&#x20;

## Level 4: Ligands

* Contains the actual ligand files in native format
* This will be SMILES for VFLP and PDBQT files for VFVS
* More details can be found in the corresponding sections:
  * [VFLP - Input and Output Databases](../vflp/untitled-2/untitled-1.md)
  * [VFVS - Input and Output Databases](../vfvs/principles-and-theory/input-and-output-databases.md)
* The VFVS output database contains a fifths hierarchical level since for each ligand there can exist multiple docking output files

## Collection lengths file

Each collection contains a certain number of ligands, and the number of ligands per collection is stored for all collections together in a so-called _collections lengths_ file. This is a plain text file which belongs to each ligand database. It is a text file containing entries of the form:

`<tranche>_<collection> <# of ligands in the collection>`

For example the collection 01234 of tranche ABCA (of meta tranche AB) would have the following entry if it contains 1000 ligands:

`ABCA_01234 1000`&#x20;

The collection lengths file is needed to specify during the setup which ligand collections of the input database should be processed (i.e. which subset, since one does not always want to process all ligands of the input database). More details can be found in the section [_Preparing the Workflow - Preparing the Tools Folder - Central Task List_](../using-virtualflow/preparing-the-workflow.md#central-task-list)_._





