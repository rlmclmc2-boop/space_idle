#!/usr/bin/env python3
import argparse,hashlib,json,pathlib,subprocess,os
p=argparse.ArgumentParser();p.add_argument('--project',required=True);p.add_argument('--source',required=True);p.add_argument('--output',required=True);p.add_argument('--godot',default='godot');a=p.parse_args();r=pathlib.Path(__file__).parent;project=pathlib.Path(a.project)
w=json.loads((r/'closed-whitelist.json').read_text());old=json.loads((r/'source-manifest.json').read_text());target=json.loads((r/'target-manifest.json').read_text());actual=json.loads((project/'qa-manifest.json').read_text())
assert actual==target and old['source_commit']==w['source_commit']
for manifest in [old,target]:
 canonical=json.dumps(manifest['files'],sort_keys=True).encode()
 assert hashlib.sha256(canonical).hexdigest()==manifest['fingerprint']
d={k:{'old':old['files'].get(k),'new':target['files'].get(k)} for k in sorted(old['files'].keys()|target['files'].keys()) if old['files'].get(k)!=target['files'].get(k)}
assert d==w['changes']
# Godot may regenerate import metadata, but source/code/data/assets must match.
import_delta=[]
for name,digest in target['files'].items():
 observed=hashlib.sha256((project/name).read_bytes()).hexdigest()
 if observed!=digest:
  assert name.endswith('.import'),name
  import_delta.append({'path':name,'expected':digest,'observed':observed})
assert hashlib.sha256(pathlib.Path(a.source).read_bytes()).hexdigest()==w['source_sha256']
(project/'qa/convert_strong.gd').write_bytes((r/'convert.gd').read_bytes())
env=os.environ.copy();isolation=pathlib.Path(a.output).parent/'converter-userdata';env.update({k:str(isolation/k) for k in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']})
subprocess.run([a.godot,'--headless','--path',str(project),'--script','res://qa/convert_strong.gd','--',a.source,str(r/'closed-whitelist.json'),str(r/'target-manifest.json'),a.output],env=env,check=True)
pathlib.Path(a.output+'.physical-audit.json').write_text(json.dumps({'all_immutable_files_match':True,'import_metadata_deltas':import_delta},indent=2))
