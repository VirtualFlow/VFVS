# Starting the Workflow

After preparing the workflow, it can be started with the command `vf_start_joblines.sh`.&#x20;

To start 10 jobs in parallel on a SLURM cluster, the following command can be used (within the`tools` directory):

```
./vf_start_jobline.sh 1 10 templates/template1.slurm.sh submit 1
```

If your cluster uses another batch system, you need to use the corresponding job template.  We use a delay time of 1 only because we are submitting a small number of jobs.  When larger number of jobs are submitted, a larger delay time can be useful to avoid that too many jobs try to access the central task list at the beginning at the same time.&#x20;



\[For more information about starting the workflow in general, see the [_corresponding section_ ](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/using-virtualflow/monitoring)in the documentation.]
