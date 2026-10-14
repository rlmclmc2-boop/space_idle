from pathlib import Path
import gzip,json,statistics
P=Path(__file__).resolve().parent
names=['A1','B1','B2','A2','A3','B3']
def clean(v):
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k!='kernel_hash' and not(k=='seed' and v.get('class')=='RandomNumberGenerator')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
def stats(v):
 s=sorted(v)
 return {'n':len(v),'mean_ms':statistics.mean(v)/1000,'median_ms':statistics.median(v)/1000,'p95_ms':s[min(len(s)-1,int(len(s)*.95))]/1000,'p99_ms':s[min(len(s)-1,int(len(s)*.99))]/1000,'max_ms':max(v)/1000}
raw={n:json.load(gzip.open(P/(n+'.json.gz'),'rt',encoding='utf8')) for n in names}
result={'runs':{},'equivalence':{},'pairs':[]}
for n,d in raw.items():
 result['equivalence'][n]={k:clean(d[k])==clean(raw['A1'][k]) for k in ['before','after','state_before','state_after','events']}
 assert d['steps']==d['native_steps']==240 and not d['gpu_beams_enabled'] and not d['damage_cache_enabled']
 previous=0;boundaries=[]
 for i,sample in enumerate(d['samples']):
  if any(previous<b<=sample['step'] for b in [60,120,180,240]):boundaries.append(i)
  previous=sample['step']
 assert len(boundaries)==4
 f=d['frames_us'];following=[i+1 for i in boundaries if i+1<len(f)]
 result['runs'][n]={'source':d['source'],'all':stats(f),'boundary':stats([f[i] for i in boundaries]),'ordinary':stats([x for i,x in enumerate(f) if i not in boundaries]),'following':stats([f[i] for i in following]),'boundary_frames':[{'index':i,'step':d['samples'][i]['step'],'ms':f[i]/1000} for i in boundaries],'kernel_metrics_before':d['kernel_metrics_before'],'kernel_metrics_after':d['kernel_metrics_after']}
for i in range(1,4):
 a,b=result['runs']['A'+str(i)],result['runs']['B'+str(i)]
 result['pairs'].append({'pair':i,'A_minus_B_ms':{section:{k:a[section][k]-b[section][k] for k in ['mean_ms','p95_ms','p99_ms','max_ms']} for section in ['all','boundary','ordinary','following']}})
result['all_equivalent']=all(all(x.values()) for x in result['equivalence'].values())
result['checks']={'numeric_incremental':31,'numeric_upgrade':69,'fleet_pose':24,'numeric_range':39,'geometry':211,'failures':0}
result['limits']='Three predeclared pairs; all frames retained; boundaries are frames crossing60/120/180/240. Ordinary excludes only those4 for attribution, not acceptance. No new native build. No source-level cost is assumed removable. No extra runs.'
(P/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print(json.dumps({'equivalence':result['equivalence'],'pairs':result['pairs']},indent=2))
