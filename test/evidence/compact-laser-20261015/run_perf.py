from pathlib import Path
import hashlib, io, json, os, shutil, subprocess, tarfile, time, statistics

ROOT = Path(__file__).resolve().parents[3]
E = Path(__file__).resolve().parent
AREA = Path('D:/CodexBuild/space_idle/compact-laser-perf-20261015')
ENGINE = Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL = Path('D:/CodexBuild/space_idle/compact-laser-20261015/bin/space_native.dll')
REF = 'fea943bc8d944cf2247907139aa075ca0ccf510f'
ORDER = [('mixed','off',1),('mixed','on',1),('mixed','on',2),('mixed','off',2),('laser','off',1),('laser','on',1),('laser','on',2),('laser','off',2)]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(DLL) == '1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() == REF
assert not (E/'perf-receipt.json').exists(), 'preserve existing completed runs'
AREA.mkdir(parents=True,exist_ok=True)
receipt={'ref':REF,'dll_sha256':sha(DLL),'engine_sha256':sha(ENGINE),'driver_sha256':sha(E/'perf_driver.gd'),'order':ORDER,'runs':[],'imports':{},'gl_smoke':None,'scope':'Same code, DLL and workload off/on; full frame 1x GL compatibility, 60Hz logic, uncapped VSync off. ABBA drift control.'}
def save(): (E/'perf-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
projects={}
for label in ['mixed','laser']:
 target=AREA/label;target.mkdir(exist_ok=True)
 archive=subprocess.check_output(['git','archive',REF,'space-battleship'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as tf:tf.extractall(target,filter='data')
 project=target/'space-battleship';(project/'bin').mkdir(exist_ok=True)
 shutil.copy2(DLL,project/'bin/space_native.dll')
 shutil.copy2(ROOT/'space-battleship/addons/native_battle/space_native.gdextension.in',project/'space_native.gdextension')
 for src,dst in [('perf_driver.gd','port_perf.gd'),('probe.gd','probe.gd'),('counter_probe.gd','counter_probe.gd')]:shutil.copy2(E/src,project/dst)
 fixture='mixed_fixture.gd' if label=='mixed' else 'combat_stress_fixture.gd'
 shutil.copy2(ROOT/'test/evidence/five-environment-20261015/baseline'/fixture,project/'combat_stress_fixture.gd')
 (project/'.runtime').mkdir(exist_ok=True)
 for stale in ['missile_audit.gd','audit_smoke.gd']:
  if (project/stale).exists():(project/stale).unlink()
 env=os.environ.copy();env['TEMP']=str(target/'tmp');env['TMP']=env['TEMP'];Path(env['TEMP']).mkdir(exist_ok=True)
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(target/'user'/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PERF_NATIVE='1',PERF_SIDE=label,WEAPON_CASE=label,MISSILE_CONTROL='legend',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 with (E/(label+'-perf-import.log')).open('w',encoding='utf-8') as log:
  r=subprocess.run([str(ENGINE),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
 receipt['imports'][label]=r.returncode;save()
 assert r.returncode==0 and 'SCRIPT ERROR' not in (E/(label+'-perf-import.log')).read_text(encoding='utf8',errors='replace'),'import failed'
 projects[label]=(project,env,fixture)
 print('IMPORTED',label,flush=True)
def perform(label,mode,index,smoke=False):
 project,base_env,fixture=projects[label]
 env=base_env.copy();env['COMPACT_LASER_MODE']=mode
 if smoke:env['PERF_SMOKE']='1'
 suffix='smoke' if smoke else f'{mode}-{index}'
 name=f'{label}-{suffix}'
 cmd=[str(ENGINE),'--path',str(project),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://port_perf.gd']
 started=time.time()
 with (E/(name+'.log')).open('w',encoding='utf-8') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
 run={'label':label,'mode':mode,'index':index,'smoke':smoke,'start_unix':started,'end_unix':time.time(),'exit':r.returncode,'project_sha256':sha(project/'project.godot'),'fixture_sha256':sha(project/'combat_stress_fixture.gd'),'dll_sha256':sha(project/'bin/space_native.dll'),'log_sha256':sha(E/(name+'.log'))}
 stem='compact-smoke' if smoke else 'uncapped-port'
 for ext in ['json','png']:
  src=project/'.runtime'/(stem+'.'+ext)
  if src.exists():shutil.copy2(src,E/(name+'.'+ext));run[ext+'_sha256']=sha(E/(name+'.'+ext))
 if smoke:receipt['gl_smoke']=run
 else:receipt['runs'].append(run)
 save()
 assert r.returncode==0 and 'json_sha256' in run and 'SCRIPT ERROR' not in (E/(name+'.log')).read_text(encoding='utf8',errors='replace'),f'{name} failed; preserve evidence'
 d=json.loads((E/(name+'.json')).read_text(encoding='utf8'))
 if smoke:
  assert d['supported'] and d['compact_fires']>0 and d['handoff_unchanged'] and d['rows_after_downgrade']==d['active_flights'],d
 else:
  frames=d['frames_us_raw'];phases=d['phases']
  invalid=[i for i,(f,dt) in enumerate(zip(phases,frames)) if [f[x] for x in ['previous_post_us','main_begin_us','main_end_us','pre_draw_us','post_draw_us']]!=sorted(f[x] for x in ['previous_post_us','main_begin_us','main_end_us','pre_draw_us','post_draw_us']) or f['post_draw_us']-f['previous_post_us']!=dt]
  run['invalid_timing_frames']=invalid;run['mean_ms']=statistics.mean(frames)/1000;run['p95_ms']=sorted(frames)[int(.95*(len(frames)-1))]/1000;run['busy_over_10ms']=sum(x>10000 for x in frames);run['wall_seconds']=d['wall_seconds'];run['actual_1x']=d['actual_1x_pass'];run['sample_valid']=d['performance_sample_valid'];run['compact_fires']=d['compact_fires'];run['compact_impacts']=d['compact_impacts'];run['fires']=d['fires'];run['hits']=d['hits'];run['events']=d['events'];run['stress']=d['stress'];save()
  assert not invalid and len(phases)==len(frames)==len(d['frame_trace']) and d['sample_steps']==480 and d['actual_1x_pass'] and d['performance_sample_valid'] and d['compact_supported'] and (d['compact_fires']>0 if mode=='on' else d['compact_fires']==0),f'{name} invalid; preserve evidence'
 print('DONE',name,run.get('mean_ms'),run.get('compact_fires'),flush=True)
perform('mixed','on',0,True)
for label,mode,index in ORDER:perform(label,mode,index)
