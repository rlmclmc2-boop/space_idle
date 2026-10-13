from pathlib import Path
import json,collections,statistics,heapq
area=Path(__file__).parent
p=area/'space-battleship/.runtime/astra-direct-geometry-boundary.json';d=json.loads(p.read_text(encoding='utf-8'))
inc=collections.Counter();exc=collections.Counter();counts=collections.Counter();inside_exc=collections.Counter();inside_calls=collections.Counter()
for row in d['phases']:
 spans=row['ledger_spans'];events=collections.defaultdict(list);live=set();heap=[];outer=0
 for i,(a,b,k) in enumerate(spans):
  inc[k]+=b-a;counts[k]+=1;events[a].append((True,i));events[b].append((False,i))
 pts=sorted(events)
 for index,a in enumerate(pts[:-1]):
  # Process ends first, then starts, including zero-length spans as inactive.
  for start,i in sorted(events[a]):
   x,y,k=spans[i]
   if x==y:continue
   if start:
    live.add(i);heapq.heappush(heap,(y-x,k,i))
    if k=='battle_slice_runtime.advance':outer+=1
   else:
    live.discard(i)
    if k=='battle_slice_runtime.advance':outer-=1
  while heap and heap[0][2] not in live:heapq.heappop(heap)
  if heap:
   k=heap[0][1];cost=pts[index+1]-a;exc[k]+=cost
   if outer:inside_exc[k]+=cost
n=len(d['phases'])
rows={k:{'inclusive_ms':inc[k]/n/1000,'exclusive_ms':exc[k]/n/1000,'advance_exclusive_ms':inside_exc[k]/n/1000,'calls_per_frame':counts[k]/n} for k in sorted(inc)}
result={'frames':n,'diagnostic_frame_ms':statistics.mean(d['frames_us_raw'])/1000,'probe_calibration':d['probe_calibration'],'calls_per_frame':sum(counts.values())/n,'advance_partition_ms':sum(inside_exc.values())/n/1000,'rows':rows,'runtime':{k:d[k] for k in ['sample_steps','fires','hits','purchases','handoffs','logic_hz','actual_1x_pass']}}
(area/'geometry-boundary-costs.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='rows'}))
for k,v in rows.items():print(k,round(v['inclusive_ms'],4),round(v['exclusive_ms'],4),round(v['advance_exclusive_ms'],4),round(v['calls_per_frame'],2))
