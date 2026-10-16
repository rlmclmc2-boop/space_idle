import copy
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'space-battleship/tools'))
from import_workbook import validate_projection

data = json.loads((root / 'space-battleship/data/game_data.json').read_text(encoding='utf-8'))
validate_projection(data)
for first, second in (('271022','271023'),('271026','271027')):
    assert data['enemies'][first]['intelName'] != data['enemies'][second]['intelName'], (first,second)
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
altered = copy.deepcopy(data)
altered['enemies']['271024']['intelVisualRef'] = 'shielded'
try:
    validate_projection(altered)
except ValueError:
    pass
else:
    raise AssertionError('Visual reference not linked to combat archetype')
legacy = (root / 'space-battleship/scripts/game.gd').read_text(encoding='utf-8')
native = (root / 'space-battleship/addons/native_battle/src/combat_execution_kernel.h').read_text(encoding='utf-8')
for name, native_pattern in (
    ('REACTIVE_STACK_LIMIT', r'std::min\((\d+), a->reactive_stacks \+ 1\)'),
    ('REACTIVE_STACK_REDUCTION', r'reactive_multiplier = 1\.0 - ([\d.]+) \* reactive_stacks'),
    ('REACTIVE_RESET_SECONDS', r'at <= a->reactive_volley_at \+ ([\d.]+)'),
    ('REACTIVE_VOLLEY_GAP', r'at > a->reactive_volley_at \+ ([\d.]+)'),
):
    authored = re.search(rf'const {name} := ([\d.]+)', legacy)
    compiled = re.search(native_pattern, native)
    assert authored and compiled and float(authored.group(1)) == float(compiled.group(1)), name
print('Enemy intel import: full data valid; 4 mechanism mismatches and visual mismatch rejected; native reactive constants match')
