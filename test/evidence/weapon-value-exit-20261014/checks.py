from pathlib import Path
import os,subprocess,shutil
ROOT=Path.cwd();WORK=ROOT/'test/work/battle-fix-20261013';ISO=WORK/'space-battleship';E=ROOT/'test/evidence/weapon-value-exit-20261014'
for p in (ROOT/'space-battleship/scripts').glob('*.gd'):shutil.copy2(p,ISO/'scripts'/p.name)
shutil.copy2(WORK/'numeric-update/candidate.dll',ISO/'bin/space_native.dll')
env=os.environ.copy();env['APPDATA']=str(WORK/'roaming');env['LOCALAPPDATA']=str(WORK/'local')
for name in ['test_upgrade_capacity_exit.gd','test_native_numeric_upgrade.gd','test_native_numeric_incremental.gd']:
 shutil.copy2(ROOT/'test'/name,ISO/'.runtime'/name)
 r=subprocess.run(['D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe','--headless','--path',str(ISO),'--script','res://.runtime/'+name],env=env,capture_output=True,text=True,timeout=60)
 (E/(name+'.txt')).write_text(r.stdout+r.stderr,encoding='utf8')
 print(name,r.returncode,r.stdout[-500:],r.stderr[-1500:],flush=True)
 assert r.returncode==0 and '0 failures' in r.stdout and 'SCRIPT ERROR' not in r.stderr
