"""Read-only source checks and isolated projection compatibility."""
from pathlib import Path
import json
import sys
import openpyxl

ROOT = Path(__file__).resolve().parents[1] / 'space-battleship'
sys.path.insert(0, str(ROOT / 'tools'))
from import_workbook import read_rows, convert_sheet
from config_workbooks import incremental_import

rows = read_rows(openpyxl.load_workbook(ROOT / 'config_excel/jewel.xlsx', data_only=True, read_only=True)['jewel'])
gems = convert_sheet('jewel', rows)
assert len(gems) == 10 and gems['7']['func'] == rows[6]['func']
assert gems['1']['para_3'] == 1000 and gems['1']['maxLevel'] == 10
try:
    convert_sheet('jewel', rows + [rows[0]])
    raise AssertionError('duplicate id accepted')
except ValueError:
    pass
projected = json.loads((ROOT / 'data/game_data.json').read_text(encoding='utf-8'))
assert projected['jewel'] == gems
config = convert_sheet('config', read_rows(openpyxl.load_workbook(ROOT / 'config_excel/config.xlsx', data_only=True, read_only=True)['config']))
assert projected['config'] == config
assert config['jewelCompose'] == '1|1000'
# run.py already isolates source/target and user dirs. Simulate a pre-jewel projection.
target = ROOT / '.runtime/jewel-import.json'
projected.pop('jewel')
target.write_text(json.dumps(projected, ensure_ascii=False), encoding='utf-8')
result = incremental_import(ROOT / 'config_excel', target)
assert result['ok']
assert json.loads(target.read_text(encoding='utf-8'))['jewel'] == gems
assert incremental_import(ROOT / 'config_excel', target)['changed'] == []
print('Jewel import: source preservation, duplicate validation, discovery and unchanged cache passed')
