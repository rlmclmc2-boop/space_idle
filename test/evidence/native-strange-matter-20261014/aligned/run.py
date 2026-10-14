from pathlib import Path
import os, subprocess, shutil, json, sys
ROOT=Path(__file__).resolve().parents[4];E=Path(__file__).resolve().parent
ENGINE='D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
receipt=json.loads((E/'receipt.json').read_text()) if (E/'receipt.json').exists() else []
for side in (sys.argv[1:] or ['A','B']):
 project=ROOT/'test/work/strange-matter-perf'/side/'space-battleship'
 for src,dst in [('driver.gd','strange_aligned.gd'),('strange_audit.gd','strange_audit.gd')]:shutil.copy2(E/src,project/dst)
 if 'preload("res://strange_audit.gd")' not in (project/'scripts/game.gd').read_text(encoding='utf8'):
  p=project/'scripts/game.gd';s=p.read_text(encoding='utf-8')
  anchor='\t\tif state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():\n\t\t\tcontinue'
  replacement='\t\tif state != State.COMBAT or not is_same(entry, pending.entry) or str(entry.key).is_empty():\n\t\t\tpreload("res://strange_audit.gd").dropped.append({"step":preload("res://strange_audit.gd").step,"index":pending.index,"drone":pending.entry.get("drone_id",""),"old_level":pending.entry.level,"new_level":entry.get("level"),"snapshot_damage":pending.snapshot.damage})\n\t\t\tcontinue'
  assert s.count(anchor)==1;s=s.replace(anchor,replacement);p.write_text(s,encoding='utf-8')
  p=project/'scripts/drone_combat_effects.gd';s=p.read_text(encoding='utf8')
  anchor='func on_hit(g,enemy: Dictionary,raw,context: Dictionary) -> void:'
  # Signature is located and matched from source, no production mutation.
  lines=s.splitlines();signature=next(line for line in lines if line.startswith('func on_hit('))
  s=s.replace(signature,signature+'\n\tpreload("res://strange_audit.gd").legacy_hit(enemy,raw,context)',1)
  anchor='\t\t\tfor i in count:delayed.append('
  assert s.count(anchor)==1
  s=s.replace(anchor,'\t\t\tpreload("res://strange_audit.gd").trigger(g,enemy,raw,context,count)\n'+anchor)
  lines=s.splitlines();index=next(i for i,line in enumerate(lines) if line.startswith('\t\t\tfor i in count:delayed.append('))
  lines.insert(index+1,'\t\t\tfor i in count:preload("res://strange_audit.gd").packet(delayed[delayed.size()-count+i])')
  s='\n'.join(lines)+'\n';s=s.replace('\t\tdelayed.erase(pending)','\t\tpreload("res://strange_audit.gd").due_packet(pending)\n\t\tdelayed.erase(pending)')
  p.write_text(s,encoding='utf8')
  p=project/'scripts/native_execution_session.gd';s=p.read_text(encoding='utf8')
  anchor='\tif not kernel.advance(dt):';assert s.count(anchor)==1
  s=s.replace(anchor,'\tpreload("res://strange_audit.gd").before_native(game,kernel,dt)\n'+anchor)
  anchor='\tgame.native_step_phase="native_done"';assert s.count(anchor)==1
  s=s.replace(anchor,'\tpreload("res://strange_audit.gd").after_native(kernel)\n'+anchor)
  anchor='\tfor row in kernel.take_feedback():';assert s.count(anchor)==1
  s=s.replace(anchor,anchor+'\n\t\tpreload("res://strange_audit.gd").native_row(row)')
  p.write_text(s,encoding='utf8')
 env=os.environ.copy();env['TEMP']=str(ROOT/'test/work/strange-aligned-tmp');env['TMP']=env['TEMP'];Path(env['TEMP']).mkdir(exist_ok=True);env.update(PERF_NATIVE='1',WEAPON_CASE='cannon',PERF_SIDE=side)
 for key,folder in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
  env[key]=str(ROOT/'test/work/strange-matter-aligned-users'/side/folder);Path(env[key]).mkdir(parents=True,exist_ok=True)
 cmd=[ENGINE,'--path',str(project),'--rendering-method','gl_compatibility','--max-fps','0','--disable-vsync','--script','res://strange_aligned.gd']
 with (E/(side+'.log')).open('w',encoding='utf-8') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240)
 receipt.append({'side':side,'command':cmd,'exit':r.returncode});(E/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
 text=(E/(side+'.log')).read_text(encoding='utf-8',errors='replace');print(side,r.returncode,text[-700:],flush=True)
 assert r.returncode==0 and 'SCRIPT ERROR' not in text
 shutil.copy2(project/'.runtime/strange-aligned.json',E/(side+'.json'))
