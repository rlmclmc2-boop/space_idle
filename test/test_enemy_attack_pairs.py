"""Validate paired attacks, preserved published templates and source authority."""
import copy,io,json,pathlib,subprocess,sys
import openpyxl
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'space-battleship/tools'))
from import_workbook import validate_projection, validate_attack_pairs
from config_workbooks import read_changed_file
data=json.loads((ROOT/'space-battleship/data/game_data.json').read_text())
validate_projection(data)
metadata={'pair_id','attack_variant','attack_type','paired_group_id'}
pairs={}
for row in data['battle_design'].values():
    if row.get('pair_id'):pairs.setdefault(row['pair_id'],[]).append(row)
assert pairs, 'No authored paired attacks to validate'
for pair,rows in pairs.items():
    assert len(rows)==2, pair
    a,b=sorted(rows,key=lambda r:r['attack_type'])
    assert (a['attack_type'],b['attack_type'])==(1,2)
    assert (a['paired_group_id'],b['paired_group_id'])==(b['group_id'],a['group_id'])
    left=data['groups'][str(a['group_id'])]['slots'];right=data['groups'][str(b['group_id'])]['slots']
    assert len(left)==len(right)
    assert [v is None for v in left]==[v is None for v in right]
for name,section in [('mon','enemies'),('monGroup','groups'),('equipment','equipment'),('battle_design','battle_design')]:
    path=ROOT/f'space-battleship/config_excel/{name}.xlsx'
    assert read_changed_file(path,name,path.read_bytes())==data[section]
# Old unpaired metadata remains supported.
legacy=copy.deepcopy(data)
for row in legacy['battle_design'].values():
    for f in metadata:row.pop(f,None)
validate_projection(legacy)
def rejects(change):
    v=copy.deepcopy(data);change(v)
    try:validate_projection(v)
    except (ValueError,TypeError):return
    raise AssertionError('malformed pair accepted')
key='normal_laser_physical_attack'
for field,value in [('attack_type',1),('attack_type',True),('attack_variant','unknown'),('paired_group_id',999999),('pair_id','orphan'),('counter','cannon')]:
    rejects(lambda v,f=field,z=value:v['battle_design'][key].__setitem__(f,z))
rejects(lambda v:v['battle_design'][key].pop('paired_group_id'))
rejects(lambda v:v['enemies']['2001'].__setitem__('armourType',1))
rejects(lambda v:v['enemies']['2001'].__setitem__('equipment',[{'name':'laser_mon'}]))
rejects(lambda v:v['equipment']['laser_mon'][0].__setitem__('dmgtype',True))
rejects(lambda v:v['groups']['2001'].__setitem__('slots',v['groups']['2001']['slots'][:10]))
rejects(lambda v:v['battle_design'].pop(key))
# Runtime resolves Lv1 regardless of workbook row order, including fallback.
def reordered(v, invalid=False, fallback=False):
    name = 'laser' if fallback else 'laser_mon'
    rows = v['equipment'][name]
    first = copy.deepcopy(rows[0]);first['level']=2;first['dmgtype']=1
    rows.insert(0, first)
    if fallback:
        v['equipment']['laser_mon'][0]['dmgtype']=None
        v['enemy_weapon_base']['laser'].pop('dmgtype',None)
    if invalid:rows[1]['dmgtype']=2
for fallback in [False,True]:
    valid=copy.deepcopy(data);reordered(valid,fallback=fallback)
    validate = validate_attack_pairs if fallback else validate_projection
    validate(valid)
    invalid=copy.deepcopy(valid);invalid['equipment']['laser' if fallback else 'laser_mon'][1]['dmgtype']=2
    try:validate(invalid)
    except ValueError:pass
    else:raise AssertionError('Lv2 row concealed invalid Lv1 attack type')
print('Attack pairs: current authored pairs, four source projections, legacy metadata and malformed/Lv1-order cases passed')
