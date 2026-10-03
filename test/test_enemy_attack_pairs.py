"""Validate paired attacks, preserved published templates and source authority."""
import copy,io,json,pathlib,subprocess,sys
import openpyxl
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'space-battleship/tools'))
from import_workbook import validate_projection, validate_attack_pairs
from config_workbooks import read_changed_file
BASE='b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f'
data=json.loads((ROOT/'space-battleship/data/game_data.json').read_text())
old=json.loads(subprocess.check_output(['git','show',f'{BASE}:space-battleship/data/game_data.json'],cwd=ROOT))
validate_projection(data);assert len(data['battle_design'])==40
metadata={'pair_id','attack_variant','attack_type','paired_group_id'}
for key,record in old['battle_design'].items():
    a=data['battle_design'][key];b=data['battle_design'][key+'_physical_attack']
    assert {k:v for k,v in a.items() if k not in metadata}==record
    assert a['pair_id']==b['pair_id']==key
    assert (a['attack_type'],b['attack_type'])==(1,2)
    assert (a['paired_group_id'],b['paired_group_id'])==(b['group_id'],a['group_id'])
    assert data['groups'][str(record['group_id'])]==old['groups'][str(record['group_id'])]
    original=data['groups'][str(a['group_id'])]['slots'];variant=data['groups'][str(b['group_id'])]['slots']
    assert variant==[None if e is None else e+1000 for e in original]
    for e in original:
        if e is None:continue
        x=data['enemies'][str(e)];y=data['enemies'][str(e+1000)]
        assert x==old['enemies'][str(e)]
        assert {k:v for k,v in x.items() if k not in {'id','des','equipment'}}=={k:v for k,v in y.items() if k not in {'id','des','equipment'}}
        assert x['equipment']==[{'name':'laser_mon'}] and y['equipment']==[{'name':'cannon-mon'}]
for name,section in [('mon','enemies'),('monGroup','groups'),('equipment','equipment'),('battle_design','battle_design')]:
    path=ROOT/f'space-battleship/config_excel/{name}.xlsx'
    assert read_changed_file(path,name,path.read_bytes())==data[section]
for key,rows in old['equipment'].items():
    assert [{k:v for k,v in row.items() if k!='des'} for row in rows]==[{k:v for k,v in row.items() if k!='des'} for row in data['equipment'][key]]
for field in ['levels','planet','galaxy','galaxy_config','enemy_weapon_base','weapon_motion','enhance_config']:
    assert data[field]==old[field],field
for name in ['mon','monGroup','equipment']:
    raw=subprocess.check_output(['git','show',f'{BASE}:space-battleship/config_excel/{name}.xlsx'],cwd=ROOT)
    a=openpyxl.load_workbook(io.BytesIO(raw)).active;b=openpyxl.load_workbook(ROOT/f'space-battleship/config_excel/{name}.xlsx').active
    for row in a:
        for cell in row:
            if name=='equipment' and cell.coordinate in {'B9','B11'}:continue
            assert cell.value==b[cell.coordinate].value,(name,cell.coordinate)
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
print('Attack pairs: 40 templates/20 pairs,60 copied enemies,4 Excel projections,old IDs/levels/defence/growth,legacy metadata,14 malformed cases and2 valid Lv1 reorder cases passed')
