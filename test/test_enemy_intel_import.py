import copy
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'space-battleship/tools'))
from import_workbook import validate_projection

data = json.loads((root / 'space-battleship/data/game_data.json').read_text(encoding='utf-8'))
validate_projection(data)
for enemy_id, replacement in (
    ('271024', []),
    ('271024', ['shieldRecovery']),
    ('271028', []),
    ('271001', ['reactiveReduction']),
):
    altered = copy.deepcopy(data)
    altered['enemies'][enemy_id]['intelMechanics'] = replacement
    try:
        validate_projection(altered)
    except ValueError:
        continue
    raise AssertionError(f'mon {enemy_id}: invalid mechanism list accepted: {replacement}')
print('Enemy intel import: full data valid; 4 mismatched mechanisms rejected')
