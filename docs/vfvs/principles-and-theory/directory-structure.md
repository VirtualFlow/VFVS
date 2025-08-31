# Directory Structure

The general structure of the `output-files` folder is described [here](../../principles-and-theory/directory-structure.md#the-output-files-folder) about VirtualFlow in general.

In the case of VFVS, the `output-files/incomplete` and `output-files/complete` folders. These folders contain for each docking scenario the following sub-folders:

* `results`
* `summaries`
* `logfiles`
* `ligand-lists`

The `results` folder contains the original docking output files of the docking programs in the VirtualFlow database format as described [here](../../principles-and-theory/naming-conventions.md).

The `summaries` folder contains summaries of the docking scores for each compound.&#x20;

The `log-files` folder contains the logging output files of the docking programs,.

The `ligand-lists` folder if enabled in the control file via the `keep_ligand_summary_logs` option contains some workflow-related information for each ligand, in particular which processing steps where successful and how long time each step has taken for each ligand.
