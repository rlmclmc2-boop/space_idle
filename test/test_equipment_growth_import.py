"""Run via run.py; only isolated workbook/projection data is read."""
import copy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
from import_workbook import convert_sheet, read_rows, validate_projection
import openpyxl

book = openpyxl.load_workbook(ROOT / 'config_excel/equipment.xlsx', data_only=True)
rows = read_rows(book['equipment'])
equipment = convert_sheet('equipment', rows)
assert len(equipment) == 9 and all(len(items) == 1 for items in equipment.values())
assert equipment['armour'][0]['para2'] == 0.2
assert equipment['shield'][0]['para4'] == 0.2
assert equipment['laser'][0]['dmgMulti'] == 0.2
assert convert_sheet('equipment', rows + [{'name': 'laser', 'level': 900, 'dmg': 'invalid'}]) == equipment
data = json.loads((ROOT / 'data/game_data.json').read_text(encoding='utf-8'))
data['equipment'] = equipment
validate_projection(data)
assert 'maxEquipmentLevel' not in data['defaults']
extra = equipment['laser'][0]
extra.update(res_3=1, cost_3=100, cost_multi_3=0.1)
validate_projection(data)
broken = copy.deepcopy(data)
broken['equipment']['laser'][0]['cost_multi_3'] = -1
try:
    validate_projection(broken)
except ValueError:
    pass
else:
    raise AssertionError('Negative dynamic cost multiplier accepted')
print('Equipment import: 8 checks, 0 failures')
