# External Packages

VFLP requires three external packages to be installed:&#x20;

1. [Java](external-packages.md#java)
2. [Nailgun](external-packages.md#nailgun)
3. [ChemAxon's JChemSuite](external-packages.md#chemaxons-jchemsuite)

&#x20;have to be provided within the VirtualFlow directory, more precisely the directory `<vf-root>/tools/packages.`

VirtualFlow will then install and use these packages automatically.

OpenBabel in the [prerequisites section](prerequisities.md) is not classified as an external package here in this documentation, because it can be installed independently of VirtualFlow (and may not be needed to be installed at all if it is already available).

## Java

Java (for Linux) needs to be provided to VFLP as a gzipped tarball (i.e. a tar.gz-archive). The minimum version required is 8. OpenJDK (a popular version of Java) can be found at [https://jdk.java.net](https://jdk.java.net).&#x20;

The reason that a local version has to be provided is that VFLP will install it locally on the compute nodes on the temporary file system (which is specified in the control file) in order to reduce the I/O load of the cluster as well as for increasing the performance.

The root folder in the tar.gz-archive has to have the name `java`. This means that the package most likely has to be modified by the user (since the root folder varies between java distributions), at first by unpacking it:

```
tar -xvf <java-package>.tar.gz
```

Then by changing the name of the root folder (e.g. if the root folder in the distribution package has the name `jdk-11.01`,  by:

```
mv jdk-11.01 java
```

And then repacking the java distribution:

```
tar -cvzf java11.tar.gz java
```

The name of the final tar.gz file can be freely chosen, and has to be specified in the VFLP config file.&#x20;

Finally, the package can be stored in the folder `<vf-root>/tools/packages.`

## Nailgun

Nailgun is a java program which provides a persistent Java virtual machine. For VFLP, it provides an extreme speedup of usually more than an order of magnitude (in particular when using JChem's tools as the first choice over OpenBabel).

Nailgun can be downloaded via GitHub:

* [https://github.com/facebook/nailgun](https://github.com/facebook/nailgun)

After downloading the ZIP-archive, it needs to be modified by the user in order to be ready to be used by VFLP. In particular, the root folder needs to be renamed, and the package stored in the tar.gz format. For this purpose, the archive is at first uncompressed by:

```
unzip nailgun-master.zip
```

Then the root folder is rename:

```
mv nailgun-master nailgun
```

And finally, the folder is repackaged into the tar.gz format:

```
tar -cvzf nailgun.tar.gz nailgun
```

The name of the nailgun archive can be chosen freely, as it has to be specified in the VFLP control file.

In the end, the package has to be placed in the folder `<vf-root>/tools/packages`

## ChemAxon's JChemSuite

VFLP can use ChemAxon's JChemSuite for carrying out several steps of the molecule preparations, though Open Babel can currently be used as well instead. _**A suitable academic or commercial license needs to be obtained from ChemAxon directly.**_ The licence file has to be stored in the folder `tools/packages/`,  and the name of the license file has to be specified in control file via the variable `chemaxon_license_filename`.

The JChemSuite package can be downloaded here from ChemAxon's homepage after registration:

* [https://chemaxon.com/products/jchem-engines](https://chemaxon.com/products/jchem-engines)

The version which has to be selected is "JChem Base" in the platform independent ZIP format.

For VFLP the package has to be reformatted again, at first by extracting and renaming the root folder to `jchemsuite`, and then by creating a tar.gz archive:

```
unzip jchem_platform_independent_18.30.zip
mv jchem jchemsuite
tar -cvzf jchemsuite.tar.gz jchemsuite
```

The tar.gz archive can now be stored in the folder `<vf-root>/tools/packages/`.
