# General Features

The following describes the features of VirtualFlow in general. The features specific to each VirtualFlow module are described in the corresponding chapters:

* [VFLP - Features](vflp/features.md)
* [VFVS - Features](vfvs/features.md)

## **Scaling behavior**

VirtualFlow can be extremely fast due to its perfect scaling behavior (even when using very large number of CPUs). There are virtually no bounds regarding the number of processors which can be utilized by VirtualFlow. In addition, it supports some of the fastest docking programs available such as QuickVina 2.

## **Error Robustness**

VirtualFlow is relatively robust regarding unexpected errors and interruptions, which often occur on computer clusters. VirtualFlow can respond to signals sent to it by the (batch or operating) system in the case of cluster problems, but even after termination without warning it can simply be resumed.

## **Any Cluster Configuration**

VirtualFlow runs out of the box on any GNU/Linux cluster which is managed by a batch system. The workflow tool can use any conceivable hardware configuration regarding the number of cores/CPUs, the number of sockets, the number of nodes, etc. The software runs on any Linux distribution.

## **Any Batchsystem**

VirtualFlow currently supports the following batch systems out of the box:

* SLURM
* Moab/TORQUE
* PBS
* LSF
* SGE

The provided job templates can be adjusted if required. In addition, VirtualFlow can be easily extended by users to other job schedulers by creating additional job-templates.

## **Monitoring**

The workflow can be monitored in real time in different ways during the execution. This allows to track the progress of the workflow, as well as to examine possible problems during or after the runtime.

## **Highly Automatized**

Virtual Flow can run fully automatically for any duration of time until it has processed all ligands specified in the input files. It achieves this by autonomously ending and submitting new jobs into the batch system as needed.

## **Realtime Control**

The workflow can be controlled and modified during the runtime. The workflow can, for instance, be paused, resumed, and the utilized hardware resources and job configurations changed. The workflow can be transferred to other clusters and resumed there if desired.

## **Convenient Input and Output Formats**

The input and output ligand databases consist of hierarchical multilevel tar-archives which are compressed. This compact format allows to easily handle vast amounts of ligands in an efficient and scalable manner.

## **Free & Libre Software**

VirtualFlow is licensed under the GNU GPL v3. Moreover, it is available at no costs. (The two terms of _free/libre_ software and open _source software_ are two different, but closely related concepts, see for instance [here](https://www.gnu.org/philosophy/open-source-misses-the-point.en.html).)

## **Open Source Development Model**

VirtualFlow is developed in an open collaborative development model, warmly inviting anyone to join. This allows VirtualFlow to grow more quickly and healthily in the way the community desires.
