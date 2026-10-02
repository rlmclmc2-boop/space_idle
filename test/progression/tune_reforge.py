"""Provisional reforge benefit candidate; source Excel and normal import."""
from pathlib import Path
import argparse,json,sys,openpyxl
root=Path(__file__).resolve().parents[2];cfg=root/'space-battleship/config_excel'
p=argparse.ArgumentParser();p.add_argument('--equipment',type=int,default=15);p.add_argument('--hightech',type=int,default=10);a=p.parse_args()
from source_lock import acquire
_source_lock=acquire(root)
w=openpyxl.load_workbook(cfg/'planet_buff.xlsx');s=w.active;h={c.value:c.column for c in s[1] if c.value};changes=[]
for r in range(4,s.max_row+1):
 target=s.cell(r,h['target']).value
 if s.cell(r,h['buff_type']).value!='level_bonus' or target not in ['equipment','hightech']:continue
 value=a.equipment if target=='equipment' else a.hightech
 changes.append({'id':s.cell(r,h['id']).value,'planet':s.cell(r,h['planet_id']).value,'target':target,'old':s.cell(r,h['value']).value,'new':value})
 s.cell(r,h['value'],value);s.cell(r,h['des'],('装备' if target=='equipment' else 'AI工厂')+'效果等级 +'+str(value))
w.save(cfg/'planet_buff.xlsx')
sys.path.insert(0,str(root/'space-battleship/tools'));from config_workbooks import incremental_import
result=incremental_import(cfg,root/'space-battleship/data/game_data.json')
(root/'test/progression/candidates/reforge-v1.json').write_text(json.dumps({'scope':'Provisional 30–60 numerical candidate; no new mechanics. No acceptance until real34 stall/replay/35 and full galaxy journey tests.','reason':'Existing +5/+5 needs evaluation against >=12h numeric34 stall and <=2h return; +15/+10 is a test candidate approximating18 effective power levels. Later preparation durations retain original settings and remain undecided.','changes':changes,'import':result},ensure_ascii=False,indent=2));print(result)
