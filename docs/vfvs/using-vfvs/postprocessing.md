# The Completed Workflow

## Complete Ligand Ranking

To obtain the complete ranking of all ligands which were screened, the data in the output-files folder needs to be post processed. For this purpose, one can use the VFTools package can be used, which can be installed as described [earlier](../../installation/vftools.md).

At first, it is recommended to create a new folder `<VFVS root directory>/pp/ranking`:

```
cd <VFVS root directory>
mkdir -p pp/ranking
cd pp/ranking
```

After that, one can use the commands `vfvs_pp_ranking_single.sh` and  `vfvs_pp_ranking_all.sh` to prepare the ranking or one or all docking scenarios, respectively. The usage of these commands can be displayed by using the `-h` option.



## Docking Poses

The docking poses of screened ligands are stored in the `output-files/complete/<docking scenario>/results/` folders. In these folders, the docking results (including the poses) are stored hierarchically sorted by metatranches, tranches, and collections (as described [here](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/principles-and-theory/naming-conventions) in the documentation). \
\
If one wants to obtain one or a few docking poses of some of the hits for further analysis, one can manually extract them. Alternatively, the VFTools package provides a script for extracting the docking poses automatically, which is in particular convenient when the docking poses for a larger number of ligands should be extracted.

As an example, if we want to extract the docking poses of the top 100 hits of a docking scenario with name _'qvina02\_rigid\_receptor1'_ , then we can do this as follow. At first we create a new folder for the docking poses of this docking scenario:

```
cd <VFVS root directory>
mkdir -p pp/docking_poses/qvina02_rigid_receptor1
cd pp/docking_poses/qvina02_rigid_receptor1
```

Next we need to create a list of the compounds for which we want to get the docking poses, i.e. the top 100 hits of docking scenario _qvina02\_rigid\_receptor1._ Assuming we have already prepared the complete ligand ranking as described [above](postprocessing.md#complete-ligand-ranking), we can do this by using the `head` command:

```
head -n 100 ../../ranking/qvina02_rigid_receptor1/firstposes.all.minindex.sorted.clean > compounds
```

The file `../../ranking/qvina02_rigid_receptor1/firstposes.all.minindex.sorted.clean` contains in the first column the collection, and in the second column the compound ID. This is the same format which the command `vfvs_pp_prepare_dockingposes.sh` requires. We can use the command now as follows:

```
vfvs_pp_prepare_dockingposes.sh ../../../output-files/complete/qvina02_rigid_receptor1/results/ meta_collection compounds dockingsposes overwrite
```

Different options to the command might be needed depending on the settings which were used during the screening.

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
