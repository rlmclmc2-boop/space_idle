"""Build a minimal original-rule Godot QA project; no engine, secrets or player saves."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess
ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, required=True)
p.add_argument('--scene',action='store_true',help='Include formal scene dependencies for canonical muzzle/target integration')
p.add_argument('--data-ref', help='Use the exact game_data.json of a frozen ref with current QA code')
a = p.parse_args(); out=a.output.resolve(); source=ROOT/'space-battleship'
if out.exists(): raise SystemExit('Output exists; use a new directory to preserve evidence')
out.mkdir(parents=True)
classes={}
for f in (source/'scripts').glob('*.gd'):
 m=re.search(r'^class_name (\w+)',f.read_text(),re.M)
 if m: classes[m[1]]=f.relative_to(source).as_posix()
queue=['scripts/balance_game.gd','scripts/balance_database.gd','scripts/balance_autoplayer.gd','scripts/balance_metrics.gd','scripts/presented_battle_game.gd']; seen=set()
while queue:
 rel=queue.pop()
 if rel in seen: continue
 seen.add(rel); src=source/rel; content=src.read_text()
 dest=out/rel; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dest)
 for dep in re.findall(r'(?:preload|load)\("res://([^"\n]+\.gd)"\)',content):queue.append(dep)
 for name,dep in classes.items():
  if re.search(r'\b'+name+r'\b',content) and dep!=rel:queue.append(dep)
if a.scene:
 for folder in ['scripts','assets','addons','dev']:
  shutil.copytree(source/folder,out/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.blend','*.blend1','__pycache__'))
 for filename in ['main.tscn','level_editor.tscn']:shutil.copy2(source/filename,out/filename)
shutil.copytree(source/'data',out/'data')
if a.data_ref:
 (out/'data/game_data.json').write_bytes(subprocess.check_output(['git','show',a.data_ref+':space-battleship/data/game_data.json'],cwd=ROOT))
(out/'.runtime').mkdir(); (out/'qa').mkdir(); 
for script in Path(__file__).parent.glob('*.gd'):shutil.copy2(script,out/'qa'/script.name)
if a.scene:
 shutil.copy2(ROOT/'test/test_enemy_design_probe.gd',out/'qa/enemy_design_probe.gd')
# Same lab bookkeeping/caches, but inherit the actual battlefield's combat class.
# The generated adapter changes no gameplay method. Exact mode is mandatory.
adapter=(source/'scripts/balance_game.gd').read_text().replace('extends BattleGame','extends "res://scripts/presented_battle_game.gd"',1)
(out/'qa/presented_balance_game.gd').write_text(adapter)
if a.scene:
 project=(source/'project.godot').read_text()
 project=re.sub(r'config/name="[^"]*"','config/name="Progression QA isolated"',project)
 (out/'project.godot').write_text(project)
else:
 (out/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Progression QA isolated"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
manifest={'scene_dependencies':a.scene,'source_commit':commit,'data_ref':a.data_ref,'dirty':subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True),'files':{}}
for f in sorted(out.rglob('*')):
 if f.is_file():manifest['files'][f.relative_to(out).as_posix()]=hashlib.sha256(f.read_bytes()).hexdigest()
manifest['fingerprint']=hashlib.sha256(json.dumps(manifest['files'],sort_keys=True).encode()).hexdigest()
(out/'qa-manifest.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps({'package':str(out),'fingerprint':manifest['fingerprint'],'files':len(manifest['files'])}))
