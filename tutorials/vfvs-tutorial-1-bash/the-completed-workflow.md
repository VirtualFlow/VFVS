# The Completed Workflow

For all collections which were completed during the workflow, the results are stored in the final output databases. There exists one output database for each docking scenario, and it is located in the folder`output-files/complete/<docking scenario>`.

## Complete Ligand Ranking

To obtain the full ligand ranking, the VFTools package can be used, which can be installed as described [here](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/vftools/installation-1). Assuming it is installed and the commands available in the `PATH` variable, we create a new folder for the post-processing of the data. In the VFVS root directory we create a new folder:

```
cd <VFVS root directory>
mkdir -p pp/ranking
cd pp/ranking
```

After that, we use the command `vfvs_pp_docking_all.sh` an:

```
vfvs_pp_ranking_all.sh ../../output-files/complete/ 2 meta_tranche
```

Here we let the two docking scenarios be post-processed in parallel. Parallel post-processing is particularly useful if the ligand databases are larger and multiple docking scenarios are to be processed.

{% hint style="info" %}
If the command above does not work, also check the help text of the command by running `vfvs_pp_ranking_all.sh -h ,`since you might have a different version installed than in the tutorial, and the options might have changed in the meantime.&#x20;
{% endhint %}

## Docking Poses

The docking poses of screened ligands are stored in the `output-files/complete/<docking scenario>/results/` folders. In these folders, the docking results (including the poses) are stored hierarchically sorted by metatranches, tranches, and collections (as described [here](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/principles-and-theory/naming-conventions) in the documentation). \
\
If one wants to obtain one or a few docking poses of some of the hits for further analysis, one can manually extract them. Alternatively, the VFTools package provides a script for extracting the docking poses automatically, which is in particular convenient when the docking poses for a larger number of ligands should be extracted.

As an example, if we want to extract the docking poses of the top 100 hits of docking scenario  _'qvina02\_rigid\_receptor1'_ , then we can do this as follow. At first we create a new folder for the docking poses of this docking scenario:

```
cd ..
mkdir -p docking_poses/qvina02_rigid_receptor1
cd docking_poses/qvina02_rigid_receptor1
```

Next we need to create a list of the compounds for which we want to get the docking poses, i.e. the top 100 hits of docking scenario _qvina02\_rigid\_receptor1._ We can do this by using the `head` command:

```
head -n 100 ../../ranking/qvina02_rigid_receptor1/firstposes.all.minindex.sorted.clean > compounds
```

The file `../../ranking/qvina02_rigid_receptor1/firstposes.all.minindex.sorted.clean` contains in the first column the collection, and in the second column the compound ID. This is the same format which the command `vfvs_pp_prepare_dockingposes.sh` requires. We can use the command now as follows:

```
vfvs_pp_prepare_dockingposes.sh ../../../output-files/complete/qvina02_rigid_receptor1/results/ meta_collection compounds dockingsposes overwrite
```

## Long-Term Storage

For long-term storage, we create a tar archive of either the entire VirtualFlow root folder:

```
cd ../../..
tar -xvzf VFVS_GK.tar.gz VFVS_GK
```

## Uninstallation

To uninstall VFVS, one simply needs to delete the root folder of the workflow:

```
rm -vr VFVS_GK
```
