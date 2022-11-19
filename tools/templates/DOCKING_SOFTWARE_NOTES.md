
### Running with ADFR: 
For running ADFR, a trg receptor file (generated during pre-processing) needs to be provided by the user. The config.txt file <br>
can contain the line: 
```
    receptor=test.tmp
```
Note: ADFR needs to be installed such that it can run by using the word 'adfr' in shell (from any location).


### Running with PLANTS:
A PLANTS executable (with the exact name PLANTS) must be downloaded from http://www.tcd.uni-konstanz.de/research/plants.php, and 
placed within the directory /tools/bin (where other executables are located).<br>
A config.txt file is required for running PLANTS. An example of the config file format is: 
```
    protein_file receptor.mol2
    write_multi_mol2 0
    bindingsite_center 10.0 12.0 5.0
    bindingsite_radius 5.0 
    cluster_structures 10
    cluster_rmsd 2.0
```

### Running with AutodockZN: 
For AutodockZN, the config.txt file must contain: 
``` 
    afinit_maps_name=receptor_tz # the location of the affinity maps file (for example, receptor_tz.gpf). For AutoDockZN, .gpf does not need to be specified
    exhaustiveness=8
```
    
### Running with Gnina: 
A gnina executable (with the exact name 'gnina') must be downloaded from https://github.com/gnina/gnina, and 
placed within the directory /tools/bin (where other executables are located).<br>
A config.txt file is required for running gnina. An example of the config file format is: 
```
    center_x=16.0
    center_y=10.0
    center_z=3.0
    size_x=4.0
    size_y=4.0
    size_z=4.0
    exhaustiveness=8
    receptor=receptor.pdb
```
    
### Running with rDOCK
For rDOCK, the key word 'rbdock' must be able to activate the program (see download instructions from: https://rdock.sourceforge.net/; or, download with conda: conda install -c bioconda rdock). 
The config.txt file must contain: 
```
    rdock_config=./config.prm # Location for the prm (rdock settings) file
    runs=50 # Number of runs
    dock_prm=dock.prm
```
    
Format for the config.prm file: 
```
        RBT_PARAMETER_FILE_V1.00
        TITLE gart_DUD
        RECEPTOR_FILE receptor_location # TODO
        SECTION MAPPER
            SITE_MAPPER RbtLigandSiteMapper
            REF_MOL ref_ligand_location # TODO
            RADIUS 6.0
            SMALL_SPHERE 1.0
            MIN_VOLUME 100
            MAX_CAVITIES 1
            VOL_INCR 0.0
           GRIDSTEP 0.5
        END_SECTION
        SECTION CAVITY
            SCORING_FUNCTION RbtCavityGridSF
            WEIGHT 1.0
        END_SECTION
```

### Running with M-Dock
The config.txt file must contain: 
```
    mdock_config=./mdock_dock.par # Location for the mdock settings file
    protein_name=protein # Location and name for the prepared protein structure (Note: during preparation of a protein with MDock, a protein.sph file is created).
```
An MDock executable (of name 'MDock_Linux') should be placed in the directory: /tools/bin <br>

Format for the mdock_dock.par file: 
```
    clash_potential_penalty      |      3.0
    orient_ligand (yes/no)       |      yes
    minimize_ligand (yes/no)     |      yes
    maximum_orientations         |      100
    gridded_score (yes/no)       |      yes
    grid_spacing (0.3~0.5)       |      0.4
    sort_orientations (yes/no)   |      yes
    write_score_total            |      100
    write_orientations (yes/no)  |      yes
    minimization_cycles (1~3)    |      1
    ligand_selectivity (yes/no)  |      no
    box_filename (optional)      |      
    grid_box_size                |      10.0
    sphere_point_filename        |      recn.sph
```

### Running with MCDock
A MCDock executable (of name 'mcdock') should be placed in the directory: /tools/bin

### Running with LigandFit
A LigandFit executable (of name 'ligandfit') should be placed in directory: /tools/bin <br>
The config.txt file should contain: 
```
    receptor_mtz=./receptor.mtz # Location for the receptor file (in mtz format)
    receptor=./receptor.pdb # Location for the receptor file (pdb format)
    center_x=10
    center_y=10
    center_z=10
```
 
### Running with Ledoc
The config.txt file should contain: 
```
    receptor=1x1r.pdb
    rmsd=1.0
    min_x=-6.36
    max_x=13.2
    min_y=0.7
    max_y=19.06
    min_z=-0.32
    max_z=22.88
    n_poses=10
```

### Running with gold
A gold executable (of name 'gold_auto') should be placed in directory: /tools/bin <br>
The config.txt file should contain: 
```
    receptor=receptor.mol2
    radius=5
    center_x=10
    center_y=10
    center_z=10
```

### Running with iGemDock
An iGemDock executable (of name 'mod_ga') should be placed in directory: /tools/bin <br>
The config.txt file should contain: 
```
    receptor=1x1r.pdb
    exhaustiveness=10
```

### Running with idock
An idock executable (of name 'idock') should be placed in directory: /tools/bin <br>
The config.txt file should contain: 
```
    receptor=./receptor.pdb 
    center_x=10
    center_y=10
    center_z=10
    size_x=10
    size_y=10
    size_z=10
```
 
### Running with GalaxyDock3
A GalaxyDock3 executable (of name 'GalaxyDock3') should be placed in directory: /tools/bin <br>
The config.txt file should contain: 
    receptor=./receptor.pdb 
    grid_box_cntr=15 12 0
    grid_n_elem=61 61 61
    grid_width=0.375
    max_trial=10
    
### Running with autodock_gpu
A autodock_cpu executable (of name 'autodock_gpu') should be placed in directory: /tools/bin <br>
The config.txt file should contain: 
```
    receptor=./protein.maps.fld # The prepared receptor file
```

### Running with autodock_cpu
A autodock_cpu executable (of name 'autodock_cpu') should be placed in directory: /tools/bin <br>
The config.txt file should contain: 
```
    receptor=./protein.maps.fld # The prepared receptor file
```


    


