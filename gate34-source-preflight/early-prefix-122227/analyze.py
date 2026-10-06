from pathlib import Path
import json,collections,statistics,hashlib,gzip,shutil
w=Path(__file__).parent;a,s=json.loads((w/'decoded.json').read_text());r=[json.loads(x) for x in (w/'actions.jsonl').read_bytes().splitlines()];entry=a['options']['qa34_entry_x1']
def analyze(rows):
 starts=[x['x1_seconds'] for x in rows if x['kind']=='tour_start'];intervals=[y-x for x,y in zip(starts,starts[1:])]
 tours=[];cur=None
 for x in rows:
  if x['kind']=='tour_start':cur={'start':x['x1_seconds'],'clicks':0,'domains':0,'paid_native_growth':0,'navigation':0,'checks':0}
  if cur is None:continue
  if x['kind']=='click':
   cur['clicks']+=1
   if x.get('action_kind') in ['upgrade_slot','scientist_max','reactor_max']:cur['paid_native_growth']+=1
  if x['kind']=='domain_action' and x.get('ok'):cur['domains']+=1
  if x['kind']=='page_visit':cur['navigation']+=1
  if x['kind']=='check':cur['checks']+=1
  if x['kind']=='tour_end':cur['end']=x['x1_seconds'];tours.append(cur);cur=None
 return {'kind_counts':dict(collections.Counter(x['kind'] for x in rows)),'native_click_kinds':dict(collections.Counter(x.get('action_kind') for x in rows if x['kind']=='click')),'tour_intervals':{'count':len(intervals),'median':statistics.median(intervals) if intervals else None,'min':min(intervals) if intervals else None,'max':max(intervals) if intervals else None,'below_300':sum(t<299.99 for t in intervals)},'completed_tours':tours,'tours_without_native_click_or_successful_domain':sum(x['clicks']==0 and x['domains']==0 for x in tours),'tours_without_paid_native_growth':sum(x['paid_native_growth']==0 for x in tours),'empty_checks':sum(x['kind']=='check' and not x.get('action_available') for x in rows),'successful_domains':sum(x['kind']=='domain_action' and x.get('ok') for x in rows),'failed_domains':sum(x['kind']=='domain_action' and not x.get('ok') for x in rows)}
first=[x for x in r if entry<=x['x1_seconds']<entry+3600]
salv=[x for x in r if x['kind']=='domain_action' and x.get('ok') and x['choice'].get('idle_salvage')]
maxroll=max((sum(0<=y['x1_seconds']-x['x1_seconds']<300 for y in salv) for x in salv),default=0)
# Segment endpoints reconstruct from shared source's open segment start; stored segments omit absolute timestamps.
old=len(s['controller']['segments']);t=s['controller']['segment_start'];segs=[]
for z in a['controller']['segments'][old:]:
 segs.append(dict(z,start=t,end=t+z['seconds']));t+=z['seconds']
result={'scope':'Complete immutable CP-aligned prefix; running process unchanged; not terminal 12h result','source_x1':s['x1_seconds'],'checkpoint_x1':a['x1_seconds'],'actual34_entry_x1':entry,'gate_end_x1':a['options']['duration'],'elapsed_main34_seconds':a['x1_seconds']-entry,'checkpoint_sha256':a['sha256'],'trace_bytes':a['trace_bytes'],'action_records':len(r),'business_records':sum(x['kind'] not in ['checkpoint_saved','checkpoint_resumed'] for x in r),'controller_deltas':{k:a['controller'].get(k,0)-s['controller'].get(k,0) for k in ['clicks','visits','checks','empty_checks','deaths','rejected_inputs']},'input_failure':a['controller']['input_failure'],'reforge_count':a['hyperspace'].get('reforge_count'),'reforge_checkpoint_pending':a['controller']['reforge_checkpoint_pending'],'all_prefix':analyze(r),'first_3600_after_main34':analyze(first),'safe_farm_event_counts':dict(collections.Counter(x.get('action_kind') for x in r if x['kind']=='safe_farm_event')),'idle_salvage_successes':[{'x1':x['x1_seconds'],'drone':x['choice']['request']['drone_id'],'budget':x['choice'].get('salvage_budget')} for x in salv],'max_idle_salvage_successes_in_rolling_300_seconds':maxroll,'new_segments':segs,'limitations':['Retreat events are not directly recorded in actions; controller death delta includes all actual retreats, visible_loadout_failure is a filtered actual-combat feedback subset.','Tour classification counts actions within start/end; domains outside a tour remain included in all-prefix counts.','Paid native growth means upgrade_slot/scientist_max/reactor_max button actions; it does not include resource pickup, allocations, hanging/forge costs or keyboard setup.']}
(w/'ANALYSIS.json').write_text(json.dumps(result,indent=2)+'\n')
out=Path('/workspace/evidence-stage/hyperspace-closeout-20261006/gate34-source-preflight/early-prefix-122227');out.mkdir(parents=True,exist_ok=True)
for name in ['checkpoint.bin','actions.jsonl','stage-states.jsonl','run.log','decoded.json']:
 with open(out/(name+'.gz'),'wb') as f:
  with gzip.GzipFile(fileobj=f,mode='wb',mtime=0) as z:z.write((w/name).read_bytes())
for name in ['heartbeat.json','run.json','ANALYSIS.json','analyze.py']:shutil.copy2(w/name,out/name)
print(json.dumps({k:v for k,v in result.items() if k not in ['all_prefix','first_3600_after_main34','new_segments']},indent=2))
for label in ['all_prefix','first_3600_after_main34']:
 v=result[label];print(label,json.dumps({k:x for k,x in v.items() if k!='completed_tours'}))
