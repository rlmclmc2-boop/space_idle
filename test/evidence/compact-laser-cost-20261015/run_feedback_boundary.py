"""QA-only feedback split: one additional clock pair per logical step."""
from pathlib import Path
import gzip, hashlib, json, os, shutil, subprocess
from prepare_cost import ROOT, E, patch, restore, sha, exact

ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
BASE=Path('D:/CodexBuild/space_idle/compact-laser-perf-20261015')
DLL_HASH='1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5'
OUT=E/'feedback-boundary'
OUT.mkdir(exist_ok=True)
assert not (OUT/'receipt.json').exists()
receipt={'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
         'dll_sha256':DLL_HASH,'engine_sha256':sha(ENGINE),
         'scope':'Only the native take_feedback call receives one extra timestamp pair per logical step. The outer consume_feedback wrapper from the earlier cost probe remains. No per-hit clock, behavior edit, or new project.',
         'runs':[]}
def save(): (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
for label in ['mixed','laser']:
 project=BASE/label/'space-battleship'
 assert sha(project/'bin/space_native.dll')==DLL_HASH
 env=os.environ.copy();u=Path('D:/CodexBuild/space_idle/compact-laser-cost-20261015/users')/label
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
  env[key]=str(u/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PERF_NATIVE='1',PERF_SIDE=label,WEAPON_CASE=label,MISSILE_CONTROL='legend',
            COMPACT_LASER_MODE='on',QA_COST_MODE='on',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 try:
  patches=patch(project)
  session=project/'scripts/native_execution_session.gd'
  s=session.read_text(encoding='utf8')
  s=exact(s,'\tfor row in kernel.take_feedback():',
          '\tvar qa_take_started=QACost.begin()\n\tvar qa_feedback_rows=kernel.take_feedback()\n\tQACost.finish("feedback_native_take",qa_take_started)\n\tfor row in qa_feedback_rows:',
          'take_feedback boundary')
  session.write_text(s,encoding='utf8')
  driver=(ROOT/'test/evidence/compact-laser-20261015/perf_driver.gd').read_text(encoding='utf8')
  driver=exact(driver,'const Probe=preload("res://probe.gd")','const Probe=preload("res://probe.gd")\nconst QACost=preload("res://qa_cost.gd")','driver preload')
  driver=exact(driver,'Probe.reset();Probe.effects.clear();Probe.active=true','Probe.reset();Probe.effects.clear();Probe.active=true\n QACost.reset();QACost.enabled=true','driver start')
  driver=exact(driver,'Probe.active=false\n scene.set_process(false);scene.track_frames=false','Probe.active=false\n QACost.enabled=false\n scene.set_process(false);scene.track_frames=false','driver stop')
  driver=exact(driver,'row.probe={"spans":Probe.spans','row.qa_cost=QACost.report()\n row.probe={"spans":Probe.spans','driver report')
  (project/'cost_driver.gd').write_text(driver,encoding='utf8')
  receipt['runs'].append({'label':label,'patches':patches,'qa_session_sha256':sha(session),'qa_driver_sha256':sha(project/'cost_driver.gd')});save()
  with (OUT/(label+'-import.log')).open('w',encoding='utf8') as f:
   imp=subprocess.run([str(ENGINE),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=150)
  assert imp.returncode==0 and 'SCRIPT ERROR' not in (OUT/(label+'-import.log')).read_text(encoding='utf8',errors='replace'),label+' import failed'
  for ext in ['json','png']:
   src=project/'.runtime'/('uncapped-port.'+ext)
   if src.exists():src.unlink()
  cmd=[str(ENGINE),'--path',str(project),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://cost_driver.gd']
  with (OUT/(label+'.log')).open('w',encoding='utf8') as f:
   run=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=150)
  assert run.returncode==0 and 'SCRIPT ERROR' not in (OUT/(label+'.log')).read_text(encoding='utf8',errors='replace'),label+' run failed'
  raw=(project/'.runtime/uncapped-port.json').read_bytes();d=json.loads(raw)
  assert d['sample_steps']==480 and d['performance_sample_valid'] and d['actual_1x_pass'] and len(d['qa_cost']['durations_us']['feedback_native_take'])==480
  archive=OUT/(label+'.json.gz');archive.write_bytes(gzip.compress(raw,9,mtime=0))
  receipt['runs'][-1].update(raw_sha256=hashlib.sha256(raw).hexdigest(),gzip_sha256=sha(archive),
                             import_log_sha256=sha(OUT/(label+'-import.log')),log_sha256=sha(OUT/(label+'.log')))
  save();print('DONE',label,'steps',d['sample_steps'],'hits',d['events']['hit'],flush=True)
 finally:
  restore(project)
  for name in ['cost_driver.gd','qa_cost.gd']:
   f=project/name
   if f.exists():f.unlink()
