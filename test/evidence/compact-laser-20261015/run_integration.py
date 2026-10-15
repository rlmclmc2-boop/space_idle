from pathlib import Path
import hashlib, json, os, shutil, subprocess, time
ROOT=Path(__file__).resolve().parents[3]
E=Path(__file__).resolve().parent
PROJECT=Path('D:/CodexBuild/space_idle/compact-laser-perf-20261015/mixed/space-battleship')
ENGINE=Path('D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(PROJECT/'bin/space_native.dll')=='1f7a106abab612abc90192e761c247c4443a717212e3f135d0f84a71bc997bd5'
for file in ['scripts/game.gd','scripts/battlefield.gd','scripts/native_execution_session.gd','scripts/battle_slice_runtime.gd']:
 assert sha(PROJECT/file)==sha(ROOT/'space-battleship'/file),file
ATTEMPT=os.environ.get('INTEGRATION_ATTEMPT','1')
assert not (E/('integration-receipt-'+ATTEMPT+'.json')).exists(),'do not overwrite completed acceptance'
shutil.copy2(E/'integration_driver.gd',PROJECT/'integration_driver.gd')
receipt={'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'dll_sha256':sha(PROJECT/'bin/space_native.dll'),'engine_sha256':sha(ENGINE),'driver_sha256':sha(E/'integration_driver.gd'),'project_sha256':sha(PROJECT/'project.godot'),'production_files':{f:sha(PROJECT/f) for f in ['scripts/game.gd','scripts/battlefield.gd','scripts/native_execution_session.gd','scripts/battle_slice_runtime.gd']},'runs':[]}
def save():(E/('integration-receipt-'+ATTEMPT+'.json')).write_text(json.dumps(receipt,indent=2),encoding='utf8')
for mode in os.environ.get('INTEGRATION_MODES','waves,death').split(','):
 env=os.environ.copy();u=Path('D:/CodexBuild/space_idle/compact-laser-acceptance-20261015')/mode
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local'),('TEMP','tmp'),('TMP','tmp')]:
  env[key]=str(u/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 env['INTEGRATION_MODE']=mode
 for stem in ['integration-'+mode+'.json','integration-'+mode+'.png']+(['natural-death-entry.png'] if mode=='death' else []):
  output=PROJECT/'.runtime'/stem
  if output.exists():output.unlink()
 cmd=[str(ENGINE),'--path',str(PROJECT),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://integration_driver.gd']
 began=time.time()
 name='integration-'+mode+'-'+ATTEMPT
 with (E/(name+'.log')).open('w',encoding='utf8') as log:
  try:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120);code=r.returncode
  except subprocess.TimeoutExpired:code='timeout'
 run={'mode':mode,'exit':code,'wall_seconds':time.time()-began,'log_sha256':sha(E/(name+'.log'))}
 for ext,stem in [('json','integration-'+mode+'.json'),('png','natural-'+mode+'-end.png')]:
  src=PROJECT/'.runtime'/stem
  if src.exists():shutil.copy2(src,E/(name+'.'+ext));run[ext+'_sha256']=sha(E/(name+'.'+ext))
 if mode=='death':
  src=PROJECT/'.runtime'/'natural-death-entry.png'
  if src.exists():shutil.copy2(src,E/('natural-death-entry-'+ATTEMPT+'.png'));run['death_entry_png_sha256']=sha(E/('natural-death-entry-'+ATTEMPT+'.png'))
 receipt['runs'].append(run);save()
 print(mode,code,run.get('json_sha256'),flush=True)
 assert code==0 and 'json_sha256' in run and 'SCRIPT ERROR' not in (E/(name+'.log')).read_text(encoding='utf8',errors='replace'),f'{mode} run failed; preserve evidence'
 d=json.loads((E/(name+'.json')).read_text(encoding='utf8'))
 assert d['reason'] in ['coverage_endpoint','death_and_retreat_exit'],f'{mode} incomplete: {d["reason"]}'
