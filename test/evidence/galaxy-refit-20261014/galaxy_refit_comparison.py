from pathlib import Path
import subprocess,os,json,time,hashlib
r=Path('D:/CodexBuild/space_idle/stable-integration');work=r/'test/work/battle-fix-20261013';iso=work/'space-battleship'
names=['battle_slice_runtime.gd','galaxy_effect_aggregator.gd','galaxy_region.gd','galaxy_system.gd','game.gd','main.gd','native_execution_compiler.gd','native_execution_session.gd']
refs={'A':'cf9c10de','B':'fe27404e'};receipt={'refs':refs,'runs':[]}
try:
 for label in ['A1','B','A2']:
  for name in names:(iso/'scripts'/name).write_bytes(subprocess.check_output(['git','show',refs[label[0]]+':space-battleship/scripts/'+name],cwd=r))
  env=os.environ.copy();env.update(APPDATA=str(work/'roaming'),LOCALAPPDATA=str(work/'local'),PERF_NATIVE='1',GALAXY_CASE=label)
  started=time.time();log=work/('galaxy-refit-'+label+'.txt')
  with log.open('w',encoding='utf-8') as stream:
   proc=subprocess.run(['D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe','--path',str(iso),'--rendering-method','gl_compatibility','--script','res://qa_galaxy_refit_real.gd'],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=240)
  contents=log.read_text(encoding='utf-8',errors='replace')
  if proc.returncode or 'SCRIPT ERROR' in contents:raise RuntimeError(str(log)+' '+contents[-1600:])
  print(label,next((line for line in contents.splitlines() if 'GALAXY_REFIT' in line),'NO RESULT'),flush=True)
  output=iso/'.runtime'/('galaxy-refit-'+label+'.json')
  receipt['runs'].append({'label':label,'started':started,'finished':time.time(),'driver_sha256':hashlib.sha256((iso/'qa_galaxy_refit_real.gd').read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'dll_sha256':hashlib.sha256((iso/'bin/space_native.dll').read_bytes()).hexdigest()})
  (work/'galaxy-refit-receipt.json').write_text(json.dumps(receipt,indent=2))
finally:
 for name in names:(iso/'scripts'/name).write_bytes((r/'space-battleship/scripts'/name).read_bytes())
