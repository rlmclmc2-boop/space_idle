from pathlib import Path
import hashlib, io, json, os, shutil, subprocess, tarfile, time, sys
ROOT=Path(__file__).resolve().parents[3]
EVIDENCE=Path(__file__).resolve().parent
AREA=ROOT/'test/work/ordinary-port-ab'
ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL=Path('D:/CodexBuild/space_idle/stable-integration/test/work/battle-fix-20261013/native-ray/contact-candidate.dll')
REFS={'A':'e7cc31e026fd390b24daa188256ee7f5f33a67e9','B':'85c76e794838be595be1722ccbb08b9a24bca852'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(DLL)=='45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e'
resume='--resume-before-sampling' in sys.argv
assert resume or not AREA.exists(), 'Never silently overwrite or rerun a sample set'
assert not any(AREA.glob('*/space-battleship/.runtime/port-perf.json')), 'No second measured group allowed'
AREA.mkdir(parents=True,exist_ok=True)
receipt={'refs':REFS,'order':['A','B'],'warm_steps':240,'sample_steps':240,'runs':[], 'engine_sha256':sha(ENGINE),'dll_sha256':sha(DLL),'driver_sha256':sha(EVIDENCE/'driver.gd'),'fixture_sha256':sha(EVIDENCE/'combat_stress_fixture.gd'),'policy':'One A/B only; default cap, full presentation, actual 1x; no rejected candidates or production instrumentation.'}
receipt['startup_failure']={'stage':'before warmup and sampling','reason':'unavailable optional native_readonly_observer added to reused driver','runner_exit':1,'timeout_seconds':90,'samples':0,'resolution':'removed additional call; existing g.event and conditional fixture observer retained'} if resume else None
projects={}
for label,ref in REFS.items():
 target=AREA/label;target.mkdir(exist_ok=True)
 if not resume:
  archive=subprocess.check_output(['git','archive',ref,'space-battleship'],cwd=ROOT)
  with tarfile.open(fileobj=io.BytesIO(archive)) as tf:tf.extractall(target,filter='data')
 project=target/'space-battleship';projects[label]=project
 (project/'bin').mkdir(exist_ok=True);shutil.copy2(DLL,project/'bin/space_native.dll')
 shutil.copy2(ROOT/'space-battleship/space_native.gdextension',project/'space_native.gdextension')
 shutil.copy2(EVIDENCE/'driver.gd',project/'port_perf.gd')
 shutil.copy2(EVIDENCE/'combat_stress_fixture.gd',project/'combat_stress_fixture.gd')
 (project/'.runtime').mkdir(exist_ok=True)
 env=os.environ.copy()
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(target/'user'/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PERF_NATIVE='1',PERF_SIDE=label,SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 if not resume:
  with (target/'import.log').open('w',encoding='utf-8') as log:
   result=subprocess.run([str(ENGINE),'--path',str(project),'--headless','--editor','--import','--quit'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
  receipt.setdefault('imports',{})[label]=result.returncode
  assert result.returncode==0,'Import failed; no measured run started'
 else:receipt.setdefault('imports',{})[label]='previous successful import reused; script-only repair'
 projects[label]=(project,env)
 print('Imported',label,flush=True)
for label in ['A','B']:
 project,env=projects[label]
 cmd=[str(ENGINE),'--path',str(project),'--rendering-method','gl_compatibility','--script','res://port_perf.gd']
 start=time.time()
 with (EVIDENCE/(label+'.log')).open('w',encoding='utf-8') as log:
  result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90)
 run={'label':label,'start_unix':start,'end_unix':time.time(),'exit':result.returncode,'cmd':cmd,'project_sha256':sha(project/'project.godot'),'dll_sha256':sha(project/'bin/space_native.dll')}
 for suffix in ['json','png']:
  f=project/'.runtime'/('port-perf.'+suffix)
  if f.exists():shutil.copy2(f,EVIDENCE/(label+'.'+suffix));run[suffix+'_sha256']=sha(f)
 receipt['runs'].append(run)
 (EVIDENCE/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
 print('Finished',label,'exit',result.returncode,flush=True)
 assert result.returncode==0 and 'json_sha256' in run,'Measured run failed; stop without retry'
