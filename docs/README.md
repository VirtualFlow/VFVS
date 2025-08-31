# Introduction

## General

VirtualFlow is a versatile, parallel workflow platform for carrying out virtual screening related tasks on Linux-based computer clusters of any type and size which are managed by a batch system (resource manager).

Since resource managers can run on top of cloud computing platforms, VirtualFlow is also ready to be directly deployed on cloud platforms like Amazon Web Services (AWS), Google's Cloud Platform (GCP), or Microsofts Azure. More information can be found in the section [Running VirtualFlow in the Cloud](running-virtualflow-in-the-cloud.md).

## Modules

Currently, there exist two VirtualFlow modules, [**VFLP (**&#x56;irtualFlow for Ligand Preparation](vflp/untitled.md)) and [**VFVS (**&#x56;irtualFlow for Virtual Screenings](vfvs/introduction.md)). These two modules share a common core technology, and therefore also a number of features. The documentation therefore exists of three parts, a general part for all versions of VirtualFlow, and one part for each VFLP and VFVS:

* [**VFLP:** VirtualFlow for Ligand Preparation](vflp/untitled.md)
* [**VFVS:** VirtualFlow for Virtual Screenings](vfvs/introduction.md)

Information for each VirtualFlow module and how to use it is therefore distributed in two different parts of the documentation (for instance information about VFVS and how to use it is found in the general part called VirtualFlow, as well as in the part of the documentation dedicated to VFVS). The general information is not duplicated in the more specific parts, therefore the general part is always relevant.

## Applications

VirtualFlow can be used for many steps relevant in the drug discovery process, such as:

* **Ligand preparation (VFLP)**
  * Preparation of general-purpose ligand databases, e.g. into a ready-to-dock format
  * Preparation of custom analog libraries based for hit/lead optimization\

* **Hit identification (VFVS)**
  * By virtually screening privately or publicly available ligand libraries\

* **Hit/lead optimization (VFVS)**
  * By screening custom libraries of analogs of certain hit/lead compounds\

* **Binding site identification of experimental hits (VFVS)**
  * By carrying out extensive docking studies of the hit compounds

## Learning VirtualFlow

VirtualFlow tries to make virtual screening related tasks on computer clusters and cloud computing platforms as simple as possible. But because each cluster and computing platform is different, and because we designed VirtualFlow in a way which allows it to run on all of them, it still can take some time to learn everything you need to know. In particular, the following topics are relevant:&#x20;

* _Linux/Bash:_ You should be comfortable with using the Linux command line, in particular Bash. There are many online tutorials available, such as [this](https://www.tldp.org/LDP/Bash-Beginners-Guide/html/Bash-Beginners-Guide.html) one.
* _Linux Clusters/Resource managers:_ You need to be comfortable with using the cluster you want to use, in particular its resource manager (such as SLURM). Often, the institution which provides/manages the cluster regularly offers free user training sessions for beginners which one can take part in.
* _VirtualFlow_: You need to understand how VirtualFlow works, and how to use it.

### How long does it take to learn using VirtualFlow?

If you are new to Linux, the command line, and/or computer clusters, and need to learn the basics, it might take a week or two to learn everything you need to know to use VirtualFlow efficiently.

If you are already comfortable with the Linux command line and computer clusters/batch systems, learning VirtualFlow is relatively simple. However, it still will need some initial time (a few days) to understand how everything works and to be able to use it efficiently. But once you know everything, using VirtualFlow will become a breeze.



