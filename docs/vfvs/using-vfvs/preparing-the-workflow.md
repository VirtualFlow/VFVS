# Preparing the Workflow

## General

In addition to the general preparation which is required for any VirtualFlow module as describe [here](../../installation/), for VFVS the `input-files` folder needs to be set up as described [below](preparing-the-workflow.md#preparation-of-the-input-files-folder).

## Preparation of the `input-files` Folder

For using VFVS, a set of docking scenarios has to be set up by the user, and it can be any number of them. This is done in the `input-files` folder, which contains the following items:

* Configuration files for the docking programs
* Receptor structures
* Other files needed by the docking program
* Optional: Input ligand collection in ready-to-dock VirtualFlow format (can also be located at another location, which can be specified in the control file)

### Docking Scenario Folders

For each docking scenario, a new folder is created within the `input-files` folder. Choosing descriptive names of the docking scenario which encodes some of its properties is recommended, such as&#x20;

`input-files/qvina_rigid_receptor1`

for a docking scenario where qvina is used as the docking program, receptor structure 1 is used, and the receptor is held rigid.

### Docking Program Config Files

Each docking scenario folder needs to have a file called `config.txt`, which is used by the configuration file used by all supported docking programs. For instance, for all the AutoDock Vina-based docking programs, this would be the config file which all these programs required.

Within these config files, also the receptor structure which is used by that docking scenario is specified. All files which are specified in these configuration files have to be relative paths with respect to the `tools` folder. This is the case because all docking programs are started by VirtualFlow from the `tools` folder. For instance, if the receptor structure file `input-files/qvina_rigid_receptor1/receptor1.pdb` is specified in the docking program configuration file `input-files/qvina_rigid_receptor/config.txt`, then the path to the receptor which needs to be used would be `../input-files/qvina_rigid_receptor1/receptor1.pdb`.&#x20;

#### AutoDock Vina-based Docking Programs

Within the docking program config files, all desired/required options have to be specified, except

* the ligand, since the ligand is variable and VFVS takes care of it

The number of CPU cores (multi threading) in the config file, which can be specified via the option `cpu`,  will be replaced by the option in the VirtualFlow control file option `cpus_per_queue`. Still, the `cpu` option needs to be present in the docking program config file, so that VirtualFlow can replace the value by the value of `cpus_per_queue`.&#x20;

#### PLANTS

As always in VirtualFlow, also the config file of the docking program PLANTS is placed in a subfolder in the `input-files` directory, and needs to contain a file called `config.txt`. All file paths which are set in the `config.txt` file need to be relative to the tools folder, as for any other docking program.

As required by PLANTS the receptor has to be in the MOL2 format. More information can be found in the manual of PLANTS:

[https://uni-tuebingen.de/fakultaeten/mathematisch-naturwissenschaftliche-fakultaet/fachbereiche/pharmazie-und-biochemie/teilbereich-pharmazie-pharmazeutisches-institut/pharmazeutische-chemie/pd-dr-t-exner/research/plants/](https://uni-tuebingen.de/fakultaeten/mathematisch-naturwissenschaftliche-fakultaet/fachbereiche/pharmazie-und-biochemie/teilbereich-pharmazie-pharmazeutisches-institut/pharmazeutische-chemie/pd-dr-t-exner/research/plants/)

PLANTS requires ligands to be in the MOL2 format. VirtualFlow can therefore use libraries in the typical VirtualFlow  library format where all ligands are stored in the MOL2 format. Alternatively,  VirtualFlow Ants can also use ligand libraries in the PDBQT Format, and convert them on the fly to the MOL2 format so that PLANTS can use PDBQT libraries. This library format option can be set in the control file via the parameter `ligand_ibrary_format`. If the library is in the PDBQT format, then SPORES has to be installed for the on the fly conversion. More details on how to install SPORES and PLANTS can be found here:

[https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/vfvs/installation/prerequisites](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/vfvs/installation/prerequisites)

### Shared Folder for Receptor Structures

It is recommended to create a separate folder for the receptor structures, such as&#x20;

`input-files/receptors`

where all the receptor structures which are used are stored. Different docking scenarios can then make shared used of them. But theoretically, they can be stored also in docking scenario folders.

### Ligand Input Database

The ligand database to be used can be stored in any location, and the location can be specified in the control file.&#x20;

The required ligand input database can be prepared either from scratch with VFLP, or a ready-made database can be used. For virtual screenings, most users would use a ready-made database. For this purpose, we are providing the REAL database from Enamine, which can be downloaded here from the VirtualFlow website:&#x20;

* [https://virtual-flow.org/real-library](https://virtual-flow.org/real-library)

There, specific subsets of the database can be downloaded, as well as the required collection lengths file which is needed to set up the `tools` folder as described earlier [here](../../using-virtualflow/preparing-the-workflow.md#central-task-list) (i.e. this file can be used for the central task `todo.all` list which is used by VirtualFlow).

## Machine Learning Classifier for Molecule Prioritization

For ultra-large screens, VFVS supports an optional machine learning classifier that predicts which molecules within a collection are likely to be high-affinity binders, so that only those molecules are docked. It is a fully-connected feedforward neural network trained on Morgan fingerprints and the docking scores from a small representative prescreen run. It is disabled by default; enabling it does not change how collections/tranches are selected for screening, only which molecules within an already-selected collection get docked.

The workflow has three steps:

1. **Prescreen.** Run the existing, unmodified VFVS workflow (`all.ctrl` + `vf_prepare_folders.sh` + `vf_start_jobline.sh`, or the AWS Batch equivalents) on a small representative set of collections, to produce real docking scores in the usual per-collection summary files under `output-files/{complete,incomplete}/<scenario>/summaries/`. No configuration changes are needed for this step.
2. **Train.** From the `tools` directory, run the training script once (a single interactive invocation, not a batch job):

   ```
   python3 train_ml_classifier.py --scenario <docking_scenario_name>
   ```

   This collects every summary file for the given docking scenario, extracts (SMILES, docking score) pairs, and trains+saves the classifier to the path given by `ml_classifier_model_path` in `workflow/control/all.ctrl` (default `ml_classifier/model.pt`, relative to `input-files/`).
3. **Primary screen.** Set `use_ml_classifier=true` in `all.ctrl` (see the "Machine Learning Classifier" section of the control file for all available options), then submit the primary screen as usual. Each queue (Slurm) or AWS Batch array child loads the trained classifier once per collection/subjob and filters out molecules scoring at or below `ml_classifier_probability_cutoff`, before they reach the docking programs.

A classifier trained once for a given docking scenario can be reused across later primary screens without retraining, as long as `ml_classifier_model_path` still points at the saved file. Filtered-out molecules are recorded in the same per-collection ligand-list status files used for other pre-docking checks (such as the element and duplicate-coordinate checks), so every input molecule remains accounted for.

Requires PyTorch and RDKit to be installed (see [Prerequisites](../installation/prerequisites.md)); these are only needed if `use_ml_classifier=true`.











