"""Versioned Excel-source progression candidates. Writes existing fields, imports formally."""
from pathlib import Path
import argparse, json, math, sys, subprocess
import openpyxl
ROOT=Path(__file__).resolve().parents[2]; SRC=ROOT/'space-battleship'; CFG=SRC/'config_excel'
sys.path.insert(0,str(SRC/'tools'))
from config_workbooks import incremental_import
from excel_cache import recache_level
p=argparse.ArgumentParser();p.add_argument('--version',default='progression-v4');p.add_argument('--through',type=int,default=20);p.add_argument('--late-income',type=float,default=.1);p.add_argument('--roster-through',type=int,default=20);p.add_argument('--smooth-income-floor',action='store_true');a=p.parse_args()
from source_lock import acquire
_source_lock=acquire(ROOT)
data=json.loads((SRC/'data/game_data.json').read_text())
books={n:openpyxl.load_workbook(CFG/(n+'.xlsx')) for n in ['level','mon','monGroup']}
sheets={n:b.active for n,b in books.items()};headers={n:{c.value:c.column for c in s[1] if c.value is not None} for n,s in sheets.items()}
indices={n:{s.cell(r,headers[n]["id"]).value:r for r in range(4,s.max_row+1)} for n,s in sheets.items()}
def replace(n,key,row):
 s=sheets[n]; h=headers[n]; ri=indices[n].get(key,s.max_row+1); indices[n][key]=ri
 for k,v in row.items():
  if k in h:s.cell(ri,h[k],v)
def source_row(n,key):
 s=sheets[n];h=headers[n];ri=indices[n][key]
 return {k:s.cell(ri,c).value for k,c in h.items()}
themes=['laser','missile','cannon','neutral1','neutral2','longLaser','laser','missile','cannon','neutral3']
themes += ['neutral1','missile','neutral2','laser','cannon','neutral4','longLaser','neutral3','missile','laser']
# Later levels normally mix themes; beam has no fixed tutorial slot after10.
cycle=['neutral2','cannon','neutral4','missile','laser','neutral1','longLaser','neutral3','cannon','neutral4','missile','neutral2','laser','neutral3','longLaser','neutral1']
while len(themes)<a.roster_through:themes.extend(cycle)
ratios=[1,1.5,2,3,4.5,1.2**15]+[1.2**(30+10*i) for i in range(4)]
ratios += [1.2**(60+13*i) for i in range(1,11)]
resources=[1.4**i for i in range(5)]+[12*1.2**(10*i) for i in range(5)]
resources += [resources[9]*1.2**(13*i)*a.late_income for i in range(1,11)]
if a.smooth_income_floor:
 for index in range(10,20):resources[index]=max(resources[index],resources[index-1]*1.4)
if a.through>20:
 # Provisional future budget. Every value is subject to segment regression.
 ratios += [1.2**(190+8*i) for i in range(1,11)]
 resources += [resources[19]*1.2**(8*i)*4 for i in range(1,11)]
 first_steps=[8,16,32,48,68]
 first_income=[0,0,4,4,10]
 ratios += [ratios[29]*1.2**i for i in first_steps]
 resources += [resources[29]*1.2**i for i in first_income]
 for planet_cycle in range(5):
  base_ratio=ratios[-1];base_income=resources[-1]
  ratios += [base_ratio*1.2**i for i in [6,12,18,30,50]]
  resources += [base_income*1.2**i for i in [4,8,12,20,32]]
manifest=[]
for stage,theme in enumerate(themes[:max(a.through,a.roster_through)],1):
 tiers=['normal']*4+['elite'] if stage<=5 else ['normal']*5+['elite']*3+['boss']
 if stage>=20 and ((stage<=70 and stage%5==0) or (stage>70 and stage%10==0)):tiers=['elite']*5+['boss']*3+['ultimate']
 groups=[]
 for node,tier in enumerate(tiers,1):
  variant='physical_attack' if (stage+node)%2==0 else 'energy_attack'
  if tier in ['boss','ultimate']:key=tier+('_energy' if theme in ['missile','cannon'] else '_physical')
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
 row=source_row('level',stage)
 row.update(length=4000 if stage<=5 else 1000,monGroup='{'+','.join(f'{g}|{pos:.6f}' for g,pos in groups)+'}')
 if stage<=a.through:
  row.update(atkRatio=ratios[stage-1],lifeRatio=ratios[stage-1],resRatio=resources[stage-1])
  row['planetExpRatio']=0 if stage<30 else 1.2**((stage-30)/5)
 # Uncalibrated future numeric cells/formulas retain their identity, not old cached values.
 replace('level',stage,row)
for n,b in books.items():b.save(CFG/(n+'.xlsx'))
recache_level(CFG/"level.xlsx",sheets["level"],subprocess.check_output(["git","show","04a5a307bcef9325efa9026e1ca94affa577e10d:space-battleship/config_excel/level.xlsx"],cwd=ROOT))
result=incremental_import(CFG,SRC/'data/game_data.json')
evidence=ROOT/'test/progression/candidates';evidence.mkdir(exist_ok=True)
(evidence/(a.version+'.json')).write_text(json.dumps({'version':a.version,'stage_range':[1,a.through],'roster_range':[1,max(a.through,a.roster_through)],'reason':'Segmented candidate; v4 diagnostic cleared20 at4.79h, far below12–18h. Late income coefficient is explicit and must be tested from a fresh profile; stage4/5 remain suggestions. Original40 templates retained; downstream Excel formula dependencies are recalculated and unaccepted.','health_normalization':.1454,'ratios':ratios,'resource_ratios':resources,'late_income_coefficient':a.late_income,'smooth_income_floor':a.smooth_income_floor,'affected':'Generated numeric range plus later formula dependencies. Future candidate is provisional until segmented and single-version full fresh tests.','waves':manifest,'import':result},indent=2,ensure_ascii=False))
print(json.dumps(result))
