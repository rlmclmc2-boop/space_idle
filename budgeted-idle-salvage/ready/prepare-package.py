"""Overlay the two QA files on the exact original 887-file 2d package; isolated import."""
import argparse,json,hashlib,shutil,os,subprocess
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);ap.add_argument('--target',type=Path,required=True);ap.add_argument('--godot',default='godot');a=ap.parse_args();here=Path(__file__).resolve().parent;p=a.target.resolve();old=json.loads((here/'source-manifest.json').read_text());m=json.loads((here/'qa-manifest.json').read_text());assert not p.exists();p.mkdir(parents=True)
for n,h in old['files'].items():
 src=a.source/n;dst=p/n;assert hashlib.sha256(src.read_bytes()).hexdigest()==h,n;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for n in ['hyperspace_player_policy.gd','hyperspace_checkpoint.gd']:shutil.copy2(here/n,p/'qa'/n)
shutil.copy2(here/'qa-manifest.json',p/'qa-manifest.json')
for n,h in m['files'].items():assert hashlib.sha256((p/n).read_bytes()).hexdigest()==h,n
saved={n:(p/n).read_bytes() for n in m['files'] if n.endswith('.import')};env=os.environ.copy()
for key,folder in [('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_CONFIG_HOME','config')]:
 d=p/'userdata'/'editor'/folder;d.mkdir(parents=True,exist_ok=True);env[key]=str(d)
with (p/'import.log').open('w') as log:r=subprocess.run([a.godot,'--headless','--editor','--path',str(p),'--import'],env=env,stdout=log,stderr=subprocess.STDOUT)
for n,b in saved.items():(p/n).write_bytes(b)
assert r.returncode==0
assert 'Parse Error:' not in (p/'import.log').read_text(errors='replace')
for n,h in m['files'].items():assert hashlib.sha256((p/n).read_bytes()).hexdigest()==h,n
(p/'.qa-import-complete.json').write_text(json.dumps({'project':str(p),'manifest_fingerprint':m['fingerprint']}));print('READY',p,m['fingerprint'])
