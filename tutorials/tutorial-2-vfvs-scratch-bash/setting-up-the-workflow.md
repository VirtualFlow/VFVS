# Setting up the Workflow

For preparing the workflow, we need to prepare

* [the input-files](setting-up-the-workflow.md#preparing-the-input-files-folder)
* [the tools folder](setting-up-the-workflow.md#preparing-the-tools-folder)
* [the workflow folder](setting-up-the-workflow.md#preparing-the-workflow-and-output-files-folders)

## Preparing the `input-files` Folder

### Input Ligand Database

The ligand database which should be screened needs to be stored on the cluster file system to be available to VFVS. New or custom libraries can be prepared either by VFLP, or ready prepared libraries can be used such as the REAL Database of Enamine which we provide on the VirtualFlow homepage:

{% embed url="https://virtual-flow.org/real-library" %}

Here in this tutorial, we use the REAL library. For this purpose, we go to the homepage via the link above, and use the slider filters to select a smaller subset of library, consisting of approximately 50,000 compounds as in the image below:

![Interactive tranche table for the REAL library: Selection of a subset of the VirtualFlow version of the REAL library of Enamine.](<../.gitbook/assets/Screenshot at 2019-03-19 08-30-57.png>)

After that, we download the _wget_ file for the tranches  (`tranches.sh`)  and the _collection-length_ file (`collections.txt`). The file `tranches.sh` is a script which contains shell commands which will download the selected part of the ligand database. The collections length file contains the number of ligands of each of the ligand collections which belong to the selected tranches.

We replace the file `tools/templates/todo.all` with the file `collections.txt`. The `todo.all` file is the central todo file of the workflow.

Then we go to the `input-files/ligand-library` directory:

```
cd VFVS_GK/input-files/ligand-library
```

Next, we move the file `tranches.sh` into this folder, and source it:

```
source tranches.sh
```

This will download all the ligand tranches/collections which were selected before in the tranche table.

### Preparing the Docking Input Files

The docking input files comprise the receptor structure and the docking program configuration file. All the filename path which are specified in the docking program configuration files need to be relative to the `tools` folder.

The preparation of the docking program input files depends on the docking program and receptor to be used. This is external to VirtualFlow. For most of them a separate homepage and tutorials exist, such as for AutoDock Vina: [http://vina.scripps.edu/](http://vina.scripps.edu/)

We now change the directory back to the `input-files` folder:

```
cd ..
```

For this tutorial, we will use the docking input files of Tutorial 1. They can be downloaded [here](https://www.dropbox.com/s/vp92xv2058yh0zs/docking_files.tar.gz?dl=0). Using the `wget` command we can get the file directly on the cluster:

```
wget https://virtual-flow.org/sites/virtual-flow.org/files/tutorials/docking_files.tar.gz
```

And then, we can extract the files:

```
tar -xvzf docking_files.tar.gz
```



\[For more information about the preparation of the `input-files` folder in general, see the [_corresponding section_](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/using-virtualflow/preparing-the-workflow#preparation-of-the-input-files-folder) in the documentation.]

## Preparing the `tools` Folder

At first, we change the directory to the `tools` folder:

```
cd ../tools
```

### Preparing the `tools/templates/all.ctrl` File

As a next step, we will edit the file `tools/templates/all.ctrl`.  It needs to be adjusted according to the cluster/batch system which you are using. In particular, the following settings are cluster dependent:

* `batchsystem`: The resource manager which is used by your cluster.
* `partition`: The partition queue to be used for running the jobs of this workflow/tutorial.
* `timelimit`: Each partition/queue has normally a time-limit, therefore make sure you don't exceed it.

Everything else is set up in a way which should work on most clusters. The jobs are pre-configured such that each job uses one CPU-core on one node.&#x20;

#### Using Entire Nodes (optional)

Very few clusters require that full nodes are used, and sometimes even a minimum number of the them. In this case, the following settings need to be adjusted as well:

* `steps_per_job`: This equals the number of nodes which should be used per job, and be at least as large as the minimum number of nodes per job since one job step is used for each node.
* `cpus_per_step`: In this case where entire nodes are used, this should be set to the number of CPUs per node to utilize them fully.
* `queues_per_step`: This should be set to the number of `cpus_per_step`, since in this case we have one cpu per queue (i.e. the docking programs which are executed within the queues are set to use just one CPU core).
* `cpus_per_queue`: This is the number of CPU cores which are used per queue, and thus also per docking program instance. Normally, it is most efficient to set up the workflow such that each docking program uses one CPU core, and that there is one queue per core.&#x20;

#### Workflow Settings

Regarding the parameters `ligands_todo_per_queue` and `ligands_per_refilling_step`, for this tutorial we set it to something smaller than the default value, which is more suitable for large-scale production runs. A value of 1000 might be favorable for both of them:

```
ligands_todo_per_queue=1000
ligands_per_refilling_step=1000
```

Regarding the logging of errors, it is favorable to enable full logging when trying to get a workflow working:

```
verbosity_logfiles=debug
store_queue_log_files=all_uncompressed
```

After everything seems to run smoothly, one can change the logging options and restart the workflow, because extensive uncompressed logging takes too much disk space for large-scale production runs.

#### Docking Scenario Settings

Regarding the docking scenario options, the `docking_scenario_inputfolders` parameter needs to be set according to the names of the docking scenario folders in the `input-files` folder. The docking programs are specified with the `docking_scenario_programs` option. For now, we use the following settings:

```
docking_scenario_names=qvina02_rigid_receptor1:smina_rigid_receptor1
docking_scenario_programs=qvina02:smina_rigid
docking_scenario_replicas=1:1
docking_scenrio_inputfolders=../input-files/qvina02_rigid_receptor1:../input-files/smina_rigid_receptor1
```

###

### Preparing the Job File

For submitting jobs into batch systems on clusters job files are needed. How they look like depends on the type of batch system. For most batch systems VirtualFlow has already pre-configured job files stored in the `tools/templates/` folder:

* **SLURM:** `template1.slurm.sh`
* **PBS:** `template1.pbs.sh`
* **SGE:** `template1.sge.sh`
* **LFS:** `template1.lfs.sh`
* **Torque/MOAB:** `template1.torque.sh`

For most clusters, the job files do not have to be edited manually. However, some clusters require specific/custom settings in the job files. If this is the case for your cluster, you need to edit the job templates and adjust them accordingly.



\[For more information about the preparation of the `tools` folder in general, see the [_corresponding section_](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/using-virtualflow/preparing-the-workflow#preparation-of-the-tools-folder) in the documentation.]

## Preparing the `workflow` and `output-files` Folders

All other files are already set up, in particular the `tools/templates/todo.all`, which contains the ligand collections which should be processed/screened, as well as the docking input files in the folder `input-files` which also contains the input ligand database.

This means, we are ready to prepare the folders, which can be done with the command `vf_prepare_folders.sh`. The command will delete old files from previous runs if present, and prepare the workflow folder which is used  by VirtualFlow during the runtime to organize and log the workflow. To prepare the folders, simply run the command:

`./vf_prepare_folders.sh`

The command will ask you if you really want to reset/prepare the relevant folders, since this may delete files from previous runs.



\[For more information about the preparation of the `workflow` and `output-files`folders in general, see the [_corresponding section_](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/using-virtualflow/preparing-the-workflow#preparation-of-the-workflow-and-output-files-folders) in the documentation.]
