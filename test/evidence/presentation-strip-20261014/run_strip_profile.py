from pathlib import Path
import subprocess,os,sys
r=Path('D:/CodexBuild/space_idle/stable-integration');work=r/'test/work';iso=work/'battle-fix-20261013/space-battleship';env=os.environ.copy();env.update(APPDATA=str(work/'battle-fix-20261013/roaming'),LOCALAPPDATA=str(work/'battle-fix-20261013/local'),PERF_NATIVE='1')
for label,mode in [('PA',0),('PB',1),('PC',2),('PD',3)]:
 env.update(STRIP_CASE=label,STRIP_MODE=str(mode),STRIP_PROFILE='1')
 log=work/('strip-'+label+'.txt')
 with log.open('w',encoding='utf-8') as stream:
  result=subprocess.run(['D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe','--path',str(iso),'--rendering-method','gl_compatibility','--script','res://qa_strip_current.gd'],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=75)
 text=log.read_text(encoding='utf-8',errors='replace')
 if result.returncode or 'SCRIPT ERROR' in text or 'STRIP_RESULT' not in text:raise RuntimeError(label+' '+text[-1800:])
 print(next(l for l in text.splitlines() if 'STRIP_RESULT' in l),flush=True)
