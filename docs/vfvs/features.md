# Features

## Choice of Docking Program

VFVS supports a variety of different docking programs, in particular the members belonging to the large AutoDock family: AutoDock Vina, QuickVina 2, Smina, QuickVina-W, ADFR, Vina Carb, and VinaXB.

## Multiple Replicas

Each docking scenario can be carried out multiple times. This can be very useful when one wants to increase the chance that the docking program finds the docking pose with the global minimum relative to the scoring function which it employs.

## Preview of Results

Even while the virtual screening procedure is still running, VFVS provides the possibility to see results in realtime for each docking scenario which was defined for the screening procedure. It can provide both statistical information regarding the docking scores of all docked ligands, as well as list the highest scoring compounds along with their highest score.

## VFTools

A separate tools-package (VFTools) for Virtual Flow was created, which contains tools which can assist to create the ligand collections in the required layout (provided the ligands are already in the correct format), as well as to automatically postprocess and curate the output files.

## Multistaging

Due to the many options regarding the dockings scenarios, VFVS is suitable for carrying out virtual screenings in a multistaged many. In each stage the accuracy (exhaustiveness, receptor flexibility, docking program, number of replicas, ...) of the dockings can be increased to rescore the highest scoring compounds from the previous stage to enhance the quality of the virtual screening at reduced computational costs.

## Multiple Docking Scenarios

VFVS allows to carry out multiple docking scenarios per ligand. A docking scenario in VFVS is defined by the receptor structure, by the docking parameters (such as exhaustiveness), rigid or flexible receptor docking, the choice of flexible receptor side chains or the docking program. This allows also for ensemble dockings.

## Machine Learning Classifier for Molecule Prioritization

VFVS supports an optional machine learning classifier that prioritizes which molecules within a collection are worth docking, based on a small representative prescreen run. Molecules predicted unlikely to be high-affinity binders are skipped before docking, reducing computational cost for large screens while maintaining hit enrichment. This is disabled by default and available on both the Slurm/HPC and AWS Batch execution paths; see [Preparing the Workflow](using-vfvs/preparing-the-workflow.md#machine-learning-classifier-for-molecule-prioritization).
