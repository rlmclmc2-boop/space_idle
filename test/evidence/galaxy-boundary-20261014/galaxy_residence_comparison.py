from pathlib import Path
import subprocess,os,json,time,hashlib
r=Path('D:/CodexBuild/space_idle/stable-integration');a=r/'test/work/battle-fix-20261013';iso=a/'space-battleship'
names=['galaxy_region.gd','galaxy_system.gd','game.gd','native_execution_compiler.gd','battle_slice_runtime.gd'];refs={'A':'720a533f','B':'1f2b40da'};receipt={'refs':refs,'runs':[]}
try:
 for label in ['A1','B','A2']:
  for name in names:(iso/'scripts'/name).write_bytes(subprocess.check_output(['git','show',refs[label[0]]+':space-battleship/scripts/'+name],cwd=r))
  env=os.environ.copy();env.update(APPDATA=str(a/'roaming'),LOCALAPPDATA=str(a/'local'),PERF_NATIVE='1',GALAXY_CASE=label)
  started=time.time()
  log=a/('galaxy-residence-final-'+label+'.log')
  with (a/('galaxy-residence-final-'+label+'-console.log')).open('w',encoding='utf-8') as stream:
   subprocess.run(['D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe','--path',str(iso),'--rendering-method','gl_compatibility','--script','res://qa_galaxy_residence.gd','--log-file',str(log)],env=env,check=True,timeout=120,stdout=stream,stderr=subprocess.STDOUT)
  contents=log.read_text(encoding='utf-8',errors='replace')
  if 'SCRIPT ERROR' in contents:raise RuntimeError('script error; abort remaining comparison: '+str(log))
  print(label, next((line for line in contents.splitlines() if 'GALAXY_RESIDENCE' in line),'NO RESULT'),flush=True)
  output=iso/'.runtime'/('galaxy-residence-'+label+'.json')
  receipt['runs'].append({'label':label,'started':started,'finished':time.time(),'driver_sha256':hashlib.sha256((iso/'qa_galaxy_residence.gd').read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'dll_sha256':hashlib.sha256((iso/'bin/space_native.dll').read_bytes()).hexdigest()})
  (a/'galaxy-residence-receipt.json').write_text(json.dumps(receipt,indent=2))
finally:
 for name in names:(iso/'scripts'/name).write_bytes((r/'space-battleship/scripts'/name).read_bytes())
