# Prerequisities

Described on this site are the general prerequisites, which are required for all modules of VirtualFlow. But in addition, each module of VirtualFlow has individual prerequisites as described in the corresponding sections:

* [VFLP - Installation - Prerequisites ](../vflp/installation/prerequisities.md)
* [VFVS - Installation - Prerequisites ](../vfvs/installation/prerequisites.md)

## Linux Cluster with Batchsystem

VFLP runs on Linux clusters which are managed by a batch system (resource manager), or cloud computing platforms on top of which a batch system is run. Out of the box, the following batch systems are supported:

* SLURM
* LSF
* Moab/TORQUE
* PBS
* SGE

Support for other batch systems can be added by simply creating a new batch system job template in the folder tools/templates/, and one can use one of the other templates as a template.

## BASH

VFLP was only tested with BASH version 4.2 and higher, even though it might run with older versions as well.&#x20;

If the system BASH is older, than version 4.2, normally the system admins of the Linux cluster can make a newer version available. Alternatively, one can compile a recent version of BASH by oneself and install it locally (for instance in the home folder).
