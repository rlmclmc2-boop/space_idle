from pathlib import Path
import json,statistics,hashlib
E=Path(__file__).resolve().parent
raw={key:json.loads((E/(key+'.json')).read_text(encoding='utf-8')) for key in ['A','B']}
def pct(values,p):
 v=sorted(values);x=(len(v)-1)*p;i=int(x);j=min(i+1,len(v)-1);return (v[i]+(v[j]-v[i])*(x-i))/1000
rows={}
for key,d in raw.items():
 frames=d['frames_us_raw'];before=d['state_before'];after=d['state_after'];events=d['events']
 b={int(r['serial']):r for r in before['beam_state'] if not r['hostile']};a={int(r['serial']):r for r in after['beam_state'] if not r['hostile']}
 ticks=sum(r['ticks']-b.get(i,{}).get('ticks',0) for i,r in a.items())
 primary=sum(not r['repeated'] for r in a.values());repeat=len(a)-primary
 legacy={name:d['legend_counters_after']['legacy'].get(name,0)-d['legend_counters_before']['legacy'].get(name,0) for name in ['jewel_attack','hit_enemy','tick_projectiles']}
 observed=events.get('friendly_periods',0);secondary=events.get('enhancement_secondary',0);enemy_hits=events.get('enemy_hits',0)
 chain=enemy_hits-observed-secondary
 rows[key]={'mean_ms':statistics.mean(frames)/1000,'p95_ms':pct(frames,.95),'p99_ms':pct(frames,.99),'frames':len(frames),'sample_steps':d['sample_steps'],'warm_steps':d['warm_steps'],'actual_1x_pass':d['actual_1x_pass'],'game_wall_ratio':d['game_wall_ratio'],'logic_hz':d['logic_hz'],'focused_uncapped_vsync0':d['performance_sample_valid'],'native':d['native_admitted'],'admission_error':d['native_admission_error'],'handoffs':d['handoffs'],'events':events,'full_run_events':d['stress']['counts'],'legacy_callbacks':legacy,'beam_state_before':list(b.values()),'beam_state_after':list(a.values()),'active_friendly_beams':len(a),'primary_beams':primary,'repeat_beams':repeat,'actual_periods':observed,'endpoint_tick_delta':ticks,'periods_from_nonretained_beams':observed-ticks,'same_live_serials':set(b)==set(a),'chain_hits_by_accounting':chain,'chain_accounting':'enemy hit events minus friendly beam period events minus secondary hit events; held-health all-friendly-beam fixture, no deaths or other damage carriers','purchases':d['purchases'],'warm_purchases':d['warm_purchases'],'upgrade_batches':len(d['purchase_trace']),'qualification_slot_before':before['endless_source_slot'],'qualification_slot_after':after['endless_source_slot'],'rng_before':before['game_rng'],'rng_after':after['game_rng'],'probe_calls':d['probe_calls'],'enemies_alive':d['enemies_alive']}
 assert d['probe_calls']['state_digest_calls']==2 and d['probe_calls']['counter_reads']==2
 assert d['probe_calls']['per_step_world_exports']==0 and d['probe_calls']['per_step_world_scans']==0
 assert primary==13 and d['enemies_alive']==15
 if set(b)==set(a):assert ticks==observed,('period mismatch',key,ticks,observed)
 else:assert observed>=ticks,('unaccounted endpoint ticks',key)
 assert len([r for r in a.values() if r['endless']])==1
 assert all(not r['endless'] for r in a.values() if r['repeated'] or r['mount']>=8)
 if d['native_admitted']:assert not any(legacy.values())
ca=raw['A']['stress']['config'];cb=raw['B']['stress']['config'];assert ca==cb,'configuration mismatch'
assert len(ca['ordinary'])==8 and len(ca['combat_sources'])==13 and len(ca['equipped'])==5
assert all(r['key']=='longLaser' for r in ca['combat_sources'])
assert sorted(ca['totals']['legendary'])==['endless_beam','prism_tower']
valid=all(r['actual_1x_pass'] and r['focused_uncapped_vsync0'] for r in rows.values())
delta=rows['A']['mean_ms']-rows['B']['mean_ms']
result={'runs':rows,'configuration_equal':True,'configuration_sha256':hashlib.sha256(json.dumps(ca,sort_keys=True).encode()).hexdigest(),'eligible':valid,'observed_mean_A_minus_B_ms':delta if valid else None,'observed_0_5ms_gate':delta>=.5 if valid else None,'same_period_count':rows['A']['actual_periods']==rows['B']['actual_periods'],'same_chain_hit_count':rows['A']['chain_hits_by_accounting']==rows['B']['chain_hits_by_accounting'],'policy':'One serial AB only. All constant event/callback increments included, no probe-time subtraction. Two endpoint reads outside sampled wall. No per-step world export or scan. Overloaded/invalid side is diagnostic only. Death and cross-wave correctness reuse accepted tests.'}
(E/'comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='runs'},indent=2))
for key,r in rows.items():print(key,json.dumps({k:v for k,v in r.items() if not k.startswith('beam_state')},indent=2))
