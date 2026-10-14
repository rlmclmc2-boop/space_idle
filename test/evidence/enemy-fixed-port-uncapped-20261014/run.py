from pathlib import Path
import hashlib,io,json,os,shutil,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[3];E=Path(__file__).resolve().parent
AREA=ROOT/'test/work/fixed-port-uncapped-ab'
ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL=Path('D:/CodexBuild/space_idle/stable-integration/test/work/battle-fix-20261013/native-ray/contact-candidate.dll')
REFS={'A':'e7cc31e026fd390b24daa188256ee7f5f33a67e9','B':'4b79775a7402c9ef19ab9fc29071a190f8645f4e'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(DLL)=='45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e'
assert not AREA.exists(),'One sample group only; never overwrite/retry'
AREA.mkdir(parents=True)
receipt={'refs':REFS,'order':['A','B'],'warm_step_target':240,'sample_step_target':480,'runs':[],'imports':{},'dll_sha256':sha(DLL),'engine_sha256':sha(ENGINE),'driver_sha256':sha(E/'driver.gd'),'fixture_sha256':sha(E/'combat_stress_fixture.gd'),'scope':'QA-only cap=0/VSync off; actual speed/time_scale 1; full rich15 layer2; four wall spans, not exclusive CPU time'}
def save(): (E/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
projects={}
for label,ref in REFS.items():
 target=AREA/label;target.mkdir()
 archive=subprocess.check_output(['git','archive',ref,'space-battleship'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as tf:tf.extractall(target,filter='data')
 project=target/'space-battleship';(project/'bin').mkdir(exist_ok=True)
 shutil.copy2(DLL,project/'bin/space_native.dll');shutil.copy2(ROOT/'space-battleship/space_native.gdextension',project/'space_native.gdextension')
 for a,z in [('driver.gd','port_perf.gd'),('combat_stress_fixture.gd','combat_stress_fixture.gd')]:shutil.copy2(E/a,project/z)
 (project/'.runtime').mkdir(exist_ok=True)
 env=os.environ.copy()
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(target/'user'/folder);Path(env[key]).mkdir(parents=True)
 env.update(PERF_NATIVE='1',PERF_SIDE=label,SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 with (target/'import.log').open('w',encoding='utf-8') as log:
  result=subprocess.run([str(ENGINE),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
 receipt['imports'][label]=result.returncode;save()
 assert result.returncode==0,'Import failed; stop'
 projects[label]=(project,env);print('Imported',label,flush=True)
for label in ['A','B']:
 project,env=projects[label]
 cmd=[str(ENGINE),'--path',str(project),'--rendering-method','gl_compatibility','--script','res://port_perf.gd']
 run={'label':label,'cmd':cmd,'started_unix':time.time(),'project_sha256':sha(project/'project.godot'),'dll_sha256':sha(project/'bin/space_native.dll')}
 try:
  with (E/(label+'.log')).open('w',encoding='utf-8') as log:result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90)
  run['exit']=result.returncode
 except subprocess.TimeoutExpired:run['exit']='timeout'
 run['completed_unix']=time.time()
 for ext in ['json','png']:
  source=project/'.runtime'/('uncapped-port.'+ext)
  if source.exists():shutil.copy2(source,E/(label+'.'+ext));run[ext+'_sha256']=sha(source)
 receipt['runs'].append(run);save()
 assert run['exit']==0 and 'json_sha256' in run,'Run failed; preserve output and stop'
 d=json.loads((E/(label+'.json')).read_text(encoding='utf-8'))
 invalid=[]
 for i,(f,dt) in enumerate(zip(d['phases'],d['frames_us_raw'])):
  t=[f[x] for x in ['previous_post_us','main_begin_us','main_end_us','pre_draw_us','post_draw_us']]
  if t!=sorted(t) or t[-1]-t[0]!=dt:invalid.append(i)
 run['invalid_order_or_closure_frames']=invalid
 run['sample_count_equal']=len(d['phases'])==len(d['frames_us_raw'])==len(d['frame_trace'])
 save();print('Finished',label,'exit',run['exit'],'frames',len(d['phases']),'invalid',invalid,flush=True)
 assert not invalid and run['sample_count_equal'],'Invalid new timing boundary: preserve raw evidence and stop, do not change formula or rerun'
