"""Isolated two-gate targeted run. Same source/DLL, no player save or full-frame timing."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess

ROOT=Path(__file__).resolve().parents[3]
E=Path(__file__).resolve().parent
BASE=Path('D:/CodexBuild/space_idle/pulse-feedback-qa-20261015')
DLL=Path('D:/CodexBuild/space_idle/native-pulse-prototype-20261015/bin/space_native.dll')
GODOT=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(DLL)=='483a7256e2d3946090515197a36fdd36122a74d4cae32acc7629f3cdaa6ce22f'
assert not (E/'receipt.json').exists()
BASE.mkdir(parents=True,exist_ok=True)
for mode in ('off','on'):
 project=BASE/mode/'space-battleship'
 assert not project.exists(),f'Preserve existing isolated project: {project}'
 project.mkdir(parents=True)
 for name in ('scripts','shaders','tools','data','config_excel','assets','addons','dev'):
  source=ROOT/'space-battleship'/name
  if source.exists():shutil.copytree(source,project/name,ignore=shutil.ignore_patterns('.godot','*.dll'))
 for name in ('project.godot','main.tscn','level_editor.tscn'):
  shutil.copy2(ROOT/'space-battleship'/name,project/name)
 shutil.copy2(ROOT/'test/combat_stress_fixture.gd',project/'combat_stress_fixture.gd')
 shutil.copy2(E/'target_driver.gd',project/'target_driver.gd')
 shutil.copy2(ROOT/'space-battleship/addons/native_battle/space_native.gdextension.in',project/'space_native.gdextension')
 (project/'bin').mkdir();shutil.copy2(DLL,project/'bin/space_native.dll')
 (project/'.runtime').mkdir()
 gate=project/'scripts/native_execution_session.gd'
 source=gate.read_text(encoding='utf8')
 assert source.count('const PULSE_FEEDBACK_PROTOTYPE:=false')==1
 if mode=='on':gate.write_text(source.replace('const PULSE_FEEDBACK_PROTOTYPE:=false','const PULSE_FEEDBACK_PROTOTYPE:=true'),encoding='utf8')
 env=os.environ.copy();user=BASE/mode/'user'
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
  env[key]=str(user/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env.update(PULSE_QA_MODE=mode,SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 for kind,args in [('import',['--headless','--editor','--import','--quit']),('run',['--headless','--script','res://target_driver.gd'])]:
  log=E/f'{mode}-{kind}.log'
  with log.open('w',encoding='utf8') as output:
   completed=subprocess.run([str(GODOT),'--path',str(project),*args],env=env,stdout=output,stderr=subprocess.STDOUT,timeout=180)
  content=log.read_text(encoding='utf8',errors='replace')
  assert completed.returncode==0 and 'SCRIPT ERROR' not in content and 'ERROR:' not in content,(kind,mode,completed.returncode,content[-3000:])
 shutil.copy2(project/'.runtime/target.json',E/f'{mode}-raw.json')
receipt={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'dll_sha256':sha(DLL),'driver_sha256':sha(E/'target_driver.gd'),'run_script_sha256':sha(E/'run_target.py')}
for name in ('off','on'):
 for ext in ('raw.json','import.log','run.log'):
  p=E/f'{name}-{ext}';receipt[p.name+'_sha256']=sha(p)
(E/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
print(json.dumps(receipt,indent=2))
