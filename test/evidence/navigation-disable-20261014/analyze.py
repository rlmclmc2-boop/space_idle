from pathlib import Path
import json,gzip,statistics
P=Path(__file__).resolve().parent
def clean(v):
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k!='kernel_hash' and not(k=='seed' and v.get('class')=='RandomNumberGenerator')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
def stat(v):
 s=sorted(v);return {'frames':len(v),'mean_ms':statistics.mean(v)/1000,'median_ms':statistics.median(v)/1000,'p95_ms':s[min(len(s)-1,int(len(s)*.95))]/1000,'p99_ms':s[min(len(s)-1,int(len(s)*.99))]/1000,'max_ms':max(v)/1000}
a=json.load(gzip.open(P/'nav-A.json.gz','rt',encoding='utf8'));b=json.load(gzip.open(P/'nav-B.json.gz','rt',encoding='utf8'))
r={'source':'63b93069','dll_sha256':a['dll_sha256'],'runs':{},'equivalence':{k:clean(a[k])==clean(b[k]) for k in ['before','after','state_before','state_after','events','config']},'limits':'One short pair only; no extra samples. Disabled navigation is incomplete UI and cannot ship. A-minus-B is an observed full-frame difference, not stable net savings or a proven theoretical bound. Small differences may be masked by variation.'}
for name,d in [('A',a),('B',b)]:
 assert d['steps']==d['native_steps']==240 and not d['help_open'] and not d['pending_unlocks']
 assert json.loads((P/('nav-'+name+'-exit.json')).read_text())['exit_code']==0
 r['runs'][name]={'all':stat(d['frames_us']),'steps':d['steps'],'game_seconds':d['game_seconds'],'exit_code':0,'counts':d['counts'],'help_open':d['help_open'],'pending_unlocks':d['pending_unlocks']}
assert all(r['equivalence'].values())
assert a['counts'].get('disabled:refresh_navigation',0)==0 and b['counts'].get('enabled:refresh_navigation',0)==0
assert b['counts']['disabled:refresh_navigation']==len(b['frames_us'])
r['A_minus_B_ms']={k:r['runs']['A']['all'][k]-r['runs']['B']['all'][k] for k in ['mean_ms','median_ms','p95_ms','p99_ms','max_ms']}
r['other_work']='Logic/state/events/config identical. Per-frame draw/display counts vary with achieved frame count; no other path intentionally disabled. This fixture has no open help/pending notice, so it cannot demonstrate live navigation correctness.'
(P/'result.json').write_text(json.dumps(r,indent=2),encoding='utf8');print(json.dumps(r,indent=2))
