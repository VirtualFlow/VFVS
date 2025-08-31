# Installation

## Choosing the Installation Location

VirtualFlow should be installed on a **fast shared scratch file system**, rather than the home directory (which is often slow and/or has insufficient I/O capacities).

After having chosen the installation location, go to the directory were you want VFVS and the workflow files to be stored:

```
cd <installation directory>
```



\[For more information about the installation location, see the [_corresponding section_](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/installation/vflp#installation-location) in the documentation.]

## Installing VFVS

The tutorial files can be downloaded with the `wget` command:

```
wget https://github.com/VirtualFlow/VFVS/archive/refs/heads/vfvs-1.tar.gz
```

Then, the files can be extracted with:

```
tar -xvzf vfvs-1.tar.gz
```

Then we can rename the directory to something more meaningful. In our case we choose as name `VFVS_GK` (for glucokinase), since this is the target we will use:

```
mv VFVS-vfvs-1 VFVS_GK
```



\[For more information about installing VirtualFlow in general, see the [_corresponding section_](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/installation/vflp#tarball-installation) in the documentation.]

