"""Native P2 same-checkpoint segments: profile fixed ticks and validate decision-UI/pose-cache variants."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--project',type=Path,required=True)
p.add_argument('--checkpoint',type=Path,required=True)
p.add_argument('--source-manifest',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--seconds',type=float,default=60)
p.add_argument('--modes',default='full,decision-ui,cached')
p.add_argument('--godot',default='godot')
p.add_argument('--timeout',type=int,default=600)
a=p.parse_args();project=a.project.resolve();out=a.output.resolve()
if out.exists():raise SystemExit('Choose a new output; preserve evidence')
old=json.loads(a.source_manifest.read_text());target=json.loads((project/'qa-manifest.json').read_text())
for m in [old,target]:
 if hashlib.sha256(json.dumps(m['files'],sort_keys=True).encode()).hexdigest()!=m['fingerprint']:raise SystemExit('Manifest identity mismatch')
continuity={'early_page_route.gd','hyperspace_player_policy.gd','hyperspace_safe_farm.gd','player_input.gd','presented_balance_game.gd'}
for name,value in old['files'].items():
 if not name.startswith('qa/') or name.removeprefix('qa/') in continuity:
  if target['files'].get(name)!=value:raise SystemExit('Production/data/policy mismatch: '+name)
if old['files'].get('qa/scene_driver.gd')!='8a509c9d77e53c892bb1799dd62e9e7c74cdd87fd19120bd8cd72982d2d45154' and not (old['fingerprint']==target['fingerprint'] and old['files'].get('qa/scene_driver.gd')==target['files'].get('qa/scene_driver.gd')):raise SystemExit('Unverified source driver version')
for name,value in target['files'].items():
 if hashlib.sha256((project/name).read_bytes()).hexdigest()!=value:raise SystemExit('Target frozen file changed: '+name)
header_bytes,payload=a.checkpoint.read_bytes().split(b'\n',1);header=json.loads(header_bytes)
if header.get('format')!=1 or header.get('bytes')!=len(payload) or header.get('sha256')!=hashlib.sha256(payload).hexdigest() or header.get('code_fingerprint')!=old['fingerprint']:raise SystemExit('Source checkpoint identity/checksum mismatch')
if a.seconds<=0:raise SystemExit('Positive interval required')
out.mkdir(parents=True);results=[];comparisons=[]
for mode in a.modes.split(','):
 if mode not in {'full','decision-ui','cached'}:raise SystemExit('Unknown mode')
 folder=out/mode;folder.mkdir();branch=folder/'stage-checkpoint.bin'
 request={'source_manifest':str(a.source_manifest.resolve()),'checkpoint':str(a.checkpoint.resolve()),'mode':mode,'output':str(branch)}
 rp=folder/'prepare.json';rp.write_text(json.dumps(request,indent=2));env=os.environ.copy();env['QA_STAGE_PREPARE']=str(rp);env['QA_STAGE_MODE']=mode
 for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','APPDATA','LOCALAPPDATA']:
  q=folder/'prepare-userdata'/key;q.mkdir(parents=True);env[key]=str(q)
 with (folder/'prepare.log').open('w') as f:r=subprocess.run([a.godot,'--headless','--path',str(project),'--script','res://qa/prepare_stage_checkpoint.gd'],stdout=f,stderr=subprocess.STDOUT,env=env,timeout=60)
 if r.returncode or 'SCRIPT ERROR:' in (folder/'prepare.log').read_text():raise SystemExit('Stage branch rejected: '+str(folder/'prepare.log'))
 options=folder/'options.json';options.write_text(json.dumps({'duration':header['x1_seconds']+a.seconds,'wall_limit_seconds':a.timeout-10,'stop_clear':0}))
 label='stage-'+out.name+'-'+mode
 cmd=['python3',str(Path(__file__).with_name('run_entry.py')),'--project',str(project),'--entry','res://qa/stage_campaign.gd','--label',label,'--godot',a.godot,'--skip-import','--resume',str(branch),'--longrun-options',str(options),'--timeout',str(a.timeout)]
 start=time.perf_counter()
 with (folder/'runner.log').open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=a.timeout+10)
 diag=project/'diagnostics'/label
 if r.returncode:raise SystemExit('Stage failed: '+str(diag/'run.log'))
 result=json.loads((diag/'stage-performance.json').read_text());result['diagnostics']=str(diag);result['process_wall_seconds']=time.perf_counter()-start
 result['complete_interval']=result['x1_seconds']+1e-6>=a.seconds
 results.append(result);print(f"{mode}: {result['wall_seconds']:.3f}s wall for {result['x1_seconds']:.3f}s X1 = {result['x1_per_wall']:.3f}x",flush=True)
base=next((r for r in results if r['mode']=='full'),None)
if base:
 x=[json.loads(s) for s in (Path(base['diagnostics'])/'stage-states.jsonl').read_text().splitlines()]
 def actions(r):
  return [s for s in (Path(r['diagnostics'])/'actions.jsonl').read_text().splitlines() if json.loads(s)['kind'] in {'click','page_visit','domain_action','visible_loadout_decision','visible_loadout_failure','manual_visible_budget_check'}]
 for r in results:
  if r is base:continue
  y=[json.loads(s) for s in (Path(r['diagnostics'])/'stage-states.jsonl').read_text().splitlines()];diffs=[]
  for lhs,rhs in zip(x,y):
   changed=sorted(k for k in lhs['state'].keys()|rhs['state'].keys() if lhs['state'].get(k)!=rhs['state'].get(k))
   if changed:diffs.append({'step':lhs['step'],'fields':changed})
  comparisons.append({'mode':r['mode'],'samples':len(x),'exact_state_equal':len(x)==len(y) and not diffs,'first_mismatch':diffs[0] if diffs else None,'mismatched_samples':len(diffs),'native_actions_equal':actions(base)==actions(r),'speedup':base['wall_seconds']/r['wall_seconds'],'final_rng_equal':base['final_rng']==r['final_rng']})
summary={'source_checkpoint':str(a.checkpoint),'source_sha256':hashlib.sha256(a.checkpoint.read_bytes()).hexdigest(),'source_x1':header['x1_seconds'],'source_manifest':old,'target_manifest':target,'results':results,'comparisons':comparisons,'scope':'Explicit same-production/data/P2 policy stage branch; formal battle regeneration, no grants/chrono/dt changes. Real native input/controller and cannon/missile/beam/drone/rail providers retained. Approximate headless combat is a separate passive probe.'}
(out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(comparisons,indent=2))
if any(not r['complete_interval'] for r in results) or any(not c['exact_state_equal'] or not c['native_actions_equal'] for c in comparisons):raise SystemExit('Native stage interval incomplete or exact invariants failed; evidence retained')
