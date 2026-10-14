from pathlib import Path
import json,statistics,sys,gzip
root=Path(sys.argv[1]);out={}
for name in ['mixed','laser','cannon','missile','longLaser']:
 p=root/(name+'.json')
 if not p.exists() and not p.with_suffix('.json.gz').exists():continue
 raw=p.read_text(encoding='utf8') if p.exists() else gzip.decompress(p.with_suffix('.json.gz').read_bytes()).decode('utf8')
 d=json.loads(raw);v=sorted(d['frames_us_raw']);n=len(v)
 phases={}
 for key,a,b in [('post_to_main','previous_post_us','main_begin_us'),('main','main_begin_us','main_end_us'),('main_to_predraw','main_end_us','pre_draw_us'),('draw','pre_draw_us','post_draw_us')]:phases[key]=statistics.mean((x[b]-x[a])/1000 for x in d['phases'])
 row={'frames':n,'steps':d['sample_steps'],'mean_ms':statistics.mean(v)/1000,'p95_ms':v[min(n-1,int(n*.95))]/1000,'p99_ms':v[min(n-1,int(n*.99))]/1000,'actual_1x':d['actual_1x_pass'],'ratio':d['game_wall_ratio'],'sample_valid':d['performance_sample_valid'],'native_admitted':d['native_admitted'],'fires':d['fires'],'hits':d['hits'],'floats_mean':statistics.mean(d['floats_raw']),'pending_mean':statistics.mean(d['pending_raw']),'drawcalls_mean':statistics.mean(d['drawcalls_raw']),'wall_phase_means_ms':phases,'events':d['events']}
 if 'diagnostic_cost' in d:
  row['inclusive_cpu_ms_per_frame']={k:v['us']/n/1000 for k,v in d['diagnostic_cost'].items()}
  sr=d['shield_observation'];row['shield']={'frames':len(sr),'visible':sum(x['visible'] for x in sr),'positive_strength':sum(x['strength']>0 for x in sr),'visible_positive_strength':sum(x['visible'] and x['strength']>0 for x in sr),'hit_times':len(set(x['hit_at'] for x in sr if x['hit_at']>=0))}
 out[name]=row
(root/'summary.json').write_text(json.dumps(out,indent=2),encoding='utf8')
print(json.dumps(out,indent=2))
