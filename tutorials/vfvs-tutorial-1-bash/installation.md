# Installation

## Choosing the Installation Location

As described in the documentation, VirtualFlow should be installed on a fast shared scratch file system, rather than the home directory (which is often slow and/or has insufficient I/O capacities).

After having chosen the directory where you want VFVS and the workflow to be located, go to this directory:

```
cd <installation directory>
```

## Downloading the Tutorial Files

The tutorial files can be downloaded here:

[https://virtual-flow.org/sites/virtual-flow.org/files/tutorials/VFVS\_GK.tar](https://virtual-flow.org/sites/virtual-flow.org/files/tutorials/VFVS_GK.tar)

The `wget` command can be used for downloading the file directly on the cluster:

```
wget https://virtual-flow.org/sites/virtual-flow.org/files/tutorials/VFVS_GK.tar
```

The tutorial files can now be extracted with the `tar` command:

```
tar -xvf VFVS_GK.tar
```

