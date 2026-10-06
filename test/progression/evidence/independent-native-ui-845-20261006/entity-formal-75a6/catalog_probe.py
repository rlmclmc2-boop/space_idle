import copy,json,os,subprocess,sys
from pathlib import Path
p=Path('/tmp/entity-formal-75a6/project');sys.path.insert(0,str(p/'tools'));import hyperspace_entities as h
raw={n:(p/'config_excel'/n).read_bytes() for n in ['hyperspace_config.xlsx','hyperspace_enemies.xlsx']};files=[p/'data/game_data.json',p/'data/space_enemy_reward_catalog.json'];back={f:f.read_bytes() for f in files};main=json.loads(back[files[0]]);gid=30101;eid=next(v for v in main['groups'][str(gid)]['slots'] if v is not None)
env=dict(os.environ,XDG_DATA_HOME='/tmp/entity-formal-75a6/user/data',XDG_CONFIG_HOME='/tmp/entity-formal-75a6/user/config',XDG_CACHE_HOME='/tmp/entity-formal-75a6/user/cache');results=[]
try:
 for case in ['numeric','add_drop','replace_resource','remove_drop']:
  changed=copy.deepcopy(main);drops=changed['enemies'][str(eid)]['drops']
  if case=='numeric':drops[0]['amount']=17.0
  if case=='add_drop':drops.append({'resourceId':2,'amount':1.0,'chance':0.5})
  if case=='replace_resource':drops[0]['resourceId']=2
  if case=='remove_drop':drops.clear()
  outputs,_=h.read_bundle(raw,changed,p/'data')
  files[0].write_text(json.dumps(changed,ensure_ascii=False));files[1].write_text(json.dumps(outputs[files[1].name],ensure_ascii=False))
  r=subprocess.run(['godot','--headless','--path',str(p),'--script','res://qa/catalog_structure.gd'],env=env,capture_output=True,text=True,timeout=30)
  out=r.stdout+r.stderr;Path('/tmp/entity-formal-75a6/evidence/catalog-'+case+'.log').write_text(out)
  results.append({'case':case,'import_projection':'accepted','godot_exit':r.returncode,'output':out});print(case,r.returncode,out.strip())
finally:
 for f,b in back.items():f.write_bytes(b)
Path('/tmp/entity-formal-75a6/evidence/catalog-structure.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
assert all(x['godot_exit']==0 for x in results)
