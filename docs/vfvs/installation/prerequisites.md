# External Packages

## External Docking Programs

The external docking programs which are currently supported by VirtualFlow are : AutoDock Vina, Vina-Carb, VinaXB, Smina, QuickVina 2, QuickVina-W, and ADFR.&#x20;

For all of these docking programs, except for ADFR, the executable binary programs (for x86 the architecture) are included in the VFVS package, and thus don't need to to be installed (when x86 compatible compute nodes are used, which is normally the case).

{% hint style="info" %}
The pre-compiled executables are the ones which are provided by the original creators of these programs. This means that the more efficient binaries might be obtained when recompiling them from the source code with settings optimized for the  precise architecture which will be used.
{% endhint %}

When self-compiled binaries should be used by VFVS, the pre-compiled binaries in the `tools/bin` folder need to be replaced by the new binaries.



## ADFR (Optional)

If the docking program ADFR (AutoDockFR) is to be used by VFVS, it needs to be installed by the user. ADFR can be found here: [http://adfr.scripps.edu/AutoDockFR/adfr.html](http://adfr.scripps.edu/AutoDockFR/adfr.html)

What is important is that the folder where the `adfr` executable  is located is included in the PATH variable after installation, so that VirtualFlow can execute the ADFR program.

## PLANTS and SPORES

VirtualFlow Ants, the module of VirtualFlow which uses PLANTS as the docking program, requires the external programs PLANTS are SPORES. PLANTS can be obtained here:&#x20;

{% embed url="https://uni-tuebingen.de/fakultaeten/mathematisch-naturwissenschaftliche-fakultaet/fachbereiche/pharmazie-und-biochemie/teilbereich-pharmazie-pharmazeutisches-institut/pharmazeutische-chemie/pd-dr-t-exner/research/plants/" %}

The PLANTS binary has to be placed in the folder tools/bin/ and has to be named `plants`.

SPORES can be obtained here:&#x20;

{% embed url="https://uni-tuebingen.de/fakultaeten/mathematisch-naturwissenschaftliche-fakultaet/fachbereiche/pharmazie-und-biochemie/teilbereich-pharmazie-pharmazeutisches-institut/pharmazeutische-chemie/pd-dr-t-exner/research/spores/" %}

The SPORES binary has to be placed in the folder tools/bin/ and has to be named `spores`.

