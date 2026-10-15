"""Deterministic summary of the one accepted full-frame ABBA series."""
from pathlib import Path
import hashlib, json, math, statistics

E=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rank(values,q):
 values=sorted(values)
 return values[max(0,math.ceil(q*len(values))-1)] if values else None
def stats(values):
 return {'count':len(values),'mean_ms':statistics.fmean(values) if values else None,'p95_ms':rank(values,.95)}
def load(run):return json.loads((E/f'{run}.json').read_text(encoding='utf8'))
run_order={case:[f'{case}-off-a',f'{case}-on-a',f'{case}-on-b',f'{case}-off-b'] for case in ('laser','mixed')}
manifest=E/'source-manifest.json'
if manifest.exists():source=json.loads(manifest.read_text(encoding='utf8'))
else:
 progress=json.loads((E/'progress.json').read_text(encoding='utf8'))
 source={key:progress[key] for key in ('source_head','source_session_sha256','dll_sha256','driver_sha256','qa_sources','screenshot_sha256')}
 manifest.write_bytes(json.dumps(source,indent=2).encode('utf8'))
report={'method':'full GL postdraw wall frame, uncapped/VSync off/focused, actual 1x, 240 warm and 480 sample logical steps','source':source,'cases':{},'raw_sha256':{}}
for path in sorted(E.glob('*.log')):
 path.write_bytes(path.read_bytes().replace(b'\r\n',b'\n'))
 report['raw_sha256'][path.name]=sha(path)
for path in sorted(E.glob('*.json')):
 if path.name not in ('analysis.json','progress.json'):report['raw_sha256'][path.name]=sha(path)
report['raw_sha256']['full-frame.png']=sha(E/'full-frame.png')
for case,order in run_order.items():
 rows={}
 for run in order:
  raw=load(run)
  f=[v/1000 for v in raw['frames_us']];steps=raw['frame_steps']
  buckets={str(k):[v for v,n in zip(f,steps) if (n==k if k<2 else n>=2)] for k in (0,1,2)}
  b=raw['before'];a=raw['after']
  ratio=(a['game_clock']-b['game_clock'])/(sum(f)/1000)
  rows[run]={'all':stats(f),'steps_0':stats(buckets['0']),'steps_1':stats(buckets['1']),'steps_2_plus':stats(buckets['2']),'game_wall_ratio':ratio,'warm_steps':b['steps']-raw['initial']['steps'],'sample_steps':a['steps']-b['steps'],'valid_frames':raw['valid_frames'],'hot_batches':a['qa_hot_batches']-b['qa_hot_batches'],'cold_batches':a['qa_cold_batches']-b['qa_cold_batches'],'hot_rows':a['qa_hot_rows']-b['qa_hot_rows'],'cold_rows':a['qa_cold_rows']-b['qa_cold_rows'],'feedback_rows':a['feedback_rows']-b['feedback_rows'],'levels_gained':a['levels']-b['levels'],'drops_gained':a['drops']-b['drops'],'renderer':raw['renderer'],'adapter':raw['adapter'],'focused':raw['focus_start'] and raw['valid_frames']==len(f)}
  assert rows[run]['focused'] and rows[run]['warm_steps']>=240 and rows[run]['sample_steps']==480 and .965<ratio<1.035,run
  assert rows[run]['hot_rows']+rows[run]['cold_rows']==rows[run]['feedback_rows'],run
 for stage in ('before','after'):
  keys=('game_clock','steps','feedback_rows','kernel','rng','kernel_rng','player','resources','levels','loadout','drops','enemies_alive','history_size','compact_membership','native_handoffs')
  mismatch=[key for key in keys if any(load(name)[stage][key]!=load(order[0])[stage][key] for name in order[1:])]
  assert not mismatch,(case,stage,mismatch)
 off=[rows[order[i]] for i in (0,3)];on=[rows[order[i]] for i in (1,2)]
 gates={}
 for scope in ('all','steps_1','steps_2_plus'):
  off_means=[r[scope]['mean_ms'] for r in off];on_means=[r[scope]['mean_ms'] for r in on]
  gates[scope]={'off_mean_ms':statistics.fmean(off_means),'on_mean_ms':statistics.fmean(on_means),'gain_ms':statistics.fmean(off_means)-statistics.fmean(on_means),'off_drift_ms':abs(off_means[0]-off_means[1]),'on_drift_ms':abs(on_means[0]-on_means[1])} if None not in off_means+on_means else None
 report['cases'][case]={'order':order,'runs':rows,'paired':gates,'workload_equal':True,'retention_gate_pass':gates['all']['gain_ms']>=.5 and gates['all']['gain_ms']>max(gates['all']['off_drift_ms'],gates['all']['on_drift_ms'])}
assert not any(c['retention_gate_pass'] for c in report['cases'].values())
(E/'analysis.json').write_bytes(json.dumps(report,indent=2).encode('utf8'))
for case,row in report['cases'].items():
 print(case,'whole',row['paired']['all'],'busy-one',row['paired']['steps_1'],'hot',[row['runs'][name]['hot_batches'] for name in row['order']])
