from pathlib import Path
import json,math,statistics
E=Path(__file__).resolve().parent
report={"scope":"One ordered A/B only; all samples retained; no outlier exclusion; capped actual-1x full frame cadence, not uncapped CPU cost", "quantiles":"median=statistics.median; p95/p99=nearest rank ceil(p*n)-1", "sides":{}}
for label in ['A','B']:
 d=json.loads((E/(label+'.json')).read_text(encoding='utf-8'))
 raw=[x/1000 for x in d['frames_us_raw']];x=sorted(raw)
 stats={'n':len(x),'mean_ms':statistics.mean(x),'median_ms':statistics.median(x),'p95_ms':x[math.ceil(.95*len(x))-1],'p99_ms':x[math.ceil(.99*len(x))-1],'max_ms':max(x),'min_ms':min(x)}
 side={'frames':stats,'sample_steps':d['sample_steps'],'warm_steps':d['warm_steps'],'game_seconds':d['game_seconds'],'wall_seconds':d['wall_seconds'],'game_wall_ratio':d['game_wall_ratio'],'actual_1x_pass':d['actual_1x_pass'],'fires':d['fires'],'hits':d['hits'],'purchases':d['purchases'],'handoffs':d['handoffs'],'rng_state':d['rng_state'],'stress_counts':d['stress']['counts'],'all_enemies_supported':all(d['enemy_supported']),'enemy_count':len(d['enemy_supported']),'unfocused_frames':sum(bool(v['unfocused']) for v in d['frame_trace']),'window_focused':d['window_focused'],'runtime_config':d['runtime_config_end']}
 for key in ['projectiles_raw','floats_raw','pending_raw','drawcalls_raw','primitives_raw']:side[key]={'mean':statistics.mean(d[key]),'max':max(d[key])}
 report['sides'][label]=side
A,B=[report['sides'][x] for x in ['A','B']]
report['B_minus_A_ms']={k:B['frames'][k]-A['frames'][k] for k in ['mean_ms','median_ms','p95_ms','p99_ms','max_ms']}
report['workload_equal']={k:A[k]==B[k] for k in ['sample_steps','warm_steps','fires','hits','purchases','handoffs','rng_state','stress_counts','enemy_count']}
report['fixture_equal']=json.loads((E/'A.json').read_text())['stress']['config']==json.loads((E/'B.json').read_text())['stress']['config']
(E/'summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
