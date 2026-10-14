from pathlib import Path
import json,statistics,math,collections
E=Path(__file__).resolve().parent

def stats(values):
 x=sorted(values)
 return {'count':len(x),'mean_ms':statistics.mean(x)/1000,'median_ms':statistics.median(x)/1000,'p95_ms':x[math.ceil(.95*len(x))-1]/1000,'p99_ms':x[math.ceil(.99*len(x))-1]/1000,'max_ms':max(x)/1000,'total_ms':sum(x)/1000}
report={'metric':'uncapped_qa_actual1x_full_wall_frame_v1','outer_interval':'previous post-draw resume to current post-draw resume; first starts at sample_start','phase_scope':'disjoint wall intervals, include synchronous driver/GPU and scheduling waits; not exclusive CPU','quantiles':'median middle values; p95/p99 nearest rank; no samples excluded','sides':{}}
for label in ['A','B']:
 d=json.loads((E/(label+'.json')).read_text(encoding='utf-8'))
 arrays={'main_callback':[],'main_end_to_pre_draw':[],'pre_to_post_draw':[],'post_to_next_main':[]}
 closure=[]
 groups=collections.defaultdict(list)
 for f,frame in zip(d['phases'],d['frames_us_raw']):
  values=[f['main_end_us']-f['main_begin_us'],f['pre_draw_us']-f['main_end_us'],f['post_draw_us']-f['pre_draw_us'],f['main_begin_us']-f['previous_post_us']]
  for key,value in zip(arrays,values):arrays[key].append(value)
  closure.append(sum(values)-frame);groups[f['logic_steps']].append(frame)
 side={k:d[k] for k in ['warm_steps','sample_steps','warm_game_seconds','game_seconds','warm_wall_seconds','wall_seconds','game_wall_ratio','actual_1x_pass','warm_fires','fires','warm_hits','hits','warm_purchases','purchases','handoffs','rng_state','kernel_metrics','runtime_config_start','runtime_config_end','window_focused','background_unfocused','video_adapter','rendering_method','enemy_supported']}
 side['full_wall_frame']=stats(d['frames_us_raw']);side['phases']={k:stats(v) for k,v in arrays.items()}
 side['phase_ms_per_logic_step']={k:sum(v)/1000/d['sample_steps'] for k,v in arrays.items()}
 side['cumulative_wall_ms_per_logic_step']=sum(d['frames_us_raw'])/1000/d['sample_steps']
 side['closure_max_abs_us']=max(abs(x) for x in closure);side['closure_total_us']=sum(closure)
 side['logic_steps_from_phases']=sum(f['logic_steps'] for f in d['phases'])
 side['steps_per_frame']={str(k):{'frames':len(v),'frame_stats':stats(v)} for k,v in sorted(groups.items())}
 side['stress_counts']=d['stress']['counts'];side['unfocused_frame_count']=sum(bool(x['unfocused']) for x in d['frame_trace'])
 for k in ['projectiles_raw','floats_raw','pending_raw','primitives_raw','drawcalls_raw']:side[k]={'sum_per_frame_observations':sum(d[k]),'mean':statistics.mean(d[k]),'max':max(d[k])}
 report['sides'][label]=side
A,B=[report['sides'][k] for k in ['A','B']]
report['B_minus_A_full_wall_ms']={k:B['full_wall_frame'][k]-A['full_wall_frame'][k] for k in ['mean_ms','median_ms','p95_ms','p99_ms','max_ms']}
report['B_minus_A_phase_mean_ms']={k:B['phases'][k]['mean_ms']-A['phases'][k]['mean_ms'] for k in A['phases']}
report['equal_workload']={k:A[k]==B[k] for k in ['warm_steps','sample_steps','warm_fires','fires','warm_hits','hits','warm_purchases','purchases','handoffs','rng_state','stress_counts','kernel_metrics']}
report['fixture_equal']=json.loads((E/'A.json').read_text())['stress']['config']==json.loads((E/'B.json').read_text())['stress']['config']
(E/'summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for label,s in report['sides'].items():
 print(label,json.dumps({k:s[k] for k in ['full_wall_frame','phases','warm_steps','sample_steps','fires','hits','purchases','game_wall_ratio','closure_max_abs_us','steps_per_frame']},indent=2))
print('DIFFERENCE',report['B_minus_A_full_wall_ms']);print('WORKLOAD',report['equal_workload'])
