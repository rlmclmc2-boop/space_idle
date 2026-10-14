from pathlib import Path
import gzip,json,collections,statistics,hashlib
P=Path(__file__).resolve().parent
root=P.parents[2]
out={}
for name in ['snapshot-locate','FG-locate','feedback-locate']:
 f=root/'test/evidence/foreground-gpu-20261014'/ (name+'.json.gz')
 d=json.load(gzip.open(f,'rt',encoding='utf8')); rows=[];previous=0
 assert len(d['phases'])==len(d['samples'])==len(d['frames_us'])
 for i,(p,s,us) in enumerate(zip(d['phases'],d['samples'],d['frames_us'])):
  sums=collections.Counter()
  for a,b,k in p['spans']:sums[k]+=b-a
  step=s['step']; boundary=any(previous<b<=step for b in [60,120,180,240])
  economy=sums['game.advance_shared_clock_and_economy']
  rows.append({'frame':i,'step':step,'step_delta':step-previous,'boundary':boundary,'frame_ms':us/1000,'economy_ms':economy/1000,'frame_minus_economy_ms':(us-economy)/1000,'inclusive_ms':{k:v/1000 for k,v in sums.items()}})
  previous=step
 def aggregate(rs):
  keys=set(k for r in rs for k in r['inclusive_ms'])
  return {'n':len(rs),'frame_ms':statistics.mean(r['frame_ms'] for r in rs),'economy_ms':statistics.mean(r['economy_ms'] for r in rs),'frame_minus_economy_ms':statistics.mean(r['frame_minus_economy_ms'] for r in rs),'inclusive_ms':{k:statistics.mean(r['inclusive_ms'].get(k,0) for r in rs) for k in sorted(keys)}}
 b=aggregate([r for r in rows if r['boundary']]);n=aggregate([r for r in rows if not r['boundary']]);one=aggregate([r for r in rows if not r['boundary'] and r['step_delta']==1])
 out[name]={'source':d['source'],'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'boundary':b,'ordinary':n,'ordinary_one_step':one,'boundary_rows':[r for r in rows if r['boundary']],'largest_nonboundary_frames':sorted([r for r in rows if not r['boundary']],key=lambda r:r['frame_ms'],reverse=True)[:5],'rows':rows}
 print(name,json.dumps({'boundary':{k:v for k,v in b.items() if k!='inclusive_ms'},'ordinary':{k:v for k,v in n.items() if k!='inclusive_ms'},'one_step':{k:v for k,v in one.items() if k!='inclusive_ms'}}))
 print('largest inclusive boundary differences',sorted([(k,b['inclusive_ms'].get(k,0)-n['inclusive_ms'].get(k,0)) for k in b['inclusive_ms']],key=lambda x:x[1],reverse=True)[:16])
 print('nonboundary top',[(r['frame'],r['step'],r['step_delta'],r['frame_ms'],r['economy_ms']) for r in out[name]['largest_nonboundary_frames']])
(P/'boundary-spans.json').write_text(json.dumps({'method':'Offline existing samples only; boundary crosses relative logic step 60/120/180/240. Inclusive spans overlap: never sum parent and child. frame minus economy subtracts this single non-overlapping call family only, preserving every frame; descriptive attribution, not a predicted removable gain. Ordinary one-step subset is diagnostic cadence matching, not replacement acceptance.','runs':out},indent=2),encoding='utf8')
