"""Source-Excel system calibration; no player save edits."""
from pathlib import Path
import json,sys
import openpyxl
ROOT=Path(__file__).resolve().parents[2]; SRC=ROOT/'space-battleship';CFG=SRC/'config_excel'
sys.path.insert(0,str(SRC/'tools'))
from config_workbooks import incremental_import
from source_lock import acquire
_source_lock=acquire(ROOT)
changes=[]
def edit(name,key_column,targets):
 w=openpyxl.load_workbook(CFG/(name+'.xlsx'));s=w.active;h={c.value:c.column for c in s[1] if c.value is not None}
 for r in range(4,s.max_row+1):
  key=s.cell(r,h[key_column]).value
  if key not in targets:continue
  for field,value in targets[key].items():
   old=s.cell(r,h[field]).value;s.cell(r,h[field],value);changes.append({'sheet':name,'id':key,'field':field,'old':old,'new':value})
 w.save(CFG/(name+'.xlsx'))
edit('config','name',{'reactorEnergyGrowth':{'para_1':1.06},'hightechCostGrowthLevel':{'para_1':50}})
edit('planet','id',{1:{'baseTime':60,'minTime':60}})
# First preparation: 60 trips (~1h), then 180 trips (~3h). Later planets retain old prep pending decision.
w=openpyxl.load_workbook(CFG/'planet_build.xlsx');s=w.active;h={c.value:c.column for c in s[1] if c.value is not None}
if 'previous_id' not in h:
 col=s.max_column+1;h['previous_id']=col;s.cell(1,col,'previous_id');s.cell(2,col,'仅用于旧建筑存档ID迁移，不改变建造玩法');s.cell(3,col,'string')
ship_r=next(r for r in range(4,s.max_row+1) if s.cell(r,h['id']).value=='shipyard')
old={field:s.cell(ship_r,c).value for field,c in h.items()}
later=dict(old,id='shipyard_later',planet_rule='exclude',planet_value='1',previous_id='shipyard')
for field,value in {'planet_rule':'only','planet_value':'1','unlock_explore':60,'build_explore':180}.items():
 changes.append({'sheet':'planet_build','id':'shipyard','field':field,'old':old[field],'new':value});s.cell(ship_r,h[field],value)
row=next((r for r in range(4,s.max_row+1) if s.cell(r,h['id']).value=='shipyard_later'),s.max_row+1)
# Regeneration must preserve later original 150/10, not reuse already tuned first parameters.
later.update(unlock_explore=150,build_explore=10)
for field,value in later.items():s.cell(row,h[field],value)
for r in range(4,s.max_row+1):
 key=s.cell(r,h['id']).value
 if key=='station':
  s.cell(r,h['unlock_explore'],1);s.cell(r,h['build_explore'],1)
 if key in ['workshop','refinery']:
  s.cell(r,h['config1'],.01);s.cell(r,h['config2'],.4 if key=='workshop' else .35)
w.save(CFG/'planet_build.xlsx')
edit('unlock','name',{'feature/galaxy':{'level':60}})
edit('galaxy','key',{'galaxy_1':{'explore_work_total':30000,'upgrade_cost_lv2':360,'upgrade_cost_lv3':540,'upgrade_cost_lv4':720,'upgrade_cost_lv5':900}})
w=openpyxl.load_workbook(CFG/'planet_buff.xlsx');s=w.active;h={c.value:c.column for c in s[1] if c.value is not None}
for r in range(4,s.max_row+1):
 target=s.cell(r,h['target']).value;typ=s.cell(r,h['buff_type']).value;v=s.cell(r,h['value']).value
 if typ=='level_bonus' and target in ['equipment','hightech']:
  s.cell(r,h['des'],('装备' if target=='equipment' else 'AI工厂')+'效果等级 +'+str(v))
w.save(CFG/'planet_buff.xlsx')
result=incremental_import(CFG,SRC/'data/game_data.json')
(ROOT/'test/progression/candidates/systems-v1.json').write_text(json.dumps({'reason':'Bound reactor growth for long-run integer capacity and prevent late free power runaway; first-planet 1h preparation +3h construction; preserve later original prep as undecided; bound exploration multipliers; reserve 6–10h galaxy budget after60 instead of old 12–53h. Not accepted before segmented tests.','changes':changes,'shipyard_later':'original150/10 retained; previous_id preserves old completed/in-flight building identity','first_shipyard_budget':{'preparation_trips':60,'construction_trips':180,'seconds_per_trip':60},'galaxy_total_upgrade_work':75600,'import':result},indent=2,ensure_ascii=False))
print(json.dumps(result))
