# Preparing the Workflow

## General

To prepare VirtualFlow for a workflow, the following needs to be done:

* [Installation of the desired module of VirtualFlow](../installation/)
* [Preparation of the input-files folder ](preparing-the-workflow.md#preparation-of-the-input-files-folder)
* [Preparation of the `tools` folder](preparing-the-workflow.md#preparation-of-the-tools-folder)
* [Preparation of the `workflow` and `output-files` folders](preparing-the-workflow.md#preparation-of-the-workflow-and-output-files-folders)

## Preparation of the `input-files` Folder

As described [here](../principles-and-theory/directory-structure.md#the-input-files-folder) in the _Background and Principles_ section, the `input-files` folder only contains the input files which are used by the external programs which process the ligands in the workflow. The only exception can be the input ligand database, which can be stored in some other centralized location (to be shareable by multiple independent VirtualFlow workflows). However, if it is stored in the VirtualFlow workflow folder, then the `input-files` folder is naturally the proper location. The location which is used is specified in the control file.&#x20;

Currently, VFLP does not require the input-files folder as described here:

* [VFLP - Directory Structure - `input-files` folder](../vflp/untitled-2/directory-structure.md#the-input-files-folder)

VFVS does require the `input-files` folder for docking input files, as described here:

* [VFVS - Preparing the Workflow - `input-files` folder](../vfvs/using-vfvs/preparing-the-workflow.md#preparation-of-the-input-files-folder)

## Preparation of the `tools` Folder

The `tools` folder is only used by the user, not by the workflow. But it needs to be setup properly, as the `tools` folder is used to set up the `workflow` folder (see [below](preparing-the-workflow.md#preparation-of-the-workflow-and-output-files-folders)).

To prepare the `tools` folder of VirtualFlow, the following files have to be prepared:

* [The initial control file (`tools/templates/all.ctrl`)](preparing-the-workflow.md#initial-control-file)
* [The central task list (`tools/templates/todo.all`](preparing-the-workflow.md#central-task-list))
* [The job file template ( `tools/templates/todo.all` )](preparing-the-workflow.md#the-job-file-template)

The `tools` folder is the primary working directory of VirtualFlow. All VirtualFlow user commands (starting with `vf_`)  have to be run with this directory.



### Initial Control-file

The initial control file `tools/templates/all.ctrl` needs to be set up. All parameters are explained in within the file itself.

{% hint style="info" %}
If one has the choice of submitting many small jobs (such as 1-CPU jobs), or fewer large jobs (e.g. multi-node jobs), the latter is generally preferable regarding the central task list. But this usually only becomes relevant with very large numbers of jobs.
{% endhint %}

Multiple different control files for different job-lines can be employed once the `workflow` folder was prepared ([see below](preparing-the-workflow.md#control-files)).



### Central Task List

The central task list `tools/templates/todo.all` needs to be set up.

The file contains the ligand collections which should be processed by the workflow. One ligand collection corresponds to one task for the workflow, even though one collection can contain any number of ligands.  For each collection one line is used in the central task list, and it has the format:

`<tranch>_<collection name> <# of ligands in the collection>`

Regarding the databases which we provide, e.g. the REAL database of Enamine, a so called _collection lengths file_ (usually it has the name`length.all`) which contains the lengths of the collections is provided along with the database on the download page. The collection lengths file and the `todo.all` file have the same format. The `todo.all` file can be either the full `lengths.all` file (i.e. when screening the entire library), or a subset of it. If all of the collections in the file should be screened, the file can simply be copied to `tools/templates/todo.all`.

If one wants to screen only a subset of the collections of the database, one can do that by extracting the subset of the length file wants to screen, and store them in the `tools/templates/todo.all` file. The selection of subsets is most easily done with grep command.&#x20;

For example, if one wants to screen all the collections of tranches with names which start with the letter "A", this can be done by the command:

```
grep "^A" length.all > tools/templates/todo.all
```

Here the caret symbol "^" indicates the beginning of a line, meaning that the letter "A" has to be at the beginning in order for a match to happen. For more detailed information about the grep command, see either the corresponding man-page (which can be accessed by running the command `man grep` or [here](http://man7.org/linux/man-pages/man1/grep.1.html) online), or other online resources such as [here](https://www.tldp.org/LDP/Bash-Beginners-Guide/html/sect_04_02.html).&#x20;



### The Job File Template

VirtualFlow uses a job file template for the job it submits into the resource manager (batch system). The job template needs to be adjusted according to the one's preferences and according to the cluster requirements and constraints.

In the particular the following settings in the job file template should set appropriately:

* Memory requirements
* Special settings required by the cluster
* Email notification settings

The following settings should be left unchanged, as they are handled internally by VirtualFlow and can be set partially in the control file.&#x20;

* job name (can be partially set in the control file)
* partition (can be set in the control file)
* wall-time (can be set in the control file)
* number of nodes (can be set in the control file)
* number of cpus and job steps (can be set in the control file)
* input/output log files

Some clusters might require additional modules to be loaded, e.g. if OpenBabel which is used by VFLP should be loaded as a module it needs to go into the job template (see also [VFLP - Installation - External Packages](../vflp/installation/external-packages.md)).

## Preparation of the `workflow` and `output-files` Folders

### General

The `workflow` and `output-files` folders needs to be prepared before the workflow can be started for the first time. This is done with the command `vf_prepare_folders.sh`. The preparation of the `workflow` folder is based on the current configuration/settings of the `tools` folder, therefore the `tools` folder needs to be set up at first.

{% hint style="info" %}
The  command `vf_prepare_folders.sh` removes previously existing `output-files` and `workflow` folders if they are present, which can be the case if test runs were carried out before. Therefore this command has to be used with care as it can delete important files.
{% endhint %}

The preparation of the workflow folder by the command `vf_prepare_folders.sh` does the following steps automatically:

* Deletion of previously existing `output-files` and `workflow` folders (if they exist)
* Creation of (new) `output-files` and `workflow` folders
* Creation of the required sub-folder structure of the `workflow` folder, which consists of:
  * `workflow/ligand-collections/todo/`
  * `workflow/ligand-collections/current/`
  * `workflow/ligand-collections/done/`
  * `workflow/ligand-collections/ligand-lists/`
  * `workflow/ligand-collections/var/`
  * `workflow/control/`
  * `workflow/output-files/jobs/`
  * `workflow/output-files/queues/`
  * `workflow/job-files/main/`
  * `workflow/job-files/sub/`
* Copying of the required (previously prepared) files from the tools folder to the workflow folder:
  * `tools/templates/one-step.sh` → `workflow/job-files/sub/one-step.sh`
  * `tools/templates/one-queue.sh` → `workflow/job-files/sub/one-queue.sh`
  * `tools/templates/todo.all` → `workflow/ligand-collections/var/todo.original`
  * `tools/templates/all.ctrl` → `workflow/control/all.ctrl`
* The todo-file is split into smaller pieces (as specified in the ctrl-file via the setting _central\_todo\_list\_splitting\_size_), and the split files are stored in the `workflow/ligand-colllections/todo/` folder
* The file `workflow/job-files/sub/one-step.sh` is made executable

### Control Files

The folder `workflow/control/` contains the control files with settings which are used by the jobs/workflow. The main control  `all.ctrl`always has to be there. It is contains the word "all", because it used by all jobs by default.

However, it is possible to define settings for specific job-lines or ranges of job-lines. For that, one simply copies the file `workflow/control/all.ctrl` to `workflow/control/<start-jobline-id>-<end-jobline-id>.ctrl`, which means that this control file is used by all the jobs which have jobline IDs between _\<start-joblline-id>_ and _\<end-jobline-id>_. These more specific control files are called _**range control files.**_ They override most of the settings in the `all.ctrl` file for the relevant joblines, but not all settings. Some settings are global and always read from the `all.ctrl` file, therefore this file always needs to be there.

For example, the range control file `workflow/control/4-9.ctrl` would be used by all jobs/job-lines which have a jobline ID between 4 and 9 (see also Fig. 1 below).&#x20;

![Fig. 1: Shown are the jobs (violet circles) of 15 joblines in the workflow which are running (the number within the circles is the joblineID). By default, the joblines will use the general control file all.ctrl. But if range control files are present, they will be used instead. Thus, range control files can be seen as overlays/overrides over the general control file.](<../.gitbook/assets/range-control-file (1).png>)



### Job Files

What is still missing in order to start the workflow are the main job files. These are prepared on the fly when the workflow is initialized/started (see the next section, [Starting the Workflow](starting-jobs.md)).
