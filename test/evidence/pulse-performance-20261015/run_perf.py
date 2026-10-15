"""The only full-frame ABBA pulse experiment. Isolated D: projects/user data."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys

ROOT=Path(__file__).resolve().parents[3];E=Path(__file__).resolve().parent
BASE=Path('D:/CodexBuild/space_idle/pulse-perf-qa-20261015')
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
 data=replace_once(data,b'var feedback_rows:=0',b'var feedback_rows:=0\nvar qa_hot_batches:=0\nvar qa_hot_rows:=0\nvar qa_cold_batches:=0\nvar qa_cold_rows:=0')
 data=replace_once(data,b'pulse_feedback_owned=true;feedback_rows+=taken',b'pulse_feedback_owned=true;feedback_rows+=taken\n\t\t\t\tqa_hot_batches+=1;qa_hot_rows+=taken')
 data=replace_once(data,b'func consume_feedback_compatibility(game:RefCounted)->void:\n\tif not release_pulse_feedback(game):return',b'func consume_feedback_compatibility(game:RefCounted)->void:\n\tvar qa_count:int=kernel.feedback_count()\n\tif qa_count>0:qa_cold_batches+=1;qa_cold_rows+=qa_count\n\tif not release_pulse_feedback(game):return')
 if mode=='on':data=replace_once(data,b'const PULSE_FEEDBACK_PROTOTYPE:=false',b'const PULSE_FEEDBACK_PROTOTYPE:=true')
 return data
def environment(mode,case,run):
 env=os.environ.copy();user=BASE/mode/'user'
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
  env[key]=str(user/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PULSE_PERF_CASE=case,PULSE_PERF_RUN=run,PULSE_PERF_SCREENSHOT='1' if run=='mixed-on-a' else '0',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 return env
assert sha(DLL)==DLL_SHA
BASE.mkdir(parents=True,exist_ok=True)
receipt={'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_session_sha256':sha(SOURCE_SESSION),'dll_sha256':DLL_SHA,'driver_sha256':sha(E/'perf_driver.gd'),'qa_sources':{},'runs':{}}
for mode in ('off','on'):
 project=BASE/mode/'space-battleship'
 if not project.exists():
  project.mkdir(parents=True)
  for name in ('scripts','shaders','tools','data','config_excel','assets','addons','dev'):
   source=ROOT/'space-battleship'/name
   if source.exists():shutil.copytree(source,project/name,ignore=shutil.ignore_patterns('.godot','*.dll'))
  for name in ('project.godot','main.tscn','level_editor.tscn'):
   shutil.copy2(ROOT/'space-battleship'/name,project/name)
  shutil.copy2(ROOT/'test/combat_stress_fixture.gd',project/'combat_stress_fixture.gd')
  shutil.copy2(ROOT/'space-battleship/addons/native_battle/space_native.gdextension.in',project/'space_native.gdextension')
  (project/'bin').mkdir();shutil.copy2(DLL,project/'bin/space_native.dll')
  (project/'.runtime').mkdir()
  (project/'scripts/native_execution_session.gd').write_bytes(qa_session(mode))
  with (E/f'import-{mode}.log').open('w',encoding='utf8') as out:
   done=subprocess.run([str(GODOT),'--path',str(project),'--headless','--editor','--import','--quit'],env=environment(mode,'laser','import'),stdout=out,stderr=subprocess.STDOUT,timeout=240)
  assert done.returncode==0 and 'SCRIPT ERROR' not in (E/f'import-{mode}.log').read_text(encoding='utf8',errors='replace'),f'import {mode}'
 assert sha(project/'bin/space_native.dll')==DLL_SHA
 assert (project/'scripts/native_execution_session.gd').read_bytes()==qa_session(mode)
 shutil.copy2(E/'perf_driver.gd',project/'perf_driver.gd')
 assert (project/'perf_driver.gd').read_bytes()==(E/'perf_driver.gd').read_bytes()
 for source in (ROOT/'space-battleship/scripts').rglob('*.gd'):
  if source.name=='native_execution_session.gd':continue
  assert (project/'scripts'/source.relative_to(ROOT/'space-battleship/scripts')).read_bytes()==source.read_bytes(),source
 receipt['qa_sources'][mode]={'session_sha256':sha(project/'scripts/native_execution_session.gd'),'driver_sha256':sha(project/'perf_driver.gd'),'dll_sha256':sha(project/'bin/space_native.dll')}
order=[('laser','off','a'),('laser','on','a'),('laser','on','b'),('laser','off','b'),('mixed','off','a'),('mixed','on','a'),('mixed','on','b'),('mixed','off','b')]
only=sys.argv[1] if len(sys.argv)>1 else ''
for case,mode,rep in order:
 run=f'{case}-{mode}-{rep}'
 if only and only!=run:continue
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
 assert data['renderer']=='gl_compatibility' and data['focus_start'] and data['valid_frames']==len(data['frames_us']) and len(data['frames_us'])==len(data['frame_steps']),run
 assert data['after']['steps']-data['before']['steps']>=480 and data['before']['steps']-data['initial']['steps']>=240,run
 hot=int(data['after']['qa_hot_batches'])-int(data['before']['qa_hot_batches'])
 assert hot>0 if mode=='on' and case=='laser' else hot==0 if mode=='off' else hot>=0,run
 receipt['runs'][run]={'raw_sha256':sha(raw),'log_checkout_sha256':sha(log),'frames':len(data['frames_us']),'hot_batches':data['after']['qa_hot_batches']-data['before']['qa_hot_batches'],'cold_batches':data['after']['qa_cold_batches']-data['before']['qa_cold_batches']}
 if run=='mixed-on-a':
  screenshot=project/'.runtime/full-frame.png'
  assert screenshot.exists() and data.get('screenshot_ok',False)
  shutil.copy2(screenshot,E/'full-frame.png');receipt['screenshot_sha256']=sha(E/'full-frame.png')
 (E/'progress.json').write_bytes(json.dumps(receipt,indent=2).encode('utf8'))
 print(run,receipt['runs'][run],flush=True)
