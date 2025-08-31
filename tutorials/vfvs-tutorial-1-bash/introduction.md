---
description: This is the first tutorial for VirtualFlow for Virtual Screening (VFVS).
---

# Introduction

## Aims

The goals of this tutorial are to demonstrate:

1. [How VFVS can be installed](installation.md) (in a preconfigured setting)
2. [How the workflow prepared ](setting-up-the-workflow.md) (in a preconfigured setting)
3. How VFVS is principally used:
   1. [Starting the workflow](starting-the-workflow.md)
   2. [Monitoring the workflow](monitoring-the-workflow.md)
4. [How to obtain the output database after completion](the-completed-workflow.md)

This is a short tutorial, which only covers some of the basics.

## The Target

The target structure in this tutorial is human glucokinase (GK), and the purpose of the screening is to find activating compounds (see also [Petit _et al._](http://scripts.iucr.org/cgi-bin/paper?S0907444911036729) for background information). The structure used has PDB ID 4NO7 ([https://www.rcsb.org/structure/4NO7](https://www.rcsb.org/structure/4NO7)).&#x20;

![Human glucokinase (GK). The structure shown has PDB ID 4NO7.](<../.gitbook/assets/Screenshot at 2019-03-18 08-06-11.png>)

## Docking Scenarios

The files in this tutorial come with two pre-configured docking scenarios:

1. [QuickVina 2](https://academic.oup.com/bioinformatics/article/31/13/2214/195750) with exhaustiveness set to 8
2. [Smina Vinardo](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0155183) with exhaustiveness set to 4

All other docking parameters are the same for both docking programs.

The pre-configured docking box is shown below:

![](<../.gitbook/assets/Screenshot at 2019-03-18 08-02-56.png>)

![](<../.gitbook/assets/Screenshot at 2019-03-18 08-03-10.png>)

![](<../.gitbook/assets/Screenshot at 2019-03-18 08-03-18.png>)

Details on how to prepare the docking input files for Autodock Vina-based programs can for example be found at [http://vina.scripps.edu](http://vina.scripps.edu/).&#x20;





