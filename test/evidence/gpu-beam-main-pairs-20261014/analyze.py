from pathlib import Path
import json,statistics,collections,math
E=Path(__file__).resolve().parent
labels=['A1','B1','B2','A2','A3','B3']
raw={x:json.loads((E/(x+'.json')).read_text(encoding='utf8')) for x in labels}
def stats(values):
 a=sorted(values)
 return {'mean':statistics.mean(a),'median':statistics.median(a),'p95':a[max(0,math.ceil(.95*len(a))-1)],'p99':a[max(0,math.ceil(.99*len(a))-1)],'max':max(a)}
def scrub(v):
 if isinstance(v,dict):return {k:scrub(x) for k,x in v.items() if k!='kernel_hash' and not(k=='seed' and v.get('class')=='RandomNumberGenerator')}
 if isinstance(v,list):return [scrub(x) for x in v]
 return v
cases={};reference=raw['A1'];differences=[]
for label,d in raw.items():
 times={name:[] for name in ['main','main_end_to_pre','pre_to_post','post_to_main']};closures=[]
 for f,whole in zip(d['phases'],d['frames_us_raw']):
  t=[f[k] for k in ['previous_post_us','main_begin_us','main_end_us','pre_draw_us','post_draw_us']]
  assert t==sorted(t)
  values=[t[i+1]-t[i] for i in range(4)]
  for name,v in zip(['post_to_main','main','main_end_to_pre','pre_to_post'],values):times[name].append(v/1000)
  closures.append(whole-sum(values))
 assert not any(closures)
 checks={k:scrub(d[k])==scrub(reference[k]) for k in ['state_before','state_after','events','rng_state','kernel_metrics','fires','hits','purchases','handoffs']}
 for k,ok in checks.items():
  if not ok:differences.append([label,k])
 loads=json.loads((E/(label+'-system-load.json')).read_text())
 cpu=[r['system_cpu_busy_percent'] for r in loads if d['sample_start_unix']<=r['unix']<=d['sample_end_unix'] and r.get('system_cpu_busy_percent') is not None]
 cases[label]={'full_wall_ms':stats([v/1000 for v in d['frames_us_raw']]),'phases_ms':{k:stats(v) for k,v in times.items()},'frames':len(d['phases']),'logic_step_distribution':dict(collections.Counter(f['logic_steps'] for f in d['phases'])),'warm_steps':d['warm_steps'],'sample_steps':d['sample_steps'],'game_seconds':d['game_seconds'],'wall_seconds':d['wall_seconds'],'game_wall_ratio':d['game_wall_ratio'],'actual_1x_pass':d['actual_1x_pass'],'work':{k:d[k] for k in ['fires','hits','purchases','handoffs','rng_state','events','beam_metrics_before','beam_metrics_after','gpu_beams_enabled']},'equivalence':checks,'closure_max_abs_us':max(abs(v) for v in closures),'system_cpu_busy_percent':stats(cpu) if cpu else {},'system_cpu_samples':len(cpu),'unfocused_frames':sum(bool(x['unfocused']) for x in d['frame_trace']),'all_15_retained':len(d['enemy_supported'])==15 and all(d['enemy_supported']),'config_start':d['runtime_config_start'],'config_end':d['runtime_config_end']}
pairs=[]
for a,b in [('A1','B1'),('A2','B2'),('A3','B3')]:
 pairs.append({'A':a,'B':b,'A_minus_B_full_ms':{k:cases[a]['full_wall_ms'][k]-cases[b]['full_wall_ms'][k] for k in ['mean','median','p95','p99','max']},'A_minus_B_phase_mean_ms':{k:cases[a]['phases_ms'][k]['mean']-cases[b]['phases_ms'][k]['mean'] for k in times}})
result={'protocol':json.loads((E/'protocol.json').read_text()),'cases':cases,'pairs':pairs,'mean_paired_gain_ms':statistics.mean(x['A_minus_B_full_ms']['mean'] for x in pairs),'state_or_work_differences':differences,'equivalence_note':'Compare complete canonical state before/after and events. Exclude only RNG seed metadata and derived kernel_hash; actual RNG state retained. Kernel metrics separately compared.','limits':['Exactly three paired groups; no runs dropped or repeated.','Four disjoint wall spans close every frame. GPU/driver/OS waits not separated; not exclusive CPU busy timings.','GPU beam sync, transforms, uniform uploads and fallback work remain inside measured main-end-to-pre; GPU execution/wait remains in full cycle. No component subtraction used as net gain.','System CPU telemetry includes the game and all other processes, sampled every0.5s; cannot quantify external-only load or assign a slow frame to another process.','Canonical snapshots and screenshots are outside sampled timing window. Per-frame trace and passive sampler perturbation shared by both sides.','No priority/affinity/power/background process changes.']}
(E/'comparison.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print('mean paired gain',result['mean_paired_gain_ms'],'differences',differences)
for label,c in cases.items():print(label,c['frames'],c['full_wall_ms'],'CPU',c['system_cpu_busy_percent'])
print('pairs',json.dumps(pairs,indent=2))
