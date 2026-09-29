"""Planet identity and building rules use the existing workbook projection."""
from pathlib import Path
import copy
import sys
import tempfile
import json
import openpyxl
root=Path(__file__).resolve().parents[1]/'space-battleship'
sys.path.insert(0,str(root/'tools'))
from import_workbook import convert_sheet,read_rows,validate_planets
from config_workbooks import incremental_import

data=json.loads((root/'data/game_data.json').read_text(encoding='utf-8'))
for table in ('planet','planet_build','planet_buff'):
    book=openpyxl.load_workbook(root/f'config_excel/{table}.xlsx',data_only=True)
    projected=convert_sheet(table,read_rows(book[table]))
    assert data[table]==projected,table
    assert all(isinstance(c.value,str) and c.value for c in book[table][2]),'column descriptions'
assert all(type(row['id']) is int for row in data['planet'].values())
assert all(type(row['id']) is int for row in data['planet_buff'].values())
for key,value in [('planet_id',999),('condition','script'),('buff_type','unknown'),('value',float('inf')),('value',-1),('stack','unknown')]:
    bad=copy.deepcopy(data)
    bad['planet_buff']['1'][key]=value
    try:validate_planets(bad)
    except ValueError:pass
    else:raise AssertionError(('planet_buff',key))
assert not any('effectType' in row or 'effectValue' in row for row in data['planet'].values())
validate_planets(data)
for value in (0,-1,float('inf'),'5',True):
    bad=copy.deepcopy(data)
    bad['planet']['1']['minTime']=value
    try:validate_planets(bad)
    except ValueError:pass
    else:raise AssertionError(('minTime',value))
for value in (0,-1,1.5,float('inf'),len(data['levels'])+1,'5',True):
    bad=copy.deepcopy(data)
    bad['planet']['1']['reforgeStartLevel']=value
    try:validate_planets(bad)
    except ValueError:pass
    else:raise AssertionError(('reforgeStartLevel',value))
for planet_id in data['planet']:
    sharing=[r for r in data['planet_buff'].values() if str(r['planet_id'])==planet_id and r['buff_type']=='crew_exp_share']
    assert len(sharing)==1 and sharing[0]['source']=='conquer' and sharing[0]['condition']=='conquered'
bad=copy.deepcopy(data)
sharing_id=next(k for k,r in bad['planet_buff'].items() if r['buff_type']=='crew_exp_share')
bad['planet_buff'][sharing_id]['value']=2
try:validate_planets(bad)
except ValueError:pass
else:raise AssertionError('sharing is a boolean capability, not a second XP multiplier')
for key,value in [('planet_rule','script'),('min_planet',0),('build_explore',0),('extra_crew',-1),('config1',float('inf'))]:
    bad=copy.deepcopy(data)
    bad['planet_build']['station'][key]=value
    try:validate_planets(bad)
    except ValueError:pass
    else:raise AssertionError(key)
for rule,value in [('all',''),('only','3,6,9'),('exclude','1,2'),('tag','ancient')]:
    edited=copy.deepcopy(data)
    edited['planet_build']['shipyard'].update(min_planet=10,planet_rule=rule,planet_value=value)
    validate_planets(edited)
with tempfile.TemporaryDirectory(dir=root/'.runtime') as folder:
    target=Path(folder)/'projection.json'
    target.write_text(json.dumps(data,ensure_ascii=False),encoding='utf-8')
    result=incremental_import(root/'config_excel',target)
    assert 'planet_build' in result['parsed']
    assert 'planet_buff' in result['parsed']
    loaded=json.loads(target.read_text(encoding='utf-8'))
    assert loaded['planet_build']==data['planet_build']
    assert loaded['planet_buff']==data['planet_buff']
print('Planet configuration: projection, four rules, rejection and incremental import passed')
