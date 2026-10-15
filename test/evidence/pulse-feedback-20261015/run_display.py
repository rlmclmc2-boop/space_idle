"""Targeted display/anchor comparison using the same isolated candidate DLL."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess

E=Path(__file__).resolve().parent; ROOT=E.parents[2]
BASE=Path('D:/CodexBuild/space_idle/pulse-feedback-qa-20261015')
GODOT=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL_SHA='483a7256e2d3946090515197a36fdd36122a74d4cae32acc7629f3cdaa6ce22f'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
receipt={'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'dll_sha256':DLL_SHA,'loaded_sources':{}}
for mode in ('off','on'):
 project=BASE/mode/'space-battleship'
 assert sha(project/'bin/space_native.dll')==DLL_SHA
 shutil.copy2(E/'target_driver.gd',project/'target_driver.gd')
 manifest={}
 for source in sorted((ROOT/'space-battleship/scripts').rglob('*.gd')):
  rel=source.relative_to(ROOT/'space-battleship')
  loaded=project/rel
  expected=source.read_bytes()
  if rel.as_posix()=='scripts/native_execution_session.gd' and mode=='on':
   expected=expected.replace(b'const PULSE_FEEDBACK_PROTOTYPE:=false',b'const PULSE_FEEDBACK_PROTOTYPE:=true')
  assert loaded.read_bytes()==expected,rel
  manifest[rel.as_posix()]=sha(loaded)
 for name,source in [('target_driver.gd',E/'target_driver.gd'),('combat_stress_fixture.gd',ROOT/'test/combat_stress_fixture.gd'),('main.tscn',ROOT/'space-battleship/main.tscn'),('project.godot',ROOT/'space-battleship/project.godot')]:
  assert (project/name).read_bytes()==source.read_bytes(),name
  manifest[name]=sha(project/name)
 receipt['loaded_sources'][mode]={'manifest_sha256':hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest(),'key_sha256':{key:manifest[key] for key in ('scripts/native_execution_session.gd','scripts/main.gd','scripts/battlefield.gd','scripts/battle_slice_runtime.gd','target_driver.gd')},'script_count':len(manifest)}
 env=os.environ.copy();user=BASE/mode/'user'
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:env[key]=str(user/folder)
 env.update(PULSE_QA_MODE=mode,PULSE_QA_SCENARIO='baseline',SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 raw_file=E/f'display-sound-{mode}.json';log_file=E/f'display-sound-{mode}.log'
 if not raw_file.exists() or not log_file.exists():
  with log_file.open('w',encoding='utf8') as out:
   done=subprocess.run([str(GODOT),'--path',str(project),'--headless','--script','res://target_driver.gd'],env=env,stdout=out,stderr=subprocess.STDOUT,timeout=100)
  assert done.returncode==0,(mode,done.returncode)
  shutil.copy2(project/'.runtime/target.json',raw_file)
 log_file.write_bytes(log_file.read_bytes().replace(b'\r\n',b'\n'))
 log=log_file.read_text(encoding='utf8',errors='replace')
 assert 'ERROR:' not in log and 'SCRIPT ERROR' not in log,(mode,log[-2000:])
 receipt[mode]={'raw_sha256':sha(raw_file),'log_sha256':sha(log_file)}
a=json.loads((E/'display-sound-off.json').read_text(encoding='utf8'))
b=json.loads((E/'display-sound-on.json').read_text(encoding='utf8'))
assert len(a['traces'])==len(b['traces'])==45
columns=('anchors','turrets','contacts','effects','played_beeps')
receipt['compare']={column:[i for i,(x,y) in enumerate(zip(a['traces'],b['traces'])) if x[column]!=y[column]] for column in columns}
receipt['compare']['owned_on']=[i for i,row in enumerate(b['traces']) if row['owned']]
assert receipt['compare']['owned_on']
(E/'display-sound-receipt.json').write_bytes(json.dumps(receipt,indent=2).encode('utf8'))
print(json.dumps(receipt['compare'],indent=2))
