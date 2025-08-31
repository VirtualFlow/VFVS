# Troubleshooting

## Introduction

Problems regarding VirtualFlow and approaches to solving them can be classified into two categories:

1. General problems, where the precise problem is yet to be determined.
2. Specific problems, where the precise problem could already be determined.

Accordingly, we classify the approaches for troubleshooting into these two categories:

1. [General problems/approaches](troubleshooting.md#general-problems-approaches)
2. [Specific problems/approaches](troubleshooting.md#specific-problems-approaches)

## General Problems/Approaches

Overview of general approaches:

* [Increasing the command-verbosity](troubleshooting.md#increasing-the-command-verbosity)
* [Inspecting log files and workflow files](troubleshooting.md#inspecting-log-files-and-workflow-files)
  * Logfiles in `workflow/output-files/jobs/`
  * Logfiles in `workflow/output-files/queues/`
  * Ligand processing status logs in `workflow/ligand-collections/ligand-lists/`
* [Interactive jobs](troubleshooting.md#interactive-jobs)

### Increasing the Command-Verbosity

The verbosity of the VirtualFlow end-user commands (starting with `vf_`) can be increased by setting the option `verbosity_commands` in the control file to the value 'debug':

```
verbosity_commands=debug
```

### Inspecting log files and workflow files

The verbosity of the VirtualFlow logfiles (in the `workflow/output-files/` folders) be increased by setting the option `verbosity_logfiles` in the control file to the value 'debug':

```
verbosity_logfiles=debug
```

This will affect the following log files:

* Logfiles in `workflow/output-files/jobs/`
* Logfiles in `workflow/output-files/queues/`

In addition, the processing status of each ligand and possible errors related to the processing steps can be found int the the subfolders of the `workflow/ligand-collections/ligand-lists/` folder.

### Interactive Jobs

Interactive jobs can for instance be useful when VirtualFlow starts the workflow and begins using the local storage of the compute nodes, but then crashes and does not manage to copy back the log-files which are stored on the compute nodes. If this case, if one is running VirtualFlow via an interactive job and is logged in to the compute node, one has immediate access to all the workflow files of VirtualFlow on that compute node.&#x20;

Similarly, one can run non-interactive jobs and then `ssh` into the the compute node which is used by VirtualFlow. However, this does not always work because if the job crashes and terminates, `ssh` access is often automatically terminated as well to that compute node (since one may not have any more job running on that node, which is often a requirement for `ssh` access to a compute node).

## Specific Problems/Approaches

\[Will be added with feedback from future users.]
