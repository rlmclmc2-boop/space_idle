"""Apply narrowly recorded, formally probed pair compensation via source Excel."""
from pathlib import Path
import io,json,subprocess,sys,openpyxl
ROOT=Path(__file__).resolve().parents[2];CFG=ROOT/'space-battleship/config_excel'
BASE='04a5a307bcef9325efa9026e1ca94affa577e10d'
from source_lock import acquire
_source_lock=acquire(ROOT)
data=json.loads(subprocess.check_output(['git','show',BASE+':space-battleship/data/game_data.json'],cwd=ROOT))
original=openpyxl.load_workbook(io.BytesIO(subprocess.check_output(['git','show',BASE+':space-battleship/config_excel/mon.xlsx'],cwd=ROOT))).active
headers={c.value:c.column for c in original[1] if c.value}
old={int(original.cell(r,headers['id']).value):r for r in range(4,original.max_row+1)}
w=openpyxl.load_workbook(CFG/'mon.xlsx');s=w.active
indices={int(s.cell(r,headers['id']).value):r for r in range(4,s.max_row+1)}
factors={'elite_laser':1.3,'elite_missile':1.3,'elite_cannon':1.4,'elite_longLaser':1.4,'boss_physical':1.5,'boss_energy':1.6,'ultimate_physical':1.9,'ultimate_energy':1.8}
factors.update({'elite_neutral'+str(i):1.3 for i in range(1,5)})
allowed={};changes=[]
for key,factor in factors.items():
 record=data['battle_design'][key+'_physical_attack']
 for eid in set(e for e in data['groups'][str(record['group_id'])]['slots'] if e):
  baseline=original.cell(old[eid],headers['dmgMultiple']).value;value=round(float(baseline)*factor,9)
  s.cell(indices[eid],headers['dmgMultiple'],value)
  allowed.setdefault(str(eid),{})['dmgMultiple']=value
  changes.append({'id':eid,'group':record['group_id'],'field':'dmgMultiple','baseline':baseline,'new':value,'factor':factor})
# Preserve both original/physical identities and matching defence; shorten69s to60s.
for eid in [1089,2089]:
 baseline=original.cell(old[eid],headers['health']).value;value=777728
 s.cell(indices[eid],headers['health'],value);allowed.setdefault(str(eid),{})['health']=value
 changes.append({'id':eid,'field':'health','baseline':baseline,'new':value})
w.save(CFG/'mon.xlsx')
sys.path.insert(0,str(ROOT/'space-battleship/tools'))
from config_workbooks import incremental_import
result=incremental_import(CFG,ROOT/'space-battleship/data/game_data.json')
meta={'base':BASE,'scope':'All40 identities/formations/attack types preserved. Only recorded source enemy damage/HP fields vary. Generated level copies require regeneration and fresh regressions.','proof':'Native Presented+scene176 private critical matches: no adjacent-gate deviations. Additional physical-ultimate HP/damage private4 matches preserve+2loss/+3win60.083s. Normal all-weapons+3 formal guarantee pending.','allowed_source_cells':allowed,'changes':changes,'import':result}
(ROOT/'test/progression/candidates/enemy-pair-compensation-v1.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2));print(json.dumps(result))
