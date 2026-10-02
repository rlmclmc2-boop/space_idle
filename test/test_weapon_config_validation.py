"""Reject incomplete migrated weapon tables through the official Excel exporter."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import shutil
import openpyxl

game = Path.cwd()
if 'work' not in game.parts:
    raise SystemExit('Run in an isolated test/work project')
sys.path.insert(0, str(game / 'tools'))
from config_workbooks import incremental_import
from import_workbook import validate_projection

base = json.loads((game / 'data/game_data.json').read_text(encoding='utf8'))
results = []
legacy = copy.deepcopy(base)
for section in ('weapon_motion', 'enemy_weapon_base'):
    del legacy[section]
validate_projection(legacy)
results.append({'case': 'legacy missing sections', 'status': 'accepted'})
nullable = copy.deepcopy(base)
for key in ('laser', 'cannon'):
    nullable['enemy_weapon_base'][key]['para2'] = None
    nullable['enemy_weapon_base'][key]['para3'] = None
nullable['enemy_weapon_base']['missile']['para3'] = None
nullable['enemy_weapon_base']['longLaser']['para3'] = None
nullable['enemy_weapon_base']['longLaser']['para1'] = 0 # Immediate maximum beam multiplier is supported.
validate_projection(nullable)
results.append({'case': 'unused parameters and optional beam charge null', 'status': 'accepted'})
for key in ('laser', 'missile', 'cannon', 'longLaser'):
    for field in (('para1', 'para2') if key in ('missile', 'longLaser') else ('para1',)):
        for missing in (False, True):
            bad = copy.deepcopy(base)
            row = bad['enemy_weapon_base'][key]
            if missing:
                del row[field]
            else:
                row[field] = None
            try:
                validate_projection(bad)
            except ValueError as error:
                assert f'{key}.{field}' in str(error)
                results.append({'case': f'{key}.{field} ' + ('missing' if missing else 'null'), 'error': str(error)})
            else:
                raise AssertionError(f'{key}.{field} accepted')

for case in ('empty weapon_motion', 'empty enemy_weapon_base', 'null missile speed', 'deleted missile speed column'):
    with tempfile.TemporaryDirectory(dir=game.parent, prefix='weapon-validation-') as directory:
        area = Path(directory)
        config = area / 'config_excel'
        shutil.copytree(game / 'config_excel', config, ignore=shutil.ignore_patterns('.import_state.json'))
        target = area / 'game_data.json'
        target.write_text(json.dumps(base), encoding='utf8')
        section = 'weapon_motion' if case == 'empty weapon_motion' else 'enemy_weapon_base'
        path = config / (section + '.xlsx')
        workbook = openpyxl.load_workbook(path)
        sheet = workbook[section]
        if case.startswith('empty'):
            sheet.delete_rows(4, sheet.max_row)
        else:
            headers = {cell.value: cell.column for cell in sheet[1]}
            if case.startswith('deleted'):
                sheet.delete_cols(headers['para2'])
            else:
                row = next(r for r in range(4, sheet.max_row + 1) if sheet.cell(r, headers['id']).value == 'missile')
                sheet.cell(row, headers['para2']).value = None
        workbook.save(path)
        before = target.read_bytes()
        try:
            incremental_import(config, target)
        except ValueError as error:
            assert section in str(error)
            assert target.read_bytes() == before, 'Invalid import changed consumer JSON'
            results.append({'case': case, 'error': str(error), 'projection_unchanged': True})
        else:
            raise AssertionError(case + ' accepted')
(game / 'weapon-validation-results.json').write_text(json.dumps(results, indent=2), encoding='utf8')
print(f'WEAPON TABLE VALIDATION: {len(results)} cases passed; 4 actual invalid Excel imports rejected; projection unchanged')
