# Controlling the Workflow

## Introduction

The workflow of VirtualFlow can generally be controlled in the following ways:

* [Jobs/joblines can be stopped](pausing-and-continuation.md#stopping-of-joblines)
* [Jobs/joblines can be continued](pausing-and-continuation.md#continuation-of-joblines)
* [Joblines can be modified (during the runtime)](pausing-and-continuation.md#modification-of-joblines)

## Stopping of Joblines

There are two ways on how one can stop jobs and joblines, via stop flags and via the batch system.

### Via Stop Flags (Preferred Way)

To stop joblines, one can use the control files, which provides three switches (stop flags) to stop the joblines:

* _stop\_after\_collection_: This option lets each queue of the job complete the ligand collection it is currently working on before stopping the job/jobline.
* _stop\_after\_job_: This option lets the job complete before stopping the jobline
* _stop\_after\_next\_check\_interval_: This option stops each queue of the job/jobline as soon as it checks again the control file for the stop flag. This is normally the fastest way. How often each queue checks the control file for the stop flag is determined by the option _ligand\_check\_interval_ in the control file. the ligand\_check\_interval setting is read by each job at the beginning, and is not updated during the runtime of a job. Changes in this parameter are only affecting future jobs.&#x20;

This way is the preferred way, because the way via the batch system only works under certain conditions (described below), and even then can result in data loss.&#x20;

### Via the Batch System

If the control file the setting `error_response=fail` is set, then one can use  the batch system to terminate the jobs, since in this case the joblines will will not continue but fail due to the above setting. In the case of SLURM as the batch system, the command to cancel jobs has the name `scancel`.

If the setting would be set to another value (e.g. ignore), then it is possible that the jobline manages to start the next successor job before it is terminated by the resource manager. This is the case because the batch system normally sends at first some warning signals to the jobs to allow them to cleanup and complete gracefully, and only after a certain grace period terminates the jobs if they are still running.&#x20;

## Continuation of Joblines

To continue joblines which were stopped, cancelled, or terminated due to other reasons such as errors or cluster problems, the commands `vf_continue_jobline.sh` and `vf_continue_all.sh` are provided. If the joblines were stopped via the stop flags in the control files, the stop flags have to be remove/set to false at first before continuing the joblines (otherwise the jobs will terminate immediate since they check these flags at the beginning).

The command `vf_continue_jobline.sh` allow to specify a range of jobline IDs which should be continued. It automatically detects joblines which are already in the batch system to prevent double submission of jobs. The command `vf_continue_all.sh` continues all joblines which exist and are currently not running.

## Modification of Joblines

### Via Control Files

During the runtime, or during times where joblines are stopped, joblines can be modified via the _**control files**_ as specified [here](preparing-the-workflow.md#control-files) in the section[ Preparing the Workflow](preparing-the-workflow.md).

### Via Job Files (rarely needed)

Also, the _**job files**_ themselves can be modified in the folder workflow/job-files/main/, which will affect future jobs of the corresponding jobline. This could for instance be useful if one wants to change the memory settings for a job (which is rarely the case). Normally it is not needed to change settings in the job files, since all important settings are managed via the control files. Also, it is more laborious to change settings in the job files of active workflows since each of the possible large number of job files needs to be modified.

