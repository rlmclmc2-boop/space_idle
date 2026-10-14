from pathlib import Path
import json,statistics,hashlib
E=Path(__file__).resolve().parent

def read(name):return json.loads((E/(name+'.json')).read_text(encoding='utf8'))
def percentile(values,p):
 values=sorted(values);at=(len(values)-1)*p;lo=int(at);hi=min(lo+1,len(values)-1)
 return (values[lo]+(values[hi]-values[lo])*(at-lo))/1000
rows={};raw={}
for label in ['Aordinary','Bordinary','Alegend','Blegend']:
 d=read(label);raw[label]=d;frames=d['frames_us_raw'];native=d['native_admitted']
 before=d['legend_counters_before'];after=d['legend_counters_after']
 source='native' if after['native'] else 'legacy'
 c1=after[source] if source=='native' else after[source]['counts'];c0=before[source] if source=='native' else before[source]['counts']
 counters={k:c1.get(k,0)-c0.get(k,0) for k in c1 if k!='targets' and isinstance(c1[k],(int,float))}
 phases={}
 for name,a,b in [('before_main','previous_post_us','main_begin_us'),('main','main_begin_us','main_end_us'),('before_render','main_end_us','pre_draw_us'),('render_to_post','pre_draw_us','post_draw_us')]:phases[name]=statistics.mean(f[b]-f[a] for f in d['phases'])/1000
 valid=d['performance_sample_valid'] and d['actual_1x_pass']
 assert d['probe_calls']['state_digest_calls']==2 and d['probe_calls']['counter_reads']==2 and d['probe_calls']['per_step_world_exports']==0 and d['probe_calls']['per_step_world_scans']==0
 legacy={k:after['legacy']['counts'].get(k,0)-before['legacy']['counts'].get(k,0) for k in ['legacy_jewel_attack','legacy_hit_enemy','legacy_tick_projectiles']}
 if native:assert not any(legacy.values())
 if label.endswith('legend'):
  assert counters['cache_firsts']+counters['cache_hits']==counters['missile_hits']
  assert counters['missile_hits']-counters['derived_hits']==counters['effective_layer_growth']
  assert counters['recursion_blocked_entries']==15*counters['wild_blasts']
  assert len(d['stress']['config']['totals']['legendary'])==2
 rows[label]={'mean_ms':statistics.mean(frames)/1000,'p50_ms':percentile(frames,.5),'p95_ms':percentile(frames,.95),'p99_ms':percentile(frames,.99),'frames':len(frames),'warm_steps':d['warm_steps'],'sample_steps':d['sample_steps'],'actual_1x_pass':d['actual_1x_pass'],'game_wall_ratio':d['game_wall_ratio'],'logic_hz':d['logic_hz'],'focus_and_unlimited_valid':d['performance_sample_valid'],'eligible_for_observed_comparison':valid,'native_admitted':native,'admission_error':d['native_admission_error'],'handoffs':d['handoffs'],'fires':d['fires'],'hits':d['hits'],'purchases':d['purchases'],'sample_counter_source':source,'sample_counters':counters,'legacy_callbacks':legacy,'phase_mean_ms':phases,'probe_calls':d['probe_calls'],'targets_at_end':after[source].get('targets',[]),'enemies_alive':d['enemies_alive']}
pairs={}
for group in ['ordinary','legend']:
 a=raw['A'+group];b=raw['B'+group]
 ca=a['stress']['config'];cb=b['stress']['config'];assert ca==cb,('configuration mismatch',group)
 eligible=rows['A'+group]['eligible_for_observed_comparison'] and rows['B'+group]['eligible_for_observed_comparison']
 delta=rows['A'+group]['mean_ms']-rows['B'+group]['mean_ms']
 pairs[group]={'configuration_equal':True,'configuration_sha256':hashlib.sha256(json.dumps(ca,sort_keys=True).encode()).hexdigest(),'sources':len(ca['combat_sources']),'enemies':ca['alive_enemies'],'legendary_effects':list(ca['totals']['legendary']),'eligible':eligible,'observed_mean_A_minus_B_ms':delta if eligible else None,'observed_0_5ms_gate':delta>=.5 if eligible else None,'interpretation':'single serial pair, counters included, no subtraction of probe wall time; not a repeated statistical estimate' if eligible else 'overload/invalid-side diagnostic only, no net saving estimate'}
result={'runs':rows,'pairs':pairs,'measurement_policy':'one ordinary pair and one full-legend pair only; state/counter endpoint reads occur outside sampled wall, all execution-site counting remains included; no per-step world export or observation scan; prior heavy-export group is coverage-only'}
(E/'comparison.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf8')
print(json.dumps({'pairs':pairs,'runs':{k:{x:v[x] for x in ['mean_ms','p50_ms','p95_ms','actual_1x_pass','game_wall_ratio','native_admitted','sample_counters','legacy_callbacks']} for k,v in rows.items()}},indent=2,ensure_ascii=False))
