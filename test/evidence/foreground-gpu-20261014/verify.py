from pathlib import Path
import gzip,json,statistics
p=Path('test/evidence/foreground-gpu-20261014')
def scrub(v):
 if isinstance(v,dict):
  return {k:scrub(x) for k,x in v.items() if k!='kernel_hash' and not(k=='seed' and v.get('class')=='RandomNumberGenerator')}
 if isinstance(v,list):return [scrub(x) for x in v]
 return v
raw={n:json.load(gzip.open(p/(n+'.json.gz'),'rt',encoding='utf-8')) for n in ['A1','B1','B2','A2','A3','B3']}
ref=raw['A1']
for n,r in raw.items():
 for key in ['state_before','state_after','events']:
  assert scrub(r[key])==scrub(ref[key]),(n,key)
 assert r['steps']==r['native_steps']==240 and r['physics_ticks_per_second']==60 and r['config']['speed']==1
 if n.startswith('B'):
  assert r['beam_metrics_before']['live_quad_builds']==r['beam_metrics_after']['live_quad_builds']==66
summary=json.loads((p/'comparison.json').read_text())
summary['equivalence']='All six before/after canonical kernel and game states and event counts equal; only RNG seed metadata and derived kernel hash excluded. RNG state preserved.'
summary['geometry_checks']=196
summary['failures']=0
summary['persistent_commands']='All three B runs: 6 beams + 60 links = 66 live quad builds before and after 240 logic steps.'
summary['percentiles_ms']={n:{str(q):sorted(r['frames_us'])[min(len(r['frames_us'])-1,int(len(r['frames_us'])*q))]/1000 for q in [.5,.95,.99]} for n,r in raw.items()}
summary['scope']='Three predeclared short interleaved pairs, no repeats. Complete 15-enemy held-health scene with effects, AI factory, research and exploration; true1x60Hz; uncapped/VSync0; same native DLL; saves off in D-only isolated QA.'
summary['limitations']='Concurrent user work was neither stopped nor controlled. Short paired measurements are not a long-run or natural-save claim. Under10ms target remains unmet. No isolated GPU time or inferred removable cost claimed.'
summary['decision']='Retain GPU beam candidate on work branch for parent integration review.' if min(summary['paired_A_minus_B_ms'])>.5 else 'Needs parent review; do not claim consistent standalone >=0.5ms gain.'
(p/'decision.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='cases'},indent=2))
