# Monitoring the Workflow

## General

A running workflow of VirtualFlow can be monitored in different ways:

1. Via the `vf_report.sh` command
2. Via the log files&#x20;
3. Via the batch system

## The `vf_report.sh` Command

The command `vf_report.sh` can be used to monitor the workflow in general, independent of the VirtualFlow module which is used. This is done by passing the value _workflow_ to the `-c` option of the command ('c' stands for **c**lass of report), i.e. by running the command `vf_report.sh -c workflow`.

This will show information about

* the jobs which are used by the current VirtualFlow workflow, how many of them are running and how many not
* the collections which are completed/not yet completed
* the ligands which are processed

Please note that for the VFVS module, the `vf_report.sh` command has additional reporting functionality, as described [here](../vfvs/using-vfvs/monitoring.md#vf_report-sh).

## Log Files

What is happening in the workflow in details can be seen via the log files. This is useful in particular for debugging purposes when errors or unexpected problems occur.

There are several types of log files:

* [Log files of jobs](monitoring.md#log-files-of-jobs)
* [Log files of queues](monitoring.md#log-files-of-queues)
* [Ligand lists](monitoring.md#ligand-lists)
* [Module Dependent Log Files](monitoring.md#module-dependend-log-files)

### Logging Verbosity

The level of details in the job and queue log files can be set via the option `verbosity_logfiles`in the control file, which essentially enables the `set -x` option in Bash.  This option is only recommended only for debugging purposes, since it dramatically increases the amount of output and thus log file sizes. If it is used for larger workflows, it can be favorable to use the option `verbosity_logfiles=all_compressed` to reduce the file of the log files. However, due to the compression, the jobs, the last part of the log files might be lost, in particular when errors/unexpected terminations occur.&#x20;

### Log Files of Jobs

The log files of the jobs can be found in the `workflow/output-files/jobs/` folder. Each file in there has the format job-X.Y\_Z.out, where

* X is the jobline ID
* Y is the job iteration number
* Z is the job ID of the batch system

### Log Files of Queues

Each jobs starts a number of queues, and once a queue is started, it will generate its own log files (provided this is not disabled in the control files via the `store_queue_log_files` option.

The log files of the queues can be found in the `workflow/output-files/queues/` folder. Each file there has the format queue-X-Y-Z.W where

* X is the jobline ID
* Y is the job step number
* Z is queue ID
* W is some file ending, depending on the setting in the control file

These files are independent of the jobs, meaning that the queues of successive jobs of a jobline will continue the log files of the same queues of previous jobs.&#x20;

Also, the log files of the queues are stored at first locally in the temporary filesystem to reduce the I/O load, and only at the end of a queue/job will be stored back in the workflow directory. Therefore, if one wants to monitor/investigate the queue file while it is generated, one needs to ssh into the appropriate node on which the queue one is interested in is running.

### Ligand Lists

During the workflow, VirtualFlow uses so called _ligand lists_ to keep track of all the ligands of the collection it is currently processing. In these ligand lists, it stores some information about the success of the processing of this ligand, and how long it has taken. The precise information stored depends on the module of VirtualFlow which is used (VFVS or VFLP), and furthermore which processing steps are carried out during the workflow.&#x20;

The ligand lists are stored text files, one file per collection. These can be permanently stored in the `output-files` folder if this is specified in the control file via the option `keep_ligand_summary_logs`.

### Module-Dependend Log Files&#x20;

The VFVS module stores in addition also the docking output files which are produced by the docking programs.

## Via the Batch System

The batch system jobs which are used by VirtualFlow can in principle also be monitored and queried by the commands which the batch system provides (such as via `squeue` command of SLURM).
