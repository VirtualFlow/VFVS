# Setting up the Workflow

## Going to the VirtualFlow Working Directory

At first, go to the folder to `VFVS_GK/tools`, since this is the working directory of VirtualFlow, where all commands are started:

```
cd VFVS_GK/tools
```

## Preparing the `tools` Folder

### Preparing the `tools/templates/all.ctrl` File

As a next step, the file `tools/templates/all.ctrl` needs to be edited.  It needs to be adjusted according to the cluster/batch system which will be used. In particular, the following settings are cluster dependent:

* `batchsystem`: The resource manager which is used by your cluster.
* `partition`: The partition queue to be used for running the jobs of this workflow/tutorial.
* `timelimit`: This parameter specifies the `timelimit` parameter of the jobs which are submitted by to batch system by VFVS. Each partition/queue has normally a maximum partition time-limit. The `timelimit` parameter should be set to a value below or equal to the partition time-limit. Otherwise, the batchsystem might terminate the job without VFVS being able to start a successor job to continue the work of the current job.

Everything else is set up in a way which should work on most clusters. The jobs are pre-configured such that each job uses one CPU-core on one node.

#### Using Entire Nodes (optional)

Very few clusters require that full nodes are used, and sometimes even a minimum number of the them. In this case, the following settings need to be adjusted as well:

* `steps_per_job`: This equals the number of nodes which should be used per job, and be at least as large as the minimum number of nodes per job since one job step is used for each node.
* `cpus_per_step`: In this case where entire nodes are used, this should be set to the number of CPUs per node to utilize them fully.
* `queues_per_step`: This should be set to the number of `cpus_per_step`, since in this case we have one cpu per queue (i.e. the docking programs which are executed within the queues are set to use just one CPU core).
* `cpus_per_queue`: This is the number of CPU cores which are used per queue, and thus also per docking program instance. Normally, it is most efficient to set up the workflow such that each docking program uses one CPU core, and that there is one queue per core.&#x20;

### Preparing the Job File

For submitting jobs into batch systems on clusters job files are needed. How they look like depends on the type of batch system. For most batch systems VirtualFlow has already pre-configured job files stored in the `tools/templates/` folder:

* **SLURM:** `template1.slurm.sh`
* **PBS:** `template1.pbs.sh`
* **SGE:** `template1.sge.sh`
* **LFS:** `template1.lfs.sh`
* **Torque/MOAB:** `template1.torque.sh`

For most clusters, the job files do not have to be edited manually. However, some clusters require specific/custom settings in the job files. If this is the case for your cluster, you need to edit the job templates and adjust them accordingly.&#x20;

## Preparing the `workflow` and `output-files` Folders

All other files are already set up, in particular the `tools/templates/todo.all`, which contains the ligand collections which should be processed/screened, as well as the docking input files in the folder `input-files` which also contains the input ligand database.

This means, we are ready to prepare the folders, which can be done with the command `vf_prepare_folders.sh`. The command will delete old files from previous runs if present, and prepare the workflow folder which is used  by VirtualFlow during the runtime to organize and log the workflow. To prepare the folders, in the `tools` folder simply run the command

`./vf_prepare_folders.sh`

The command will ask you if you really want to reset/prepare the relevant folders, since this may delete files from previous runs.&#x20;

\[For more information about the preparation of the workflow and output-files folders in general, see the [_corresponding section_](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/using-virtualflow/preparing-the-workflow#preparation-of-the-workflow-and-output-files-folders) in the documentation.]
