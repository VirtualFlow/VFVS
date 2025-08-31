# Job Organization

### General

To run computations on computer clusters which are managed by a batch system (resource manager), one generally needs to submit jobs into batch system. This is also the case with VirtualFlow. VirtualFlow uses batchsystem job to run the workflow, and can use any number of them. Each of these batchsystem jobs has a hierarchy of subjobs.

Overview of the hierarchical job structure/organization:

* Batchsystem jobs: Any number
  * Job steps: Usually one per node
    * Queues: Usually one per CPU core
      * Mutlithreading: Can be used if the external programs which process the ligands are multithreading enabled



### Batchsystem Jobs

Each batchsystem job has a name of the form&#x20;

`<workflow_letter>-<job-id>.<iteration_no>`

where

* `<workflow-letter>` is a single letter which depends on the workflow, and can be specified in the control file. The workflow-letter is useful to distinguish multiple different workflows if they are running in parallel.
* `<jobline-id>` is the ID of the job, which is a positive integer.&#x20;
* `<jobline-iteration-no>` is the number of how many times this particular jobline was already running since the beginning of the workflow. After a job has finished and restarts a successive job to continue to the work, the `<jobline-iteration-no>` is increased (see also the figure below).

For example, the jobname "a-1123.3" would be a job of the workflow with workflow ID "a", with jobline ID 1123, and with iteration number 3.



![Figure 1: Joblines in VirtualFlow are successive jobs with the same jobline ID. Once a job is completed, normally the next successor job is started by the job which just finishes its work. The jobline iteration number is increased by 1 with each new successor job.](../.gitbook/assets/joblines.png)





