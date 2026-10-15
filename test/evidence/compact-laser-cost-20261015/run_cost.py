from pathlib import Path
import gzip, hashlib, json, os, shutil, subprocess, time
from prepare_cost import ROOT,E,patch,restore,sha,exact

ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
AREA=Path('D:/CodexBuild/space_idle/compact-laser-cost-20261015')
BASE=Path('D:/CodexBuild/space_idle/compact-laser-perf-20261015')
DLL_HASH='1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5'
assert not (E/'receipt.json').exists(),'preserve finished evidence'
receipt={'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'dll_sha256':DLL_HASH,'engine_sha256':sha(ENGINE),'qa_cost_sha256':sha(E/'qa_cost.gd'),'prepare_sha256':sha(E/'prepare_cost.py'),'order':['off-1','on-1','off-2'],'runs':[],'projects':{},'scope':'Compact-on mixed and pulse fixtures only. QA source wrappers identical across timer-off/on/off. Full GL 1x, 60Hz logic, uncapped and VSync off. No gameplay edits or prototype.'}
def save():(E/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
def driver(project):
 src=ROOT/'test/evidence/compact-laser-20261015/perf_driver.gd'
 s=src.read_text(encoding='utf8')
 s=exact(s,'const Probe=preload("res://probe.gd")','const Probe=preload("res://probe.gd")\nconst QACost=preload("res://qa_cost.gd")','driver preload')
 s=exact(s,'Probe.reset();Probe.effects.clear();Probe.active=true','Probe.reset();Probe.effects.clear();Probe.active=true\n QACost.reset();QACost.enabled=OS.get_environment("QA_COST_MODE")=="on"','driver start')
 s=exact(s,'Probe.active=false\n scene.set_process(false);scene.track_frames=false','Probe.active=false\n QACost.enabled=false\n scene.set_process(false);scene.track_frames=false','driver stop')
 s=exact(s,'row.probe={"spans":Probe.spans','row.qa_cost=QACost.report()\n row.probe={"spans":Probe.spans','driver report')
 (project/'cost_driver.gd').write_text(s,encoding='utf8')
 return {'base_driver_sha256':sha(src),'qa_driver_sha256':sha(project/'cost_driver.gd')}
def env_for(label):
 env=os.environ.copy();u=AREA/'users'/label
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
  env[key]=str(u/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PERF_NATIVE='1',PERF_SIDE=label,WEAPON_CASE=label,MISSILE_CONTROL='legend',COMPACT_LASER_MODE='on',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 return env
for label in ['mixed','laser']:
 project=BASE/label/'space-battleship'
 assert sha(project/'bin/space_native.dll')==DLL_HASH
 env=env_for(label)
 try:
  patches=patch(project);shutil.copy2(E/'qa_cost.gd',project/'qa_cost.gd');drv=driver(project)
  receipt['projects'][label]={'patches':patches,'driver':drv,'project_sha256':sha(project/'project.godot'),'fixture_sha256':sha(project/'combat_stress_fixture.gd')};save()
  with (E/(label+'-import.log')).open('w',encoding='utf8') as out:
   imp=subprocess.run([str(ENGINE),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,stdout=out,stderr=subprocess.STDOUT,timeout=150)
  assert imp.returncode==0 and 'SCRIPT ERROR' not in (E/(label+'-import.log')).read_text(encoding='utf8',errors='replace'),label+' import failed'
  for name,mode in [('off-1','off'),('on-1','on'),('off-2','off')]:
   env['QA_COST_MODE']=mode
   for ext in ['json','png']:
    src=project/'.runtime'/('uncapped-port.'+ext)
    if src.exists():src.unlink()
   cmd=[str(ENGINE),'--path',str(project),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://cost_driver.gd']
   began=time.time();filename=label+'-'+name
   with (E/(filename+'.log')).open('w',encoding='utf8') as out:
    try:r=subprocess.run(cmd,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=150);code=r.returncode
    except subprocess.TimeoutExpired:code='timeout'
   run={'label':label,'order':name,'timers':mode,'exit':code,'wall_seconds':time.time()-began,'log_sha256':sha(E/(filename+'.log'))}
   src=project/'.runtime'/'uncapped-port.json'
   if src.exists():
    raw=src.read_bytes();archive=E/(filename+'.json.gz');archive.write_bytes(gzip.compress(raw,9,mtime=0))
    run.update(raw_sha256=hashlib.sha256(raw).hexdigest(),gzip_sha256=sha(archive))
   src=project/'.runtime'/'uncapped-port.png'
   if src.exists() and name=='on-1':shutil.copy2(src,E/(filename+'.png'));run['png_sha256']=sha(E/(filename+'.png'))
   receipt['runs'].append(run);save()
   assert code==0 and 'raw_sha256' in run and 'SCRIPT ERROR' not in (E/(filename+'.log')).read_text(encoding='utf8',errors='replace'),filename+' failed; preserve raw and stop'
   d=json.loads(raw)
   assert d['sample_steps']==480 and d['actual_1x_pass'] and d['performance_sample_valid'] and d['compact_fires']>0 and d['compact_supported'],filename+' invalid sample'
   assert len(d['frames_us_raw'])==len(d['phases'])==len(d['frame_trace']),filename+' incomplete frames'
   assert (bool(d['qa_cost']['durations_us'])==(mode=='on')),filename+' timer mode mismatch'
   print('DONE',filename,'frames',len(d['frames_us_raw']),'fires',d['fires'],'qa scopes',list(d['qa_cost']['durations_us']),flush=True)
 finally:
  restore(project)
  for filename in ['cost_driver.gd','qa_cost.gd']:
   path=project/filename
   if path.exists():path.unlink()
