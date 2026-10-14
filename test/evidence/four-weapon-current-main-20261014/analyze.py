from pathlib import Path
import json,collections,bisect,statistics,math,gzip,sys
E=Path(__file__).resolve().parent
labels=sys.argv[1:] or ['laser','cannon','missile','longLaser']
def stat(a):
 a=sorted(a)
 return {'mean':statistics.mean(a),'median':statistics.median(a),'p95':a[math.ceil(.95*len(a))-1],'p99':a[math.ceil(.99*len(a))-1],'max':max(a)}
for label in labels:
 d=json.loads((E/(label+'.json')).read_text());frames=d['phases'];spans=d['probe']['spans'];N=len(frames)
 byid={int(r[0]):r for r in spans};children=collections.defaultdict(list)
 for r in spans:
  assert r[4]>=r[3]
  if r[1]>=0:
   parent=byid[int(r[1])];assert parent[3]<=r[3]<=r[4]<=parent[4];children[int(r[1])].append(r)
 names=['post_to_main','main','main_end_to_pre','pre_to_post'];keys=['previous_post_us','main_begin_us','main_end_us','pre_draw_us','post_draw_us']
 totals={p:collections.Counter() for p in names};phase_times={p:[] for p in names};residual={p:0 for p in names}
 ends=[f['post_draw_us'] for f in frames];buckets=collections.defaultdict(list)
 for r in spans:
  for i in range(bisect.bisect_left(ends,r[3]),N):
   if frames[i]['previous_post_us']>r[4]:break
   buckets[i].append(r)
 for i,f in enumerate(frames):
  ts=[f[k] for k in keys];assert ts==sorted(ts) and ts[-1]-ts[0]==d['frames_us_raw'][i]
  for index,p in enumerate(names):
   lo,hi=ts[index:index+2];phase_times[p].append((hi-lo)/1000);used=0
   def overlap(r):return max(0,min(hi,r[4])-max(lo,r[3]))
   for r in buckets[i]:
    value=overlap(r)-sum(overlap(c) for c in children[int(r[0])]);assert value>=0
    totals[p][r[2]]+=value;used+=value
   assert used<=hi-lo;residual[p]+=hi-lo-used
 load=json.loads((E/(label+'-system-load.json')).read_text());cpu=[r['system_cpu_busy_percent'] for r in load if d['sample_start_unix']<=r['unix']<=d['sample_end_unix'] and r.get('system_cpu_busy_percent') is not None]
 activity={k:stat([r[k] for r in d['activity_rows']]) for k in ['beams','links','chain_hops','prism_beams','endless_beams']}
 weapons=set(k for r in d['activity_rows'] for k in r['active_by_weapon'])
 activity['active_by_weapon']={k:stat([r['active_by_weapon'].get(k,0) for r in d['activity_rows']]) for k in weapons}
 row={'weapon':label,'source':'e7cc31e0','frames':N,'full_wall_ms':stat([v/1000 for v in d['frames_us_raw']]),'phases':{p:{'wall_ms':stat(phase_times[p]),'exclusive_ms_per_frame':{k:v/N/1000 for k,v in totals[p].most_common() if v},'unattributed_ms_per_frame':residual[p]/N/1000} for p in names},'closure_max_us':0,'logic_step_distribution':dict(collections.Counter(f['logic_steps'] for f in frames)),'warm_steps':d['warm_steps'],'sample_steps':d['sample_steps'],'game_seconds':d['game_seconds'],'wall_seconds':d['wall_seconds'],'game_wall_ratio':d['game_wall_ratio'],'actual_1x_pass':d['actual_1x_pass'],'limiter_and_focus_valid':d['performance_sample_valid'],'performance_sample_valid':d['performance_sample_valid'] and d['actual_1x_pass'],'focus_false_frames':sum(not x['window_focused'] for x in d['frame_trace']),'background_unfocused_frames':sum(x['unfocused'] for x in d['frame_trace']),'native_admitted':d['native_admitted'],'admission_error':d['native_admission_error'],'fires_by_weapon':d['fires_by_weapon'],'legendary_counts':d['legendary_counts'],'activity':activity,'work':{k:d[k] for k in ['fires','hits','purchases','handoffs','events','rng_state','enemies_alive']},'sampling_config':d['sampling_config'],'config_end':d['runtime_config_end'],'system_cpu_busy_percent':stat(cpu) if cpu else {},'system_cpu_samples':len(cpu),'probe_bookkeeping_us':d['probe']['bookkeeping_us'],'limits':['Instrumented single scenario, not AB; different weapon/effect work cannot be called optimization gain.','Exclusive callback wall time only; driver/GPU/OS waits remain unsplit.','Existing native compiler rejects unsupported legendary combinations; ordinary production GDS fallback retained, not new parallel world.','Held-health scene excludes kill/wave transition branches. Enabled and actually triggered effects are separate.','Counters and per-frame activity scan have overhead included in timing. No overhead subtraction.']}
 (E/(label+'-summary.json')).write_text(json.dumps(row,indent=2),encoding='utf8')
 print(label,'frames',N,'ms',row['full_wall_ms'],'1x',row['actual_1x_pass'],'valid',row['performance_sample_valid'],'legendary',row['legendary_counts'],'work',row['work'])
