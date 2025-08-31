# Monitoring the Workflow

## Introduction

In addition to the general monitoring possibilities in VirtualFlow as described here, the VFVS module allows to previous the current virtual screening results while the workflow is still running. Thes functions are provided via the `vf_report.sh` command, which was extended for VFVS.

## vf\_report.sh

Shown below is the help output of the `vf_report.sh` command:

```
$ vf_report -h

Usage: vf_report [-h] -c category [-v verbosity] [-d docking-type-name] [-s][-n number-of-compounds]

Options:
    -h: Display this help
    -c: Possible categories are:
            workflow: Shows information about the status of the workflow and the batchsystem.
            vs: Shows information about the virtual screening results. Requires the -d option.
    -v: Specifies the verbosity level of the output. Possible values are 1-3 (default 1)
    -d: Specifies the docking type name (as defined in the workflow/control/all.ctrl file)
    -s: Specifies if statistical information should be shown about the virtual screening results (in the vs category)
        Possible values: true, false
        Default value: true
    -n: Specifies the number of highest scoring compounds to be displayed (in the vs category)
        Possible values: Non-negative integer
        Default value: 0
```

In order to show preliminary screening results, the value "vs" has to be passed to the -c option. In addition, the docking type has the specified for which the preliminary results should be shown. This is done via the docking type name variable which was specified in the control file.

By default statistical data about the predicated binding affinities will be shown (i.e. the "-s true" option is active). This can be disabled with the "-s false" option, which will speed up the output generation.

In addition, the command can list the \<N> top-scoring compounds if the "-n \<N>" option is passed to it.&#x20;



### Time delay&#x20;

The preliminary results of the `vf_report.sh` are not fully in real-time, but with some time delay, because VirtualFlow uses the local storage of the compute nodes to run the docking procedures, and only after a ligand collection is completed it copies it back to the shared filesystem in order to reduce I/O. Therefore, the results of ligand collections which are currently processed are not included in the preliminary results.
