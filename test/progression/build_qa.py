"""Build a minimal original-rule Godot QA project; no engine, secrets or player saves."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess
ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(); out=a.output.resolve(); source=ROOT/'space-battleship'
if out.exists(): raise SystemExit('Output exists; use a new directory to preserve evidence')
out.mkdir(parents=True)
classes={}
for f in (source/'scripts').glob('*.gd'):
 m=re.search(r'^class_name (\w+)',f.read_text(),re.M)
 if m: classes[m[1]]=f.relative_to(source).as_posix()
queue=['scripts/balance_game.gd','scripts/balance_database.gd','scripts/balance_autoplayer.gd','scripts/balance_metrics.gd']; seen=set()
while queue:
 rel=queue.pop()
 if rel in seen: continue
 seen.add(rel); src=source/rel; content=src.read_text()
 dest=out/rel; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dest)
 for dep in re.findall(r'(?:preload|load)\("res://([^"\n]+\.gd)"\)',content):queue.append(dep)
 for name,dep in classes.items():
  if re.search(r'\b'+name+r'\b',content) and dep!=rel:queue.append(dep)
shutil.copytree(source/'data',out/'data')
(out/'qa').mkdir(); shutil.copy2(Path(__file__).with_name('progression_probe.gd'),out/'qa/progression_probe.gd')
(out/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Progression QA isolated"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
manifest={'source_commit':commit,'dirty':subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True),'files':{}}
for f in sorted(out.rglob('*')):
 if f.is_file():manifest['files'][f.relative_to(out).as_posix()]=hashlib.sha256(f.read_bytes()).hexdigest()
manifest['fingerprint']=hashlib.sha256(json.dumps(manifest['files'],sort_keys=True).encode()).hexdigest()
(out/'qa-manifest.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps({'package':str(out),'fingerprint':manifest['fingerprint'],'files':len(manifest['files'])}))
