# Monitoring the Workflow

The workflow can for instance be monitored by the command `vf_report.sh`.&#x20;

To get information about the workflow in general, within the `tools` folder one can run

```
./vf_report.sh -c workflow
```

{% hint style="info" %}
Please note that the numbers in the _**Ligands**_ and _**Dockings**_ sections only consider the completed collections. Collections currently in processing are not included yet in these counts.
{% endhint %}

To get preliminary virtual screening results for the docking scenario _qvina02\_rigid\_receptor1_, one can run  the command (within the `tools` folder):

```
./vf_report.sh -c vs -d qvina02_rigid_receptor1 -n 10
```

The -n option here specifies that we would also like to have the top 10 compounds listed.



\[For more information about monitoring the workflow in general, see the [_corresponding section_ ](https://docs.virtual-flow.org/documentation/-LUuXd7bP4jqFNOe_7qQ/using-virtualflow/monitoring)in the documentation.]
