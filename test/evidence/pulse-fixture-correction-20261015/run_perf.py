"""Corrected frozen laser fixture, uptake-only probe."""
from pathlib import Path
import gzip, hashlib, json, os, shutil, subprocess, sys

ROOT=Path(__file__).resolve().parents[3];E=Path(__file__).resolve().parent
BASE=Path('D:/CodexBuild/space_idle/pulse-fixture-correction-qa-20261015')
FROZEN=ROOT/'test/evidence/five-environment-20261015/baseline'
FIXTURE_SHA={'laser':'227f9cc6bba709ba29a41041c01eab3d4064e58cdc1fc23b0f4fb92e31cb9dfe','mixed':'cc310aec9fddeb6b2199c811e47ff2eb4ddd82c108c381407d3c91dd13194db4'}
DLL=Path('D:/CodexBuild/space_idle/native-pulse-prototype-20261015/bin/space_native.dll')
GODOT=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL_SHA='483a7256e2d3946090515197a36fdd36122a74d4cae32acc7629f3cdaa6ce22f'
SOURCE_SESSION=ROOT/'space-battleship/scripts/native_execution_session.gd'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace_once(data,old,new):
 assert data.count(old)==1,(old,data.count(old))
 return data.replace(old,new)
def qa_session(mode):
 data=SOURCE_SESSION.read_bytes().replace(b'\r\n',b'\n')
 data=replace_once(data,b'var feedback_rows:=0',b'var feedback_rows:=0\nvar qa_hot_batches:=0\nvar qa_hot_rows:=0\nvar qa_cold_batches:=0\nvar qa_cold_rows:=0\nvar qa_cold_kind_rows:Dictionary={}\nvar qa_cold_first_reject:Dictionary={}')
 data=replace_once(data,b'pulse_feedback_owned=true;feedback_rows+=taken',b'pulse_feedback_owned=true;feedback_rows+=taken\n\t\t\t\tqa_hot_batches+=1;qa_hot_rows+=taken')
 data=replace_once(data,b'func consume_feedback_compatibility(game:RefCounted)->void:\n\tif not release_pulse_feedback(game):return\n\tfor row in kernel.take_feedback():',b'''func consume_feedback_compatibility(game:RefCounted)->void:
\tif not release_pulse_feedback(game):return
\tvar qa_batch:Array=kernel.take_feedback()
\tif not qa_batch.is_empty():
\t\tqa_cold_batches+=1;qa_cold_rows+=qa_batch.size()
\t\tvar qa_first:=""
\t\tvar qa_unknown_before:=false
\t\tfor qa_row in qa_batch:
\t\t\tvar qa_kind:int=int(qa_row.kind)
\t\t\tvar qa_key:=str(qa_kind)
\t\t\tqa_cold_kind_rows[qa_key]=int(qa_cold_kind_rows.get(qa_key,0))+1
\t\t\tif not qa_first.is_empty():continue
\t\t\tif qa_kind in [0,1,5,9]:
\t\t\t\tif not qa_row.has("native_laser"):qa_first="kind_"+qa_key+"_noncompact"
\t\t\telif qa_kind==2:
\t\t\t\tif bool(qa_row.player):qa_first="kind_2_player"
\t\t\t\telif not is_finite(float(qa_row.amount)) or not is_finite(float(qa_row.absorbed)):qa_first="kind_2_nonfinite"
\t\t\t\telse:qa_unknown_before=true # pulse_laser_hit is not exported by this DLL.
\t\t\telse:qa_first="kind_"+qa_key+"_unsupported"
\t\tif qa_first.is_empty():qa_first="kind_2_flag_unexposed_or_other_guard"
\t\telif qa_unknown_before:qa_first="kind_2_flag_unexposed_before_"+qa_first
\t\tqa_cold_first_reject[qa_first]=int(qa_cold_first_reject.get(qa_first,0))+1
\tfor row in qa_batch:''')
 if mode=='on':data=replace_once(data,b'const PULSE_FEEDBACK_PROTOTYPE:=false',b'const PULSE_FEEDBACK_PROTOTYPE:=true')
 return data
def environment(mode,case,run):
 env=os.environ.copy();user=BASE/mode/'user'
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
  env[key]=str(user/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PULSE_PERF_CASE=case,PULSE_PERF_RUN=run,PULSE_PERF_UPTAKE_ONLY='1' if run.endswith('probe') else '0',PULSE_PERF_SCREENSHOT='0',WEAPON_CASE='laser',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 return env
assert sha(DLL)==DLL_SHA
for key,expected in FIXTURE_SHA.items():assert sha(FROZEN/('combat_stress_fixture.gd' if key=='laser' else 'mixed_fixture.gd'))==expected
with gzip.open(FROZEN/'laser.json.gz','rt',encoding='utf8') as source:FROZEN_MANIFEST=json.load(source)['stress']['config']
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode('utf8')
FROZEN_MANIFEST_SHA='c700fc3484c7ad6ee3c73a905e46e24255901d6410f7697bc18916f6d697ae90'
assert hashlib.sha256(canonical(FROZEN_MANIFEST)).hexdigest()==FROZEN_MANIFEST_SHA
BASE.mkdir(parents=True,exist_ok=True)
receipt={'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_session_sha256':sha(SOURCE_SESSION),'dll_sha256':DLL_SHA,'driver_sha256':sha(E/'perf_driver.gd'),'frozen_fixture_sha256':FIXTURE_SHA,'frozen_laser_raw_sha256':sha(FROZEN/'laser.json.gz'),'frozen_laser_manifest_sha256':FROZEN_MANIFEST_SHA,'qa_sources':{},'runs':{}}
assert len(sys.argv)==2 and sys.argv[1]=='laser-on-probe'
for mode in ('on',):
 project=BASE/mode/'space-battleship'
 if not project.exists():
  project.mkdir(parents=True)
  for name in ('scripts','shaders','tools','data','config_excel','assets','addons','dev'):
   source=ROOT/'space-battleship'/name
   if source.exists():shutil.copytree(source,project/name,ignore=shutil.ignore_patterns('.godot','*.dll'))
  for name in ('project.godot','main.tscn','level_editor.tscn'):
   shutil.copy2(ROOT/'space-battleship'/name,project/name)
  shutil.copy2(FROZEN/'combat_stress_fixture.gd',project/'combat_stress_fixture.gd')
  shutil.copy2(FROZEN/'mixed_fixture.gd',project/'mixed_fixture.gd')
  shutil.copy2(ROOT/'space-battleship/addons/native_battle/space_native.gdextension.in',project/'space_native.gdextension')
  (project/'bin').mkdir();shutil.copy2(DLL,project/'bin/space_native.dll')
  (project/'.runtime').mkdir()
  (project/'scripts/native_execution_session.gd').write_bytes(qa_session(mode))
  with (E/f'import-{mode}.log').open('w',encoding='utf8') as out:
   done=subprocess.run([str(GODOT),'--path',str(project),'--headless','--editor','--import','--quit'],env=environment(mode,'laser','import'),stdout=out,stderr=subprocess.STDOUT,timeout=240)
  assert done.returncode==0 and 'SCRIPT ERROR' not in (E/f'import-{mode}.log').read_text(encoding='utf8',errors='replace'),f'import {mode}'
 assert sha(project/'bin/space_native.dll')==DLL_SHA
 assert sha(project/'combat_stress_fixture.gd')==FIXTURE_SHA['laser'] and sha(project/'mixed_fixture.gd')==FIXTURE_SHA['mixed']
 assert (project/'scripts/native_execution_session.gd').read_bytes()==qa_session(mode)
 shutil.copy2(E/'perf_driver.gd',project/'perf_driver.gd')
 assert (project/'perf_driver.gd').read_bytes()==(E/'perf_driver.gd').read_bytes()
 for source in (ROOT/'space-battleship/scripts').rglob('*.gd'):
  if source.name=='native_execution_session.gd':continue
  assert (project/'scripts'/source.relative_to(ROOT/'space-battleship/scripts')).read_bytes()==source.read_bytes(),source
 receipt['qa_sources'][mode]={'session_sha256':sha(project/'scripts/native_execution_session.gd'),'driver_sha256':sha(project/'perf_driver.gd'),'dll_sha256':sha(project/'bin/space_native.dll')}
order=[('laser','on','probe')]
for case,mode,rep in order:
 run=f'{case}-{mode}-{rep}'
 project=BASE/mode/'space-battleship'
 raw=E/f'{run}.json';log=E/f'{run}.log'
 if not raw.exists():
  with log.open('w',encoding='utf8') as out:
   done=subprocess.run([str(GODOT),'--path',str(project),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://perf_driver.gd'],env=environment(mode,case,run),stdout=out,stderr=subprocess.STDOUT,timeout=300)
  assert done.returncode==0,(run,done.returncode,log.read_text(encoding='utf8',errors='replace')[-3000:])
  shutil.copy2(project/'.runtime/perf.json',raw)
 content=log.read_text(encoding='utf8',errors='replace')
 assert 'SCRIPT ERROR' not in content and 'ERROR:' not in content,(run,content[-3000:])
 data=json.loads(raw.read_text(encoding='utf8'))
 assert data['run']==run and data['case']==case and data['gate']==(mode=='on')
 assert data['loadout_manifest']==FROZEN_MANIFEST,(run,'frozen manifest mismatch')
 assert len(data['loadout_manifest']['equipped'])==5 and len(data['loadout_manifest']['combat_sources'])==13
 assert [x['key'] for x in data['loadout_manifest']['ordinary']]==['laser']*8
 assert data['renderer']=='gl_compatibility' and data['focus_start'] and data['valid_frames']==len(data['frames_us']) and len(data['frames_us'])==len(data['frame_steps']),run
 assert data['after']['steps']-data['before']['steps']>=data['sample_target'] and data['before']['steps']-data['initial']['steps']>=data['warm_target'],run
 hot=int(data['after']['qa_hot_batches'])-int(data['before']['qa_hot_batches'])
 assert hot>=0 if mode=='on' else hot==0,run
 receipt['runs'][run]={'raw_sha256':sha(raw),'log_checkout_sha256':sha(log),'frames':len(data['frames_us']),'hot_batches':hot,'hot_rows':data['after']['qa_hot_rows']-data['before']['qa_hot_rows'],'cold_batches':data['after']['qa_cold_batches']-data['before']['qa_cold_batches'],'cold_rows':data['after']['qa_cold_rows']-data['before']['qa_cold_rows']}
 (E/'receipt.json').write_bytes(json.dumps(receipt,indent=2).encode('utf8'))
 print(run,receipt['runs'][run],flush=True)
