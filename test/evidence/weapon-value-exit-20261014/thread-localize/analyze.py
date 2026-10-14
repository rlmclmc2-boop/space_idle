from pathlib import Path
import json,gzip,statistics,collections,math
P=Path(__file__).resolve().parent
names=['diag-A','diag-B'];stages=[('pre_main_gap','previous','main_start'),('main','main_start','main_end'),('after_main_before_render','main_end','pre_draw'),('render_submit_wait','pre_draw','post_draw'),('frame','previous','post_draw')]
def stat(v):
 if not v:return {}
 s=sorted(v);return {'n':len(v),'mean':statistics.mean(v),'median':statistics.median(v),'p95':s[min(len(s)-1,int(len(s)*.95))],'max':max(v),'sum':sum(v)}
def clean(v):
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k!='kernel_hash' and not(k=='seed' and v.get('class')=='RandomNumberGenerator')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
raw={n:json.load(gzip.open(P/(n+'.json.gz'),'rt',encoding='utf8')) for n in names};out={'runs':{},'equivalence':{},'limits':['One frozen diagnostic A/B, not acceptance. Probe changes timing; does not replace/delete original three pairs.','QueryThreadCycleTime is raw execution cycle count, never converted to ms. Changes in cycles versus wall do not alone identify scheduling, CPU frequency or engine waits.','GetThreadTimes values stored in100ns units; observed increments determine granularity. Frame/stage CPU-ms attribution is not claimed exact.','Micro regions include native/GDScript probe overhead; empty calibration and baseline empty probes bound attribution. Binding region measures existing search plus helper, not just added function dispatch.','Render-submit/wait is wall and main-thread cycles between pre/post draw; renderer/driver thread CPU not isolated.']}
for name,d in raw.items():
 freq=d['probe_info']['qpc_frequency'];tid=d['probe_info']['calling_thread_id'];marks=json.loads((P/('cpu-'+name+'.json')).read_text());assert d['probe_info']['process_id']==marks['pid']
 assert d['gpu_beams_enabled'] is False and d['damage_cache_enabled'] is False and d['steps']==d['native_steps']==240
 prev=0;bound=[];rows=[];allcpu=[];invalid=[]
 for i,(sample,elapsed) in enumerate(zip(d['samples'],d['frames_us'])):
  step=sample['step']-prev
  if any(prev<b<=sample['step'] for b in [60,120,180,240]):bound.append(i)
  prev=sample['step'];t=sample['thread']
  for stamp in t.values():assert stamp[3]==tid and stamp[4]==0
  ordered=[t[k] for k in ['previous','signal','main_start','main_end','pre_draw','post_draw']]
  if any(a[0]>b[0] or a[1]>b[1] or a[2]>b[2] for a,b in zip(ordered,ordered[1:])):invalid.append(i)
  allcpu.extend(b[2]-a[2] for a,b in zip(ordered,ordered[1:]) if b[2]>a[2])
  phases={s:{'wall_ms':(t[b][0]-t[a][0])*1000/freq,'cycles':t[b][1]-t[a][1],'accounted_cpu_100ns':t[b][2]-t[a][2]} for s,a,b in stages}
  micro=[]
  for j,v in enumerate(sample['micro']):
   assert v[3]==0
   micro.append({'id':j,'count':v[0],'wall_ms':v[1]*1000/freq,'cycles':v[2]})
  rows.append({'index':i,'logic_step':sample['step'],'logic_steps_in_frame':step,'wall_ms':elapsed/1000,'phases':phases,'micro':micro})
 following=[i+1 for i in bound if i+1<len(rows)];ordinary=[i for i in range(len(rows)) if i not in bound+following]
 def aggregate(ids):
  return {'frames':len(ids),'wall_ms':stat([rows[i]['wall_ms'] for i in ids]),'phase':{s:{metric:stat([rows[i]['phases'][s][metric] for i in ids]) for metric in ['wall_ms','cycles','accounted_cpu_100ns']} for s,a,b in stages},'micro':{str(k):{'count':sum(rows[i]['micro'][k]['count'] for i in ids),'wall_ms':sum(rows[i]['micro'][k]['wall_ms'] for i in ids),'cycles':sum(rows[i]['micro'][k]['cycles'] for i in ids)} for k in range(5)}}
 cal=d['calibration'][4];calibration={'pairs':cal[0],'span_wall_us_per_pair':cal[1]*1e6/freq/cal[0],'span_cycles_per_pair':cal[2]/cal[0],'whole_loop_wall_us_per_pair':(d['calibration_end'][0]-d['calibration_start'][0])*1e6/freq/cal[0],'whole_loop_cycles_per_pair':(d['calibration_end'][1]-d['calibration_start'][1])/cal[0]}
 result={'probe_info':d['probe_info'],'all_stamps_same_windows_thread':True,'nonmonotonic_frame_indices':invalid,'GetThreadTimes_positive_increments_100ns':dict(collections.Counter(allcpu)),'accounting_increment_gcd_100ns':math.gcd(*allcpu),'calibration':calibration,'process_cpu_ms':None if marks['cpu_us'] is None else marks['cpu_us']/1000,'thread_accounted_cpu_total_ms':(d['samples'][-1]['thread']['post_draw'][2]-d['samples'][0]['thread']['previous'][2])/10000,'all':aggregate(list(range(len(rows)))),'ordinary':aggregate(ordinary),'ordinary_by_logic_steps':{str(n):aggregate([i for i in ordinary if rows[i]['logic_steps_in_frame']==n]) for n in sorted(set(r['logic_steps_in_frame'] for r in rows))},'ordinary_by_quarter':{str(q+1):aggregate([i for i in ordinary if q*60<rows[i]['logic_step']<=(q+1)*60]) for q in range(4)},'boundaries':bound,'following':following,'rows':rows}
 out['runs'][name]=result
 out['equivalence'][name]={k:clean(d[k])==clean(raw['diag-A'][k]) for k in ['before','after','state_before','state_after','events']}
 reference=json.load(gzip.open(P.parent/'final'/('A1.json.gz' if name=='diag-A' else 'B1.json.gz'),'rt',encoding='utf8'))
 out['equivalence'][name]['prior_acceptance_state_events']=all(clean(d[k])==clean(reference[k]) for k in ['before','after','state_before','state_after','events'])
assert all(all(x.values()) for x in out['equivalence'].values())
(P/'analysis.json').write_text(json.dumps(out,indent=2),encoding='utf8')
for name,r in out['runs'].items():
 print(name,'tid',r['probe_info'],'bad',r['nonmonotonic_frame_indices'],'CPU quantum',r['accounting_increment_gcd_100ns'],'calibration',r['calibration'],'CPU total',r['thread_accounted_cpu_total_ms'])
 for step,row in r['ordinary_by_logic_steps'].items():
  print('steps',step,'n',row['frames'],'wall',row['wall_ms'].get('mean'),'phases', {s:{k:round(v.get('mean',0),3) for k,v in data.items()} for s,data in row['phase'].items()},'micro',row['micro'])
