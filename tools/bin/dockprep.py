import chimera
from DockPrep import prep
from chimera import runCommand
from WriteMol2 import writeMol2
from chimera import runCommand, openModels, MSMSModel
from WriteDMS import writeDMS

models = chimera.openModels.list(modelTypes=[chimera.Molecule])
prep(models)
writeMol2(models, "rec_charged.mol2")
runCommand("del @h=")
runCommand("write format pdb 0 rec_noH.pdb")

runCommand("surf")
surf = openModels.list(modelTypes=[MSMSModel])[0]

writeDMS(surf, "rec.ms")
