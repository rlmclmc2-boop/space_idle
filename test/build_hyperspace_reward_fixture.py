"""Literal-table variations for a short real Godot binder test; no XLSX writes."""
import copy
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]/'space-battleship'
sys.path.insert(0,str(ROOT/'tools'))
import hyperspace_entities as h

def build():
    data=ROOT/'data';schema=h.load_schema()
    tables=h.parse_tables({name:(ROOT/'config_excel'/name).read_bytes() for name in ['hyperspace_config.xlsx','hyperspace_enemies.xlsx']})
    main=json.loads((data/'game_data.json').read_text());frozen={n:json.loads((data/n).read_text()) for n in schema['frozen_inputs']}
    default=h.project_tables(tables,main,frozen);refs=default['space_enemy_reward_catalog.json']['references']
    r=tables[('hyperspace_enemies.xlsx','早段回退预算')][0];refid=r['reference_id'];r['amount']=13;r['chance']=.75
    edits=[]
    def edit_group(gid,amount):
        eid=next(v for v in main['groups'][str(gid)]['slots'] if v is not None)
        main['enemies'][str(eid)]['drops'][0]['amount']=amount;edits.append({'enemy_id':eid,'drop_index':0,'amount':amount})
    edit_group(refs[refid]['late_reference_actual_group_id'],17)
    early_id,early=next((k,r) for k,r in refs.items() if r['early_existing_encounters'])
    edit_group(early['early_existing_encounters'][0]['group_id'],19)
    source=refs[refid]['source_design_group_id'];waves=frozen['space_enemy_reward_sources.json']['waves']
    missing=next(stage for stage in range(6,len(main['levels'])+1) if not any(w['stage']==stage and w['source_group']==source for w in waves))
    match=next(w for w in waves if w['source_group']==source and w['stage']>=6)
    edit_group(match['group'],23)
    projected=h.project_tables(tables,main,frozen)
    return {'source':'formal21sheet parent XLSX -> typed rows -> same importer projection','mainline_edits':edits,'catalog':projected['space_enemy_reward_catalog.json'],'cases':[{'label':'95block independent early fallback','reference_id':refid,'resource_level':1,'first_amount':13,'first_chance':.75,'matched':False},{'label':'current mainline late fallback refresh','reference_id':refid,'resource_level':missing,'first_amount':projected['space_enemy_reward_catalog.json']['references'][refid]['late_drop_blocks'][0][0]['amount'],'first_chance':1,'matched':False},{'label':'current mainline early fallback refresh','reference_id':early_id,'resource_level':1,'first_amount':19,'first_chance':1,'matched':False},{'label':'actual matched source uses current mainline drops','reference_id':refid,'resource_level':match['stage'],'first_amount':23,'first_chance':1,'matched':True}]}
if __name__=='__main__':
    Path(sys.argv[1]).write_text(json.dumps(build(),ensure_ascii=False,indent=2)+'\n')
