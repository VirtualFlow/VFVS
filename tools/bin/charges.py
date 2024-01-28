from chimera import openModels, Molecule
from AddCharge import estimateFormalCharge

mol = openModels.list(modelTypes=[Molecule])[0]

fc = estimateFormalCharge(mol.atoms)
atomicSum = sum([a.element.number for a in mol.atoms]) 

if (atomicSum + fc) % 2 == 0:
	print(fc)		# charge estimate
else:
	print(fc)		# bad charge estimate
