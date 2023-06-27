import os
from typing import Dict, Tuple
import logging

logger = logging.getLogger(__name__)

def read_config_line(line: str) -> Tuple[str, str]:
    key, sep, value = line.strip().partition("=")
    return key.strip(), value.strip()

def load_config(config_path: str) -> Dict:
    with open(config_path) as fd:
        result = dict(read_config_line(line) for line in fd)

    for item in result:
        if '#' in result[item]:
            result[item] = result[item].split('#')[0]

    return result

def format_ligand(ligand_path: str, file_format: str) -> str:
    """Converts a ligand file to a different file format using the Open Babel tool.

        Args:
            ligand_ (str): The path to the input ligand file.
            new_format (str): The desired output format for the ligand file.
    
        Returns:
            None
    
        Raises:
            Exception: If the input file does not exist, or if the Open Babel tool is not installed.
    
        Examples:
            To convert a ligand file from mol2 format to pdbqt format:
            >>> convert_ligand_format('./ligands/ligand1.mol2', 'pdbqt')
    """
    ligand_path_as_list = ligand_path.split('.')
    current_format = ligand_path_as_list[-1]
    if current_format != file_format: 
        logger.info(f'Converting ligand file format to {file_format} using obabel.')
        ligand_path_as_list[-1] = file_format
        result = ''.join(ligand_path_as_list)
        os.system('obabel {} -O {}'.format(ligand_path, result))
        return result
        
    return ligand_path
