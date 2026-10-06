#!/usr/bin/env python3
import json,pathlib,argparse,collections,math
p=argparse.ArgumentParser();p.add_argument('--root',required=True);p.add_argument('--snapshot',required=True);p.add_argument('--cached-actions',required=True);p.add_argument('--output',required=True);a=p.parse_args();root=pathlib.Path(a.root);source=json.loads((root/'source-inspection.json').read_text());initial=json.loads((root/'run/save_resumed.json').read_text());snap=json.loads(pathlib.Path(a.snapshot).read_text());end=snap['x1_seconds'];events=[]
for phase,path in [('native',root/'run/actions.jsonl'),('cached',pathlib.Path(a.cached_actions))]:
 for n,line in enumerate(path.read_text().splitlines(),1):
  try:r=json.loads(line)
  except json.JSONDecodeError:continue
  if r['x1_seconds']<=end+1e-6:events.append({'phase':phase,'line':n,'event':r})
counts=collections.Counter();domain=collections.Counter();forge=collections.Counter();credits=collections.Counter();deltas=collections.Counter();debits=collections.Counter();pending={};settled=set();claims=[];transactions=[];duplicates=[];errors=[]
for row in events:
 e=row['event'];counts[e['kind']]+=1
 if e['kind']=='space_feedback':
  reason=e['payload'].get('reason');active=e.get('active',{})
  if reason=='completed_pending' and active:
   key=(active['round_id'],active['run_id']);pending[key]=active
  if reason=='claimed':
   eligible=[(k,v) for k,v in pending.items() if k[0]==e['payload']['round_id']]
   if not eligible:errors.append({'kind':'claim_without_observed_pending','row':row})
   else:
    key,reward=max(eligible,key=lambda x:x[0][1]);pending.pop(key)
    if key in settled:duplicates.append(key)
    else:
     settled.add(key);credit=reward['reward'].get('materials',{});credits.update(credit);claims.append({'receipt':list(key),'at':e['x1_seconds'],'phase':row['phase'],'route':reward['route'],'level':reward['level'],'mode':reward['mode'],'ticket':reward['ticket'],'receipt_duration':reward['duration'],'materials':credit,'drone':reward['reward'].get('drone',{}),'cores':reward['reward'].get('ultimate_cores',0)})
 if e['kind']=='domain_action':
  ch=e['choice'];domain[ch['kind']]+=1
  if not e.get('ok'):errors.append({'kind':'failed_domain_transaction','row':row})
  if ch['kind']=='space_forge':
   op=ch['request']['operation'];forge[op]+=1;change={k:e['after']['materials'].get(k,0)-v for k,v in e['before']['materials'].items()};deltas.update(change)
   for k,v in change.items():
    if v<0:debits[k]+=-v
   transactions.append({'at':e['x1_seconds'],'phase':row['phase'],'operation':op,'id':ch['request']['drone_id'],'command_seq':ch['request']['command_seq'],'expected_revision':ch['request']['expected_revision'],'ok':e['ok'],'preview':ch['preview'],'material_delta':change,'raw_phase_line':row['line']})
for claim in claims:
 if claim['mode']=='manual':
  actual=[r['event'] for r in events if r['event']['kind']=='space_actual_result' and r['event'].get('success') and r['event']['route']==claim['route'] and int(r['event']['level'])==int(claim['level']) and abs(r['event']['end']-claim['at'])<1.0]
  if len(actual)==1:claim['actual_manual_seconds']=actual[0]['seconds'];claim['actual_manual_start']=actual[0]['start'];claim['actual_manual_end']=actual[0]['end']
  else:errors.append({'kind':'manual_claim_without_unique_observed_result','claim':claim})
old=initial['save']['hyperspace'];h=snap['save']['hyperspace'];expected={k:old['materials'][k]+credits[k]+deltas[k] for k in old['materials']};balance={k:{'initial':old['materials'][k],'claimed':credits[k],'forge_delta':deltas[k],'expected':expected[k],'actual':h['materials'][k],'match':expected[k]==h['materials'][k]} for k in expected}
c=source['controller'];d=snap['controller'];time_rows={};time_total=collections.Counter()
for stage in sorted(set(c['rows'])|set(d['rows']),key=int):
 row={k:d['rows'].get(stage,{}).get(k,0)-c['rows'].get(stage,{}).get(k,0) for k in ['travel','combat','retreat','clear_notice','other','clicks','checks','page_visits','growth_blocked_checks']}
 if any(abs(v)>1e-5 for v in row.values()):time_rows[stage]=row
 for k in ['travel','combat','retreat','clear_notice','other']:time_total[k]+=row[k]
metric={k:d[k]-c[k] for k in ['clicks','checks','visits','deaths','operation_seconds','space_seconds','farm_seconds']};logical=end-source['clock'];exclusive=sum(time_total.values())+metric['space_seconds']
fleet=[dict({'id':i},**h['inventory']['drones'][i]) for i in h['inventory']['equipped']]
out={'cutoff_x1':end,'source_x1':source['clock'],'source_cp_sha256':snap['source_cp_sha256'],'logical_delta':logical,'metrics_delta':metric,'exclusive_main_state_seconds':dict(time_total),'main_plus_space_seconds':exclusive,'exclusive_time_matches_delta':abs(exclusive-logical)<0.05,'overlap_warning':'operation_seconds is an overlapping input budget; farm_seconds covers safe_farm.phase != idle and overlaps main battle/travel. Do not sum these into exclusive wall/X1 time.','stage_rows_delta':time_rows,'event_counts':dict(counts),'domain_counts':dict(domain),'forge_counts':dict(forge),'claims':claims,'forge_transactions':transactions,'material_balance':balance,'all_material_balances_match':all(x['match'] for x in balance.values()),'duplicate_claims':duplicates,'errors':errors,'fleet':fleet,'modules':h['hanging_modules'],'frontier':snap['save']['highestLevel'],'journey':snap['save']['journey'],'round_clears':d['round_clears'],'reforges':d['refeeds'],'scope':'SourceCP-to-cutoff only; raw transaction receipts and actual profile balance; no guessed reward/payouts or hidden simulation.'}
pathlib.Path(a.output).write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps({k:out[k] for k in ['cutoff_x1','frontier','journey','logical_delta','metrics_delta','exclusive_main_state_seconds','exclusive_time_matches_delta','forge_counts','all_material_balances_match','errors']},ensure_ascii=False))
