"""Explicit reviewed production-candidate transition, never an unchanged resume."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=Path,required=True)
p.add_argument('--source-manifest',type=Path,required=True)
p.add_argument('--target-project',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--source-library-identity',type=Path,required=True)
p.add_argument('--godot',default='godot')
a=p.parse_args();target=a.target_project.resolve();old=json.loads(a.source_manifest.read_text());new=json.loads((target/'qa-manifest.json').read_text())
marker=target/'.qa-import-complete.json'
if not marker.exists():raise SystemExit('Target must complete its own run_entry editor import before conversion')
imported=json.loads(marker.read_text())
if imported.get('project')!=str(target) or imported.get('manifest_fingerprint')!=new['fingerprint']:raise SystemExit('Target import marker does not match this immutable package')
known={'54c98562adfa41adbefb89016c313223ca5034cc4253af7ba6a11d31fb7c1b3e':'frozen v17 UI candidate','32db3f1523ba58719f34fc48c1e40e6eb8fc1524c65003c488ed542c12201395':'frozen v16 reasonable QA','0f151fb5c8461aa0cf8d40c182078fd2e41a384b645f4423231ba0cddf850f8f':'frozen v15 production plus fast QA','b61b08d5410b42b4c0a2a23ec8047c500c58f305bbb4febd4d05adab3ea25c36':'verified ee fast-QA old production','6cfb7ec81f61bca2753a2cba2d73b192df545f627c6c39c8f8eb7889d8f61001':'frozen v14 production'}
for m in [old,new]:
 if hashlib.sha256(json.dumps(m['files'],sort_keys=True).encode()).hexdigest()!=m['fingerprint']:raise SystemExit('Manifest digest rejected')
if old['fingerprint'] not in known:raise SystemExit('Source is not a registered frozen candidate; review its exact manifest before registering')
if old['files']['data/game_data.json']!=new['files']['data/game_data.json']:raise SystemExit('Numeric data change rejected; requires a separate explicit transition')
for name,expected in new['files'].items():
 if hashlib.sha256((target/name).read_bytes()).hexdigest()!=expected:raise SystemExit('Target immutable file changed: '+name)
identity=json.loads(a.source_library_identity.read_text())
if not identity.get('library_file_id') or not identity.get('file_id'):raise SystemExit('Exact materialized Library identity required')
if a.output.exists():raise SystemExit('Output exists; choose a new path')
raw=a.source.read_bytes();legacy=raw.lstrip().startswith(b'{') and b'\n' not in raw[:raw.find(b'}')+1]
# JSON snapshots can be pretty printed; distinguish the checksum packet header.
try:obj=json.loads(raw);legacy=isinstance(obj,dict) and isinstance(obj.get('save'),dict)
except (ValueError,UnicodeDecodeError):legacy=False
if legacy:
 if obj.get('code_fingerprint')!=old['fingerprint']:raise SystemExit('Legacy snapshot/source manifest identity mismatch')
else:
 try:header_line,payload=raw.split(b'\n',1);h=json.loads(header_line)
 except (ValueError,UnicodeDecodeError):raise SystemExit('Invalid checkpoint packet')
 if h.get('format')!=1 or h.get('bytes')!=len(payload) or h.get('sha256')!=hashlib.sha256(payload).hexdigest() or h.get('code_fingerprint')!=old['fingerprint']:raise SystemExit('Checkpoint checksum/identity rejected')
a.output.parent.mkdir(parents=True,exist_ok=True)
changes=[{'path':k,'source':old['files'].get(k),'target':new['files'].get(k)} for k in sorted(old['files'].keys()|new['files'].keys()) if old['files'].get(k)!=new['files'].get(k)]
request={'source':str(a.source.resolve()),'source_sha256':hashlib.sha256(raw).hexdigest(),'source_manifest':str(a.source_manifest.resolve()),'source_library_identity':identity,'source_fingerprint':old['fingerprint'],'target_fingerprint':new['fingerprint'],'output':str(a.output.resolve()),'legacy':legacy,'changes':changes}
rp=a.output.with_name(a.output.name+'.request.json');rp.write_text(json.dumps(request,ensure_ascii=False,indent=2));env=os.environ.copy();env['QA_CANDIDATE_TRANSITION']=str(rp.resolve())
for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','APPDATA','LOCALAPPDATA']:
 folder=a.output.parent/'transition-userdata'/key;folder.mkdir(parents=True,exist_ok=True);env[key]=str(folder.resolve())
log=a.output.with_name(a.output.name+'.transition.log')
with log.open('w') as f:r=subprocess.run([a.godot,'--headless','--path',str(target),'--script','res://qa/transition_candidate.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
text=log.read_text()
if r.returncode or 'SCRIPT ERROR:' in text or 'ERROR:' in text:raise SystemExit('Candidate transition rejected; inspect '+str(log))
print('Explicit production candidate transition:',a.output)
