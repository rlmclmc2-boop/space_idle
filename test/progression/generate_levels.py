"""Versioned Excel-source progression candidates. Writes existing fields, imports formally."""
from pathlib import Path
import argparse, json, math, sys, subprocess
import openpyxl
ROOT=Path(__file__).resolve().parents[2]; SRC=ROOT/'space-battleship'; CFG=SRC/'config_excel'
sys.path.insert(0,str(SRC/'tools'))
from config_workbooks import incremental_import
from excel_cache import recache_level
p=argparse.ArgumentParser();p.add_argument('--version',default='early-v3');a=p.parse_args()
data=json.loads((SRC/'data/game_data.json').read_text())
books={n:openpyxl.load_workbook(CFG/(n+'.xlsx')) for n in ['level','mon','monGroup']}
sheets={n:b.active for n,b in books.items()};headers={n:{c.value:c.column for c in s[1] if c.value is not None} for n,s in sheets.items()}
def replace(n,key,row):
 s=sheets[n]; h=headers[n]; col=h['id']; ri=next((r for r in range(4,s.max_row+1) if s.cell(r,col).value==key),s.max_row+1)
 for k,v in row.items():
  if k in h:s.cell(ri,h[k],v)
def source_row(n,key):
 s=sheets[n];h=headers[n];ri=next(r for r in range(4,s.max_row+1) if s.cell(r,h['id']).value==key)
 return {k:s.cell(ri,c).value for k,c in h.items()}
themes=['laser','missile','cannon','neutral1','neutral2','longLaser','laser','missile','cannon','neutral3']
ratios=[1,1.5,2,3,4.5]+[1.2**(20+10*i) for i in range(5)]
resources=[1.4**i for i in range(5)]+[12*1.2**(10*i) for i in range(5)]
manifest=[]
for stage,theme in enumerate(themes,1):
 tiers=['normal']*4+['elite'] if stage<=5 else ['normal']*5+['elite']*3+['boss']
 groups=[]
 for node,tier in enumerate(tiers,1):
  variant='physical_attack' if (stage+node)%2==0 else 'energy_attack'
  if tier=='boss':key='boss_energy' if theme in ['missile','cannon'] else 'boss_physical'
  else:key=tier+'_'+theme
  # Neutral elites carry numeric suffix; their source IDs exist.
  gid=int(data['battle_design'][key]['group_id'])+(1000 if variant=='physical_attack' else 0)
  original=data['groups'][str(gid)];newgid=30000+stage*10+node;slots=[]
  for slot,eid in enumerate(original['slots']):
   if eid is None:slots.append('null');continue
   newid=40000+stage*1000+node*20+slot;row=source_row('mon',eid);row['id']=newid
   row['des']=f'校准{a.version}-关{stage}-层{node}-'+str(row['des'])
   row['health']=max(1,round(float(row['health'])*.1454));row['shield']=max(0,round(float(row['shield'] or 0)*.1454))
   loot=(8 if tier=='normal' else 20) if stage<=5 else max(1,round((30 if tier=='normal' else 60 if tier=='elite' else 120)/len([e for e in original['slots'] if e is not None])))
   row['res']='{1,%d,1}'%loot
   row['dmgMultiple']=float(row['dmgMultiple'])*.1454
   # Normalize attacks with HP for original level10 -> early-game scaling; keep actual damage types.
   replace('mon',newid,row);slots.append(str(newid))
  replace('monGroup',newgid,{'id':newgid,'des':f'校准{a.version}-关{stage}-层{node}-{tier}-{theme}-{variant}','mon':'{'+','.join(slots)+'}'})
  groups.append((newgid,node*.9/len(tiers)))
  manifest.append({'stage':stage,'node':node,'tier':tier,'theme':theme,'source_group':gid,'group':newgid,'variant':variant,'suggested':stage in [4,5]})
 row=source_row('level',stage);row.update(length=4000 if stage<=5 else 1000,monGroup='{'+','.join(f'{g}|{pos:.6f}' for g,pos in groups)+'}',atkRatio=ratios[stage-1],lifeRatio=ratios[stage-1],resRatio=resources[stage-1],planetExpRatio=0)
 replace('level',stage,row)
for n,b in books.items():b.save(CFG/(n+'.xlsx'))
recache_level(CFG/"level.xlsx",sheets["level"],subprocess.check_output(["git","show","04a5a307bcef9325efa9026e1ca94affa577e10d:space-battleship/config_excel/level.xlsx"],cwd=ROOT))
result=incremental_import(CFG,SRC/'data/game_data.json')
evidence=ROOT/'test/progression/candidates';evidence.mkdir(exist_ok=True)
(evidence/(a.version+'.json')).write_text(json.dumps({'version':a.version,'stage_range':[1,10],'reason':'Initial teaching roster and economy candidate after 49-second stage1 / 398-second teaching baseline; not accepted balance. Stage4/5 themes are suggestions. Retain 40 original templates.','health_normalization':.1454,'ratios':ratios,'waves':manifest,'import':result},indent=2,ensure_ascii=False))
print(json.dumps(result))
