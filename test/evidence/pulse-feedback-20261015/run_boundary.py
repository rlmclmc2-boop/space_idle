"""Pending-feedback exit/handoff and same-frame cap, same isolated candidate DLL."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess

E=Path(__file__).resolve().parent; ROOT=E.parents[2]
BASE=Path('D:/CodexBuild/space_idle/pulse-feedback-qa-20261015')
GODOT=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL_SHA='483a7256e2d3946090515197a36fdd36122a74d4cae32acc7629f3cdaa6ce22f'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
receipt={'candidate':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'dll_sha256':DLL_SHA,'boundary_driver_sha256':sha(E/'boundary_driver.gd'),'loaded_sources':{}}
for mode in ('off','on'):
 project=BASE/mode/'space-battleship'
 assert sha(project/'bin/space_native.dll')==DLL_SHA
 shutil.copy2(E/'boundary_driver.gd',project/'boundary_driver.gd')
 manifest={}
 for source in sorted((ROOT/'space-battleship/scripts').rglob('*.gd')):
  rel=source.relative_to(ROOT/'space-battleship'); loaded=project/rel
  expected=source.read_bytes()
  if rel.as_posix()=='scripts/native_execution_session.gd' and mode=='on':
   expected=expected.replace(b'const PULSE_FEEDBACK_PROTOTYPE:=false',b'const PULSE_FEEDBACK_PROTOTYPE:=true')
  assert loaded.read_bytes()==expected,rel
  manifest[rel.as_posix()]=sha(loaded)
 for name,source in [('boundary_driver.gd',E/'boundary_driver.gd'),('combat_stress_fixture.gd',ROOT/'test/combat_stress_fixture.gd'),('main.tscn',ROOT/'space-battleship/main.tscn'),('project.godot',ROOT/'space-battleship/project.godot')]:
  assert (project/name).read_bytes()==source.read_bytes(),name
  manifest[name]=sha(project/name)
 receipt['loaded_sources'][mode]={'manifest_sha256':hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest(),'script_count':len(manifest),'session_sha256':manifest['scripts/native_execution_session.gd']}
 env=os.environ.copy();user=BASE/mode/'user'
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:env[key]=str(user/folder)
 env.update(PULSE_QA_MODE=mode,SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 for action in ('close','handoff','cap'):
  env['PULSE_QA_ACTION']=action;key=f'{action}-{mode}'
  raw_file=E/f'boundary-{key}.json';log_file=E/f'boundary-{key}.log'
  if not raw_file.exists() or not log_file.exists():
   with log_file.open('w',encoding='utf8') as out:
    done=subprocess.run([str(GODOT),'--path',str(project),'--headless','--script','res://boundary_driver.gd'],env=env,stdout=out,stderr=subprocess.STDOUT,timeout=100)
   assert done.returncode==0,(key,done.returncode)
   shutil.copy2(project/'.runtime/boundary.json',raw_file)
  log_file.write_bytes(log_file.read_bytes().replace(b'\r\n',b'\n'))
  log=log_file.read_text(encoding='utf8',errors='replace')
  assert 'ERROR:' not in log and 'SCRIPT ERROR' not in log,(key,log[-2000:])
  data=json.loads((E/f'boundary-{key}.json').read_text(encoding='utf8'))
  assert data['action']==action and data['mode']==mode
  receipt[key]={'raw_sha256':sha(E/f'boundary-{key}.json'),'log_sha256':sha(E/f'boundary-{key}.log'),'fresh_fire':data['fresh_fire'],'before_owned':data['before']['owned'],'before_pending':data['before']['pending'],'after_owned':data['after']['owned'],'after_pending':data['after']['pending'],'after_total_visuals':data['after']['visual_reservations']+data['after']['ordinary_visuals']}
for action in ('close','handoff','cap'):
 a=json.loads((E/f'boundary-{action}-off.json').read_text(encoding='utf8'))
 b=json.loads((E/f'boundary-{action}-on.json').read_text(encoding='utf8'))
 columns=('history','anchors','contacts','turrets','effects','played_beeps','paused','game_rng','player','active_flights')
 if action!='cap':columns+=('history_main',)
 mismatches=[column for column in columns if a['after'][column]!=b['after'][column]]
 receipt[action+'_comparison']={'after_mismatches':mismatches,'off_after':{'owned':a['after']['owned'],'pending':a['after']['pending']},'on_before':{'owned':b['before']['owned'],'pending':b['before']['pending']},'on_after':{'owned':b['after']['owned'],'pending':b['after']['pending']},'fresh_fire_on':b['fresh_fire'],'played_beeps_on':len(b['after']['played_beeps'])}
 assert b['before']['owned'] and b['before']['pending'] and not b['after']['pending'],action
 assert not b['after']['paused'] and not mismatches,(action,mismatches)
 if action=='close':
  assert b['close_ok'] and not b['after']['owned'] and not b['after_tree_free']['paused'] and not b['after_tree_free']['owned'] and not b['after_tree_free']['pending']
 if action=='handoff':assert b['handoff_ok'] and not b['after']['native_alive']
 if action=='cap':
  assert b['publish_ok'] and b['after']['owned'] and b['fresh_fire']>=2 and b['after']['visual_reservations']+b['after']['ordinary_visuals']==256
  assert a['after']['visual_reservations']+a['after']['ordinary_visuals']==256
(E/'boundary-receipt.json').write_bytes(json.dumps(receipt,indent=2).encode('utf8'))
print(json.dumps({k:v for k,v in receipt.items() if k.endswith('_comparison') or k=='cap-on'},indent=2))
