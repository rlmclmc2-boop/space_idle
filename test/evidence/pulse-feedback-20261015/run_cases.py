"""Run fixed, targeted QA cases in prebuilt isolated D: projects."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess

E=Path(__file__).resolve().parent
ROOT=E.parents[2]
BASE=Path('D:/CodexBuild/space_idle/pulse-feedback-qa-20261015')
GODOT=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
DLL_SHA='483a7256e2d3946090515197a36fdd36122a74d4cae32acc7629f3cdaa6ce22f'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (E/'cases-receipt.json').exists()
receipt={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'dll_sha256':DLL_SHA,'driver_sha256':sha(E/'target_driver.gd')}
for mode in ('off','on'):
 project=BASE/mode/'space-battleship'
 assert sha(project/'bin/space_native.dll')==DLL_SHA
 gate=(project/'scripts/native_execution_session.gd').read_text(encoding='utf8')
 assert f'const PULSE_FEEDBACK_PROTOTYPE:={"true" if mode=="on" else "false"}' in gate
 shutil.copy2(E/'target_driver.gd',project/'target_driver.gd')
 env=os.environ.copy();user=BASE/mode/'user'
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:env[key]=str(user/folder)
 env.update(PULSE_QA_MODE=mode,SPACE_BATTLESHIP_PYTHON='D:/CodexTools/venv/godot-native/Scripts/python.exe')
 for scenario in ('baseline','transitions','death'):
  env['PULSE_QA_SCENARIO']=scenario
  prefix=f'{scenario}-{mode}'
  with (E/f'{prefix}.log').open('w',encoding='utf8') as output:
   done=subprocess.run([str(GODOT),'--path',str(project),'--headless','--script','res://target_driver.gd'],env=env,stdout=output,stderr=subprocess.STDOUT,timeout=100)
  content=(E/f'{prefix}.log').read_text(encoding='utf8',errors='replace')
  assert done.returncode==0 and 'SCRIPT ERROR' not in content and 'ERROR:' not in content,(prefix,done.returncode,content[-3000:])
  raw=project/'.runtime/target.json'
  assert raw.exists()
  shutil.copy2(raw,E/f'{prefix}.json')
  result=json.loads(raw.read_text(encoding='utf8'))
  assert result['mode']==mode and result['scenario']==scenario and result['gate']==(mode=='on') and not result['exit_paused'],prefix
  receipt[prefix]={'log_sha256':sha(E/f'{prefix}.log'),'raw_sha256':sha(E/f'{prefix}.json'),'traces':len(result['traces']),'owned_frames':sum(t['owned'] for t in result['traces'])}
numeric=('clock','fx_time','speed','damage_mode','accelerated','player','enemies','game_rng','kernel_rng','projectiles','history','floats','pending','native','paused')
for scenario in ('baseline','transitions','death'):
 a=json.loads((E/f'{scenario}-off.json').read_text(encoding='utf8'))
 b=json.loads((E/f'{scenario}-on.json').read_text(encoding='utf8'))
 assert len(a['traces'])==len(b['traces']) and len(a['traces'])>0
 mismatches=[(i,key) for i,(x,y) in enumerate(zip(a['traces'],b['traces'])) for key in numeric if x[key]!=y[key]]
 receipt[scenario+'_comparison']={'numeric_display_mismatches':mismatches,'steps':len(a['traces']),'history_full':max(len(x['history']) for x in b['traces'])==40}
 assert not mismatches,(scenario,mismatches[:10])
assert receipt['baseline-on']['owned_frames']>0
assert receipt['transitions-on']['owned_frames']>0
assert json.loads((E/'transitions-on.json').read_text(encoding='utf8'))['traces'][-1]['compatibility']
(E/'cases-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in receipt.items() if k.endswith('_comparison') or k.endswith('-on')},indent=2))
