from pathlib import Path
import json,collections,statistics,gzip,hashlib,shutil,subprocess
w=Path(__file__).parent;decoded=json.loads((w/'decoded-pair.json').read_text());arms={'original':Path('/workspace/sol-validation/unified-e528-post60-qa/diagnostics/sol-e528-cadence-original600'),'fixed':Path('/workspace/sol-validation/sparse-repeat-failure-qa/diagnostics/sol-sparse-repeat-failure600')};out=Path('/workspace/evidence-stage/hyperspace-closeout-20261006/sparse-repeat-failure-short600');out.mkdir(exist_ok=True)
res={}
for i,(name,d) in enumerate(arms.items()):
 cp=decoded[i];summary=json.loads((d/'longrun-summary.json').read_text());r=[json.loads(x) for x in (d/'actions.jsonl').read_bytes()[:int(cp['trace_bytes'])].splitlines()];ts=[x['x1_seconds'] for x in r if x['kind']=='tour_start'];salv=[x for x in r if x['kind']=='domain_action' and x.get('ok') and x['choice'].get('idle_salvage')];domains=[x for x in r if x['kind']=='domain_action'];native=collections.Counter(x.get('action_kind') for x in r if x['kind']=='click');success=sum(x.get('ok',False) for x in domains);c=cp['controller']
 res[name]={'checkpoint_x1':cp['x1_seconds'],'checkpoint_sha256':cp['sha256'],'trace_bytes':cp['trace_bytes'],'status':summary.get('status'),'input_failure':c['input_failure'],'script_errors':(d/'run.log').read_text().count('SCRIPT ERROR:'),'tour_starts':ts,'tour_intervals':[b-a for a,b in zip(ts,ts[1:])],'native_click_counts':dict(native),'counted_actions':sum(native.values())+sum(x['kind']=='page_visit' for x in r)+success,'page_visits':sum(x['kind']=='page_visit' for x in r),'checks':sum(x['kind']=='check' for x in r),'empty_checks':sum(x['kind']=='check' and not x['action_available'] for x in r),'domains_success':success,'domains_failed':len(domains)-success,'domain_counts':dict(collections.Counter(x['choice']['kind']+':'+str(x['choice'].get('request',{}).get('operation','')) for x in domains)),'idle_salvage_successes':[{'x1':x['x1_seconds'],'drone':x['choice']['request']['drone_id'],'budget':x['choice'].get('salvage_budget')} for x in salv],'max_idle_salvage_in_rolling_300_seconds':max((sum(0<=y['x1_seconds']-x['x1_seconds']<300 for y in salv) for x in salv),default=0),'tour_reactions':[x for x in r if x['kind']=='tour_reaction'],'stage':summary.get('stage'),'clear33':c['clears'].get('33'),'clear34':c['clears'].get('34'),'deaths':c['deaths']-333,'loadout':cp['save']['loadout'],'resources':cp['save']['resources'],'materials':cp['hyperspace']['materials'],'inventory_warehouse':cp['inventory']['warehouse'],'rng_state':cp['rng_state'],'active_manual':cp['hyperspace']['active'],'salvage_success_times':cp['space_policy'].get('idle_salvage_success_times'),'safe_farm_event_counts':dict(collections.Counter(x.get('action_kind') for x in r if x['kind']=='safe_farm_event')),'safe_farm_final':cp['safe_farm'],'wall_seconds':summary.get('wall_seconds')}
 arm=out/name;arm.mkdir(exist_ok=True)
 for f in d.iterdir():
  if not f.is_file():continue
  if f.suffix in ['.bin','.jsonl','.log'] or f.name.endswith('.previous') or f.name.startswith('save_'):
   with open(arm/(f.name+'.gz'),'wb') as z:
    with gzip.GzipFile(fileobj=z,mode='wb',mtime=0) as g:g.write(f.read_bytes())
  else:shutil.copy2(f,arm/f.name)
 assert hashlib.sha256((d/'checkpoint.bin').read_bytes()).hexdigest()==cp['sha256']
assert res['original']['checkpoint_x1']==res['fixed']['checkpoint_x1'];(out/'COMPARISON.json').write_text(json.dumps(res,indent=2)+'\n')
for f in w.iterdir():
 if f.is_file():
  if f.name=='decoded-pair.json':
   with open(out/(f.name+'.gz'),'wb') as z:
    with gzip.GzipFile(fileobj=z,mode='wb',mtime=0) as g:g.write(f.read_bytes())
  else:shutil.copy2(f,out/f.name)
for name in ['qa-manifest.json','.qa-import-complete.json']:shutil.copy2(Path('/workspace/sol-validation/sparse-repeat-failure-qa')/name,out/('fixed-'+name.lstrip('.')))
print(json.dumps(res,indent=2))
