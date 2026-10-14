from pathlib import Path
import json,gzip,hashlib,shutil,statistics,subprocess
r=Path('D:/CodexBuild/space_idle/stable-integration');iso=r/'test/work/battle-fix-20261013/space-battleship';src=iso/'.runtime';dst=r/'test/evidence/presentation-strip-20261014'
labels=['A1','B','A2','C','A3','D','A4','PA','PB','PC','PD','A5'];rows={x:json.loads((src/('strip-'+x+'.json')).read_text(encoding='utf-8')) for x in labels}
clean={};base=rows['A1']
for k,d in rows.items():
 for field in ['steps','native_steps']:assert d[field]==480
 assert d['events']==base['events'],k
 for field in ['game_rng','clock','player','enemies','resources','loadout','drops','projectiles','state','stage','group']:assert d['state_after'][field]==base['state_after'][field],(k,field)
 if k in ['C','D','PC','PD']:assert d['node_fingerprint_equal']
 if not k.startswith('P'):
  clean[k]={'frames':len(d['frames_us']),'whole_ms':statistics.mean(d['frames_us'])/1000,'p95_ms':sorted(d['frames_us'])[int((len(d['frames_us'])-1)*.95)]/1000,'logic_hz':480/d['wall_seconds'],'wall_seconds':d['wall_seconds'],'mode':d['mode']}
canonical={}
for k in ['PA','PB','PC','PD','A5']:
 value=rows[k]['state_after']['canonical_kernel'];value['rng'].pop('seed',None)
 canonical[k]=hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
assert len(set(canonical.values()))==1,canonical
ledger=json.loads((r/'test/work/strip-ledger.json').read_text(encoding='utf-8'));cal=json.loads((src/'strip-probe-calibration.json').read_text(encoding='utf-8'))
for k,v in ledger.items():v['noop_probe_pair_estimate_ms_per_frame']=sum(v['span_calls'].values())*cal['us_per_pair']/v['frames']/1000
natural=json.loads((src/'natural-current.json').read_text(encoding='utf-8'));nn=len(natural['frames_us']);admit=sum(x['us'] for x in natural['admissions']);handoff=sum(x['us'] for x in natural['transfers'])
summary={'source_main':'346c67f8856dac075cc604e21c41fe96220f78df','dll_sha256':rows['A5']['dll_sha256'],'clean_runs':clean,'baseline_drift_ms':max(clean[x]['whole_ms'] for x in ['A1','A2','A3','A4','A5'])-min(clean[x]['whole_ms'] for x in ['A1','A2','A3','A4','A5']),'fixed_step_comparison':{'steps_each':480,'game_seconds_each':base['game_seconds'],'events_identical_all_runs':True,'events':base['events'],'game_rng':base['state_after']['game_rng'],'typed_kernel_hashes_excluding_unused_seed_metadata':canonical,'note':'Full post-sample native export matches recursively except /rng/seed. Actual RNG state matches. Seed is initialization metadata after live RNG state restoration, not compared as current RNG state. Flight display views replaced only with identity/target UIDs; typed motion/queues/attack/defence state retained. Initial clean raw export hashes include live objects/display views and are not used as determinism evidence.'},'mutually_exclusive_ledger':ledger,'probe_calibration':cal,'natural':{'stop_reason':natural['stop_reason'],'frames':nn,'whole_ms':statistics.mean(natural['frames_us'])/1000,'p95_ms':sorted(natural['frames_us'])[int((nn-1)*.95)]/1000,'game_seconds':natural['game_seconds'],'wall_seconds':natural['wall_seconds'],'logic_hz':natural['steps']/natural['wall_seconds'],'events':natural['events'],'observed_drop_ids':len(natural['observed_drop_ids']),'resources_before':natural['initial']['resources'],'resources_after':natural['resources_end'],'admissions':natural['admissions'],'transfers':natural['transfers'],'admission_and_handoff_amortized_ms_per_frame':(admit+handoff)/nn/1000,'native_frames':sum(s['native'] for s in natural['samples']),'notes':['Original table health/drops, finite resource replay, no replenishment. 19 actual module level purchases in 4 batches; wallet drops from 3000 to142 iron including income.','Third admission occurs at stop boundary: two full native wave residences plus third successful admission, not three completed native waves.','Drop creation counted by first-seen live IDs (22), collection events 13 plus jewel events4; do not equate all drop IDs with ordinary collect events.','Sampling includes travel/legacy periods; native active only 533 of1058 rendered samples. No claim of continuous native ownership across transitions.']},'interpretation':['B/C/D whole intervals are capped around16.7ms; no conclusion that remaining busy work is16.7ms. Measured script spans are reported separately; rendering window contains submission/GPU/wait which is not reliably split.','B dependency delta includes stopped painter bodies and their incidental updates, plus suppressed ship rendering. It is neither GPU-only cost nor implementable full-quality saving.','Changing frame rate changes per-render snapshot/update count; compare totals per480 steps as well as per-frame. No nested timings or concurrent CPU/GPU durations are summed.','A whole-frame drift exceeds4ms. Profile A falls within clean A range; no positive whole-frame probe correction can be inferred. Empty begin/end calibration is partial only and is not subtracted from results.','Natural sample and held-health stress fixture answer different questions; do not compare their whole-frame times as optimization gains.']}
(dst/'comparison.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
# Raw compressed JSON is measurement evidence, not an engine cache or player save.
for k in labels:
 raw=(src/('strip-'+k+'.json')).read_bytes()
 with (dst/('strip-'+k+'.json.gz')).open('wb') as out:
  with gzip.GzipFile(filename='',mode='wb',fileobj=out,mtime=0) as z:z.write(raw)
 shutil.copy2(r/'test/work'/('strip-'+k+'.txt'),dst/('strip-'+k+'.txt'))
for name in ['natural-current.json','strip-probe-calibration.json']:shutil.copy2(src/name,dst/name)
for name in ['strip-A5.png','strip-B.png','strip-C.png','strip-D.png','natural-current.png']:shutil.copy2(src/name,dst/name)
for name in ['natural-current.txt','strip-probe-calibration.txt','analyze_strip_ledger.py']:shutil.copy2(r/'test/work'/name,dst/name)
shutil.copy2(iso/'qa_strip_probe_calibration.gd',dst/'qa_strip_probe_calibration.gd')
# Return isolated production sources to the repository source; no probes remain in scripts/.
for p in (r/'space-battleship/scripts').rglob('*.gd'):shutil.copy2(p,iso/p.relative_to(r/'space-battleship'))
print('clean',clean,'drift',summary['baseline_drift_ms'],'canonical identical',len(set(canonical.values()))==1)
print('native transition ms/frame',summary['natural']['admission_and_handoff_amortized_ms_per_frame'])
print('probe perframe',{k:v['noop_probe_pair_estimate_ms_per_frame'] for k,v in ledger.items()})
