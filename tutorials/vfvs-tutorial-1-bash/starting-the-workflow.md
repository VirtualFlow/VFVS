# Starting the Workflow

&#x20;   &#x20;

After preparing the workflow, it can be started with the command `vf_start_joblines.sh`. &#x20;

{% hint style="info" %}
The pre-configured todo list (`tools/templates/todo.all`) contains 1123 ligands to be screened.  One queue was pre-configured in the `tools/templates/all.ctrl` file to have around 100 ligands in their local todo lists. If you did not change the number of nodes/CPUs used by one job, then each job uses one CPU (or queue). This means, that if we use 12 jobs in parallel, 12 queues will run in parallel, and each queue will process around 100 ligands, which will covert the 1123 ligands completely.&#x20;

If, on the other hand, jobs with more queues are submitted, then one needs to submit less jobs to employ the same number of queues.
{% endhint %}

To start 12 jobs in parallel on a SLURM cluster, the following command can be used (within the`tools` directory):

```
./vf_start_jobline.sh 1 12 templates/template1.slurm.sh submit 1
```

If your cluster uses another batch system, you need to use the corresponding job template.  We use a delay time of 1 only because we are submitting a small number of jobs.  When larger number of jobs are submitted, a larger delay time can be useful to avoid that too many jobs try to access the central task list at the beginning at the same time.

\[For more information about starting of the workflow in general, see the [_corresponding sectio_](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/using-virtualflow/starting-jobs)_n_ in the documentation.]
