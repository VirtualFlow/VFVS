# The Completed Workflow

For all collections which were completed during the workflow, the results are stored in the final output databases. There exists one output database for each docking scenario, and it is located in the folder`output-files/complete/<docking scenario>`.

## Complete Ligand Ranking

To obtain the full ligand ranking, the VFTools package can be used, which can be installed as described [here](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/vftools/installation-1). Assuming it is installed, we create a new folder for the post-processing of the data. In the VFVS root directory we create a new folder:

```
cd <VFVS root directory>
mkdir -p pp/ranking
cd pp/ranking
```

After that, we use the command `vfvs_pp_docking_all.sh` an:

```
vfvs_pp_ranking_all.sh ../../output-files/complete/ 2 meta_collection
```

Here we let the two docking scenarios be post-processed in parallel. Parallel post-processing is particularly useful if the ligand databases are larger and multiple docking scenarios are to be processed.

## Docking Poses

The docking poses of screened ligands are stored in the `output-files/complete/<docking scenario>/results/` folders. In this folder, the docking results (including the poses) are stored hierarchically sorted by metatranches, tranches, and collections (as described [here](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/principles-and-theory/naming-conventions) in the documentation). \
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

{% hint style="danger" %}
**Verification of the results/hits**\
\
It is important to verify that all went well with the docking regarding the virtual screenings hits before ordering them from a compound vendor like Enamine. \
\
This can be done by \
1\) looking at the docking poses\
2\) looking at the potential energies of the docked compounds.
{% endhint %}

The above command also creates an energy-output file, which contains all the potential energies of the docking poses of the compounds. If the energy is above 5000-10000, it is likely that something went wrong with this compound during docking. We recommend to ignore these compounds and filter them out regarding the further analysis.&#x20;

After the virtual screening is completed, we recommend to check the docking poses of the hit compounds before ordering them. It is generally also advisable to look at the docking poses with a molecular viewer like AutoDockTools.&#x20;

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
