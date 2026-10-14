from pathlib import Path
import os, subprocess, shutil, json
ROOT=Path(__file__).resolve().parents[4];E=Path(__file__).resolve().parent
ENGINE='D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
receipt=[]
for side in ['A','B']:
 project=ROOT/'test/work/laser-charge-perf'/side/'space-battleship'
 for src,dst in [('driver.gd','charge_aligned.gd'),('charge_audit.gd','charge_audit.gd')]:shutil.copy2(E/src,project/dst)
 p=project/'scripts/game.gd';s=p.read_text(encoding='utf-8')
 anchor='\t\tif state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():\n\t\t\tcontinue'
 replacement='\t\tif state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():\n\t\t\tpreload("res://charge_audit.gd").dropped.append({"step":preload("res://charge_audit.gd").step,"index":pending.index,"drone":pending.entry.get("drone_id",""),"old_level":pending.entry.level,"new_level":entry.get("level"),"snapshot_damage":pending.snapshot.damage})\n\t\t\tcontinue'
 assert s.count(anchor)==1;s=s.replace(anchor,replacement);p.write_text(s,encoding='utf-8')
 env=os.environ.copy();env.update(PERF_NATIVE='1',WEAPON_CASE='laser',PERF_SIDE=side)
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(ROOT/'test/work/laser-charge-aligned-users'/side/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 cmd=[ENGINE,'--path',str(project),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://charge_aligned.gd']
 with (E/(side+'.log')).open('w',encoding='utf-8') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240)
 receipt.append({'side':side,'command':cmd,'exit':r.returncode});(E/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
 text=(E/(side+'.log')).read_text(encoding='utf-8',errors='replace');print(side,r.returncode,text[-700:],flush=True)
 assert r.returncode==0 and 'SCRIPT ERROR' not in text
 shutil.copy2(project/'.runtime/charge-aligned.json',E/(side+'.json'))
