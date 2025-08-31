# Directory Structure

## General

The directory structure of VFLP is as the as for for VirtualFlow in general (as described [here](../../principles-and-theory/directory-structure.md)).

## The `input-files` Folder

What is specific for VFLP is that the `input-files` folder does not contain anything, except possibly the input ligand collection,  which can also be stored at another location (as specifiable in the control file). The reason that the `input-files` folder does not need to contain anything is that the external programs which are used by VFLP do not need any input files except the ligands.
