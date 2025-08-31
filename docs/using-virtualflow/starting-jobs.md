# Starting the Workflow

## General

After the workflow was prepared, it can be initialized by starting jobs with the command

```
vf-start-jobline.sh <start-jobline-id> <end-jobline-id> <job-template>
                    <submit-mode> <delay-time-in-seconds>
```

Each of the arguments is explained below in the corresponding section:

* [\<start-jobline-id> \<end-jobline-id>](starting-jobs.md#less-than-start-end-jobline-id-greater-than)
* [\<job-template>](starting-jobs.md#less-than-job-template-greater-than)
* [\<submit-jobs>](starting-jobs.md#less-than-submit-jobs-greater-than)
* [\<delay-time-in-seconds>](starting-jobs.md#less-than-delay-time-in-seconds-greater-than)

## \<start/end-jobline-id>

Each job which is used by VirtualFlow has a jobline ID, which is a positive integer. The jobs which are started with the command `vf-start-jobline.sh` are all which fall within the range of specified with \<start-jobline-id> and \<end-jobline-id>. More information on jobs and corresponding job names can be found in the section [Background and Principle.Job Organisation.Batchsystem Jobs](../principles-and-theory/job-organization.md#batchsystem-jobs).

## \<job-template>

The template which is used for the jobs. The default templates which are shipped with VirtualFlow are located in the folder `tools/templates/`. For instance, the default template with SLURM as the batchsystem is the file  `tools/templates/template1.slurm.sh`.

Please note that the job template has to be set up properly before it is used. How this can be done is described in the previous section: [Preparing the Workflow.Preparing the Tools Folder.Job File Template](preparing-the-workflow.md#the-job-file-template).

One can use different job templates for different joblines. For instance, one can copy the job file `tools/templates/template1.slurm.sh` to `tools/templates/template2.slurm.sh` with different memory settings and use it for a certain set of joblines for testing purposes. However, normally it is not needed to use different job files, since all important settings are managed via the control files.

## \<submit-jobs>

Possible values:

* _**true:**_ The batch system jobs are prepared and submitted.
* _**false:**_ The batch system jobs are only prepared,  not submitted.&#x20;

Normally, one submits the jobs during this step. If the jobs are not submitting at this step, they need to be submitted manually without any command provided by VirtualFlow, but by using the commands provided by the resource manager. Not submitting the jobs here is mainly useful for debugging purposes.&#x20;

## \<delay-time-in-seconds>

Possible values: Non-negative integer&#x20;

The delay time is used in between the submission of the jobs which are started with the command `vf-start-jobline.sh`. A delay time is useful to prevent that all jobs start at the same time, which would result in all of them trying to access the central task list at the same time. If too many jobs try to do that at the same time, it can lead to the corruption of the central task list. The optimal delay time depends from case to case. In the beginning of each job, the workload balancer is used to create local task lists for each queue of the job. It takes the longer the more queues it is has to serve, the more tasks each queue is supposed to have, and the slower the file system is. One can find out about the time which the load balancer needs by looking into the log files in the folder workflow/output-files/jobs/. The workload balancer reports the time it has needed in the following form:

_`The todo lists for the queues were (re)filled in 2 second(s) (waiting time not included).`_

One can find this line with tools like `grep` or `less`. For instance, to get the (re)filling time for all the job files in one can run:

`grep "The todo lists for the queues" worflow/output-files/jobs/`

In this way one can get the average value, and use a value slightly above that the delay time to prevent that too many jobs are accumulating in the waiting queue of jobs trying to access the central task list.
