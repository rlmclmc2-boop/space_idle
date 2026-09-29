import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
from import_workbook import convert_sheet, read_rows, validate_projection
import openpyxl

data = json.loads((ROOT / 'data/game_data.json').read_text(encoding='utf-8'))
assert 'charge' not in data
assert not (ROOT / 'config_excel/charge.xlsx').exists()
book = openpyxl.load_workbook(ROOT / 'config_excel/config.xlsx', data_only=True, read_only=True)
try:
    source = convert_sheet('config', read_rows(book['config']))
finally:
    book.close()
for key in ('reactorEnergyBase','reactorEnergyGrowth','reactorUpgradeBase','reactorUpgradeGrowth','reactorBoostExponent','reactorUraniumId','reactorModules','reactorInitialLevel','reactorPercentScale','reactorAllocationStep','scientistCost'):
    assert source[key] == data['config'][key], key
book = openpyxl.load_workbook(ROOT / 'config_excel/unlock.xlsx', data_only=True, read_only=True)
try:
    unlocks = convert_sheet('unlock',read_rows(book['unlock']))
finally:
    book.close()
assert unlocks['reactor'] == data['unlock']['reactor']
assert source['reactorModules'].split(',') == ['weapons','defence','smelting','condensation']
assert unlocks['reactor_module/condensation'] == data['unlock']['reactor_module/condensation']
assert unlocks['reactor_module/condensation']['level'] == 15
assert unlocks['reactor_module/condensation']['mode'] == 'cleared'
assert all(row['type'] != 'charge' for row in unlocks.values())
validate_projection(data)
print('reactor config valid')
