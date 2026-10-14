from pathlib import Path
import json,gzip,collections
P=Path(__file__).resolve().parent
d=json.load(gzip.open(P/'slot-locate.json.gz','rt',encoding='utf8'))
order=[(c,i,str(e['key'])) for c in ['weapons','defence'] for i,e in enumerate(d['state_before']['loadout'][c])]
rows=[]
for phase,sample in zip(d['phases'],d['samples']):
 calls=sorted(s for s in phase['spans'] if s[2]=='economy.game.upgrade_slot')
 if not calls:continue
 assert len(calls)==len(order)
 for (a,b,_),(category,i,key) in zip(calls,order):
  costs=collections.Counter();counts=collections.Counter();quotes=[]
  for x,y,label in phase['spans']:
   if x>=a and y<=b and (label.startswith('slot.') or label in ['economy.game.can_upgrade_slot','economy.game.slot_upgrade_cost']):
    costs[label]+=y-x;counts[label]+=1
    if label in ['economy.game.can_upgrade_slot','economy.game.slot_upgrade_cost']:quotes.append((x,y))
  union=0;end=-1
  for x,y in sorted(quotes):union+=max(0,y-max(x,end));end=max(end,y)
  costs['quote_eligibility_union']=union
  rows.append({'step':sample['step'],'category':category,'slot':i,'key':key,'total_us':b-a,'parts_us':dict(costs),'calls':dict(counts)})
summary={}
for category in ['weapons','defence']:
 rr=[r for r in rows if r['category']==category];labels=set(k for r in rr for k in r['parts_us'])
 summary[category]={'slots_per_batch':len(rr)/4,'mean_batch_ms':sum(r['total_us'] for r in rr)/4000,'parts_ms_per_batch':{k:sum(r['parts_us'].get(k,0) for r in rr)/4000 for k in sorted(labels)}}
def clean(v):
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k!='kernel_hash' and not(k=='seed' and v.get('class')=='RandomNumberGenerator')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
reference=json.load(gzip.open(P/'numeric-locate.json.gz','rt',encoding='utf8'))
equality={k:clean(d[k])==clean(reference[k]) for k in ['state_before','state_after','events']}
assert all(equality.values())
result={'source':'4454d680','method':'One instrumented run, four batches. Slot calls sorted by timestamp and matched to original weapons/defence order; count equality asserted. slot.* sections disjoint. can_upgrade includes quote; quote_eligibility_union counts their interval union once. Cache rebuild work remains inside value reads/listeners, not the cache-clear call. Not net removable benefit.','equivalence':equality,'summary':summary,'rows':rows}
(P/'slot-breakdown.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print(json.dumps({'equivalence':equality,'summary':summary},indent=2))
