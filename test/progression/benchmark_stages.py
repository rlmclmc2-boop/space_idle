"""Profile short same-save/RNG stages; compare exact UI variants with approximate no-scene combat."""
import argparse,hashlib,json,os,subprocess,time
from decimal import Decimal,localcontext
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--project',type=Path,required=True)
p.add_argument('--checkpoint',type=Path,required=True,help='save_*.json with save/x1_seconds/rng_state/code_fingerprint')
p.add_argument('--source-manifest',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--seconds',type=float,default=30)
p.add_argument('--modes',default='full,ui1s,minimal-vfx,headless')
p.add_argument('--scenarios',default='combat,idle-growth')
p.add_argument('--godot',default='godot')
p.add_argument('--timeout',type=int,default=180)
p.add_argument('--baseline-mode',help='Explicit paired reference; defaults full, then cached, then first requested mode')
p.add_argument('--resize-challenge',action='store_true',help='Resize at fixed logical boundaries and compare cached poses with fresh original calculation')
a=p.parse_args();mode_list=a.modes.split(',');baseline_mode=a.baseline_mode or ('full' if 'full' in mode_list else 'cached' if 'cached' in mode_list else mode_list[0])
if baseline_mode not in mode_list:raise SystemExit('Baseline mode must be requested')
project=a.project.resolve();out=a.output.resolve()
if out.exists():raise SystemExit('Preserve prior evidence; choose a new output')
if a.seconds<=0 or a.seconds*60>10_000_000:raise SystemExit('Positive bounded segment required')
old=json.loads(a.source_manifest.read_text());new=json.loads((project/'qa-manifest.json').read_text());source_bytes=a.checkpoint.read_bytes()
source_format='json'
if a.checkpoint.suffix=='.bin':
 header_bytes,payload=source_bytes.split(b'\n',1);source=json.loads(header_bytes);source_format='binary'
 if source.get('format')!=1 or source.get('bytes')!=len(payload) or source.get('sha256')!=hashlib.sha256(payload).hexdigest():raise SystemExit('Source checkpoint checksum mismatch')
else:source=json.loads(source_bytes)
for m in [old,new]:
 if hashlib.sha256(json.dumps(m['files'],sort_keys=True).encode()).hexdigest()!=m['fingerprint']:raise SystemExit('Manifest fingerprint invalid')
if source.get('code_fingerprint')!=old['fingerprint'] or (source_format=='json' and not isinstance(source.get('save'),dict)):raise SystemExit('Snapshot/source manifest identity mismatch')
production=lambda m:{k:v for k,v in m['files'].items() if not k.startswith('qa/')}
if production(old)!=production(new):raise SystemExit('Production/data differ: build a matching frozen package; no silent config migration')
for name,value in new['files'].items():
 if hashlib.sha256((project/name).read_bytes()).hexdigest()!=value:raise SystemExit('Frozen target changed: '+name)
if not (project/'.qa-import-complete.json').exists():raise SystemExit('Import the isolated package through run_entry first')
out.mkdir(parents=True);results=[]
for scenario in a.scenarios.split(','):
 if scenario not in {'combat','idle-growth'}:raise SystemExit('Unknown scenario')
 for mode in a.modes.split(','):
  if mode not in {'full','ui1s','minimal-vfx','headless','cached'}:raise SystemExit('Unknown mode')
  folder=out/(scenario+'-'+mode);folder.mkdir()
  request={'checkpoint':str(a.checkpoint.resolve()),'format':source_format,'seconds':a.seconds,'scenario':scenario,'mode':mode,'output':str(folder),'resize_challenge':a.resize_challenge,'source_manifest':str(a.source_manifest.resolve()),'source_fingerprint':old['fingerprint'],'target_fingerprint':new['fingerprint'],'data_sha256':new['files']['data/game_data.json'],'source_sha256':hashlib.sha256(a.checkpoint.read_bytes()).hexdigest(),'source_phase':{'highest':source.get('save',{}).get('highestLevel'),'round':source.get('save',{}).get('hyperspace',{}).get('round_id')}}
  rp=folder/'request.json';rp.write_text(json.dumps(request,indent=2));env=os.environ.copy();env['QA_STAGE_REQUEST']=str(rp)
  for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','APPDATA','LOCALAPPDATA']:
   f=folder/'userdata'/key;f.mkdir(parents=True);env[key]=str(f)
  start=time.perf_counter()
  with (folder/'run.log').open('w') as log:r=subprocess.run([a.godot,'--headless','--path',str(project),'--script','res://qa/stage_probe.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=a.timeout)
  if r.returncode or 'SCRIPT ERROR:' in (folder/'run.log').read_text():raise SystemExit('Probe failed: '+str(folder/'run.log'))
  result=json.loads((folder/'result.json').read_text());result['process_wall_seconds']=time.perf_counter()-start;results.append(result)
  print(f"{scenario} {mode}: {result['x1_per_wall']:.2f} X1/wall",flush=True)
def number(v):
 return Decimal(str(v['m']))*(Decimal(10)**int(v['e'])) if isinstance(v,dict) else Decimal(str(v))
def error(reference,variant):
 with localcontext() as ctx:
  ctx.prec=40
  x=number(reference);y=number(variant);absolute=abs(y-x)
  return {'reference':str(x),'variant':str(y),'signed_difference':str(y-x),'absolute_error':str(absolute),'relative_to_reference':str(absolute/abs(x)) if x else None,'zero_reference':not bool(x)}
def remaining(state,field):
 return sum((max(Decimal(0),number(e.get(field,0))) for e in state['enemies']),Decimal(0))
def outcome_error(reference,variant):
 if not reference or not variant:return {'available':False}
 result={'available':True,'numeric':{k:error(reference[k],variant[k]) for k in ['outgoing_hit_damage','incoming_hit_damage','outgoing_hits','incoming_hits','enemy_kills','wave_clears','defeats']},'net_resources_equal':reference['net_resource_change']==variant['net_resource_change'],'pending_drops_equal':reference['pending_drops']==variant['pending_drops'],'run_resources_equal':reference['run_resources']==variant['run_resources'],'new_cleared_equal':reference['new_cleared']==variant['new_cleared'],'final_battle_position_equal':all(reference[k]==variant[k] for k in ['final_stage','final_group','final_state'])}
 return result
comparisons=[]
for scenario in a.scenarios.split(','):
 baseline=next((r for r in results if r['mode']==baseline_mode and r['scenario']==scenario),None)
 if baseline is None:continue
 base=[json.loads(s) for s in (out/(scenario+'-'+baseline_mode)/'states.jsonl').read_text().splitlines()]
 for r in results:
  if r['scenario']!=scenario or r['mode']==baseline_mode:continue
  probe=[json.loads(s) for s in (out/(scenario+'-'+r['mode'])/'states.jsonl').read_text().splitlines()]
  diffs=[];health_errors=[]
  for x,y in zip(base,probe):
   keys=sorted(k for k in x['state'].keys()|y['state'].keys() if x['state'].get(k)!=y['state'].get(k))
   health_errors.append({'step':x['step'],'enemy_hp':error(remaining(x['state'],'hp'),remaining(y['state'],'hp')),'enemy_shield':error(remaining(x['state'],'shield'),remaining(y['state'],'shield')),'player_armour':error(x['state']['player']['armour'],y['state']['player']['armour']),'player_shield':error(x['state']['player']['shield'],y['state']['player']['shield'])})
   if keys:diffs.append({'step':x['step'],'fields':keys})
  comparisons.append({'scenario':scenario,'reference_mode':baseline_mode,'mode':r['mode'],'comparison_scope':'Approximate rough-screen error measurement; not acceptance' if 'headless' in [baseline_mode,r['mode']] else 'Presented state samples','sample_health_errors':health_errors,'outcome_errors':outcome_error(baseline.get('outcome'),r.get('outcome')),'outcome_reference':baseline.get('outcome'),'outcome_variant':r.get('outcome'),'samples':len(base),'exact_equal':not diffs and len(base)==len(probe),'first_mismatch':diffs[0] if diffs else None,'mismatched_samples':len(diffs),'speedup_over_reference':baseline['wall_seconds']/r['wall_seconds'],'final_rng_equal':r['final_rng']==baseline['final_rng']})
summary={'baseline_mode':baseline_mode,'comparison_status':'paired' if comparisons else 'unpaired: no comparison performed','source':str(a.checkpoint),'source_manifest':old['source_commit'],'target_commit':new['source_commit'],'results':results,'comparisons':comparisons,'scope':'Fixed1/60 passive stage probes. Same formal reload/profile/RNG, no new player actions. Idle-growth deliberately freezes combat only in isolated branches. Not native-input policy or full-campaign acceptance.'}
(out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(comparisons,indent=2))

if a.resize_challenge and (any(not c['exact_equal'] or not c['final_rng_equal'] for c in comparisons if c['mode']=='cached') or any(not r.get('resize_exact',False) for r in results if r['mode']=='cached')):raise SystemExit('Resize exactness failed; evidence retained')
