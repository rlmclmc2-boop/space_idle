"""Explicit P1 v7 -> v8 QA upgrade; never alter production or silently bypass resume checks."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-checkpoint',type=Path,required=True)
p.add_argument('--source-manifest',type=Path,required=True)
p.add_argument('--target-project',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--godot',default='godot')
a=p.parse_args()
old=json.loads(a.source_manifest.read_text());target=a.target_project.resolve();new=json.loads((target/'qa-manifest.json').read_text())
known={'qa/hyperspace_player_policy.gd':'4ca02554319aa5c16a18bd417287da0a20fa84c46139745a16252935c5f67edf','qa/hyperspace_longrun.gd':'ccc4abf619dcd7c045bbdabe73d30c276777c391ac2466473825d0ed388db394','qa/hyperspace_checkpoint.gd':'20404138c8618c6e5ee6d76f2c335f2eb88a3b12305c77a2bb6bb2d896735ed2'}
added={'qa/upgrade_policy_checkpoint.gd','qa/test_manual_policy.gd'}
def verify_manifests(old,new,target):
 for m in [old,new]:
  if hashlib.sha256(json.dumps(m['files'],sort_keys=True).encode()).hexdigest()!=m['fingerprint']:raise ValueError('Manifest fingerprint does not match its files')
 if any(old['files'].get(k)!=v for k,v in known.items()):raise ValueError('Source is not the verified P1 v7 QA version')
 differing={k for k in old['files'].keys()|new['files'].keys() if old['files'].get(k)!=new['files'].get(k)}
 if not differing<=known.keys()|added or any(k in old['files'] for k in added):raise ValueError('Unapproved production/data/other QA change: '+str(sorted(differing-known.keys()-added)))
 if old['files'].get('data/game_data.json')!='95ed3347bc031c9f55468ad3536f71dc58dbb83874ef40882d3d9bcc8a14556e':raise ValueError('Source is not P1 formal data')
 for name,expected in new['files'].items():
  if hashlib.sha256((target/name).read_bytes()).hexdigest()!=expected:raise ValueError('Target package changed: '+name)
 return sorted(differing)
try:changed=verify_manifests(old,new,target)
except (ValueError,KeyError,OSError) as e:raise SystemExit(str(e))
if a.output.exists() or a.output.with_name(a.output.name+'.previous').exists():raise SystemExit('Output exists; preserve it and choose a new path')
selected=None;failures=[]
for candidate in [a.source_checkpoint,a.source_checkpoint.with_name(a.source_checkpoint.name+'.previous')]:
 try:
  with candidate.open('rb') as f:header=json.loads(f.readline());payload=f.read()
  if header.get('format')!=1 or header.get('bytes')!=len(payload) or header.get('sha256')!=hashlib.sha256(payload).hexdigest():raise ValueError('format/checksum mismatch')
  if header.get('code_fingerprint')!=old['fingerprint']:raise ValueError('Checkpoint/source manifest identity mismatch')
  selected=candidate;break
 except (OSError,ValueError) as e:failures.append(str(candidate)+': '+str(e))
if selected is None:raise SystemExit('No valid source checkpoint: '+str(failures))
a.output.parent.mkdir(parents=True,exist_ok=True)
request={'source_checkpoint':str(selected.resolve()),'requested_checkpoint':str(a.source_checkpoint.resolve()),'source_manifest':str(a.source_manifest.resolve()),'output':str(a.output.resolve()),'changed_files':changed,'fallback_failures':failures}
request_path=a.output.with_name(a.output.name+'.request.json');request_path.write_text(json.dumps(request,indent=2))
env=os.environ.copy();env['QA_POLICY_UPGRADE_REQUEST']=str(request_path.resolve())
for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','APPDATA','LOCALAPPDATA']:
 folder=a.output.parent/'upgrade-userdata'/key;folder.mkdir(parents=True,exist_ok=True);env[key]=str(folder.resolve())
log=a.output.with_name(a.output.name+'.upgrade.log')
with log.open('w') as f:r=subprocess.run([a.godot,'--headless','--path',str(target),'--script','res://qa/upgrade_policy_checkpoint.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
if r.returncode or 'SCRIPT ERROR:' in log.read_text() or 'Parse Error:' in log.read_text():raise SystemExit('Upgrade failed; inspect '+str(log))
print('Explicit QA policy upgrade written: '+str(a.output))
