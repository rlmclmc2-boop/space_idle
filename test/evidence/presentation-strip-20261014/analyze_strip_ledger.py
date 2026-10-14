from pathlib import Path
import json,collections,statistics
r=Path('D:/CodexBuild/space_idle/stable-integration');src=r/'test/work/battle-fix-20261013/space-battleship/.runtime';report={}
for case in ['PA','PB','PC','PD']:
 d=json.loads((src/('strip-'+case+'.json')).read_text(encoding='utf-8'));total=collections.Counter();calls=collections.Counter();all_us=0
 for f in d['phases']:
  a,b=f['start'],f['end'];all_us+=b-a;segments=[]
  anchors=[(a,f['signal'],'gap.postdraw_to_signal'),(f['signal'],f['main_start'],'gap.signal_to_main'),(f['main_start'],f['main_end'],'main.unwrapped'),(f['main_end'],f['pre_draw'],'gap.after_main_before_render'),(f['pre_draw'],b,'render_submission_gpu_wait_unsplit')]
  for x,y,label in anchors:
   x=max(a,x);y=min(b,y)
   if y>x:segments.append((x,y,label,0))
  for x,y,label in f['spans']:
   x=max(a,x);y=min(b,y)
   if y>x:segments.append((x,y,label,1));calls[label]+=1
  endpoints=collections.defaultdict(list)
  for i,(x,y,label,rank) in enumerate(segments):endpoints[x].append((i,True));endpoints[y].append((i,False))
  endpoints[a];endpoints[b];active=set();previous=a
  for t,changes in sorted(endpoints.items()):
   if t>previous:
    chosen=max(active,key=lambda i:(segments[i][3],-(segments[i][1]-segments[i][0]))) if active else None
    total[segments[chosen][2] if chosen is not None else 'gap.unassigned']+=t-previous
   for i,on in changes:
    if on:active.add(i)
    else:active.discard(i)
   previous=t
 n=len(d['frames_us']);assert sum(total.values())==all_us
 means={k:v/n/1000 for k,v in total.most_common()}
 scripts=sum(v for k,v in total.items() if not k.startswith('gap.') and k!='render_submission_gpu_wait_unsplit')
 report[case]={'frames':n,'whole_ms':all_us/n/1000,'exclusive_sum_ms':sum(means.values()),'exclusive_ms_per_frame':means,'exclusive_us_totals':dict(total),'span_calls':dict(calls),'measured_script_ms_per_frame':scripts/n/1000,'measured_script_ms_per_logic_step':scripts/d['steps']/1000,'game_seconds':d['game_seconds'],'logic_hz':d['steps']/d['wall_seconds'],'root_render_mean':{k:statistics.mean(s['render']['root'][k] for s in d['samples']) for k in ['cpu_ms','gpu_ms']},'ship_render_mean':{k:statistics.mean(s['render']['ship'][k] for s in d['samples']) for k in ['cpu_ms','gpu_ms']} if case=='PA' else 'Viewport disabled; engine timestamps stale, not reported as current work.'}
 print(case,'whole',round(all_us/n/1000,3),'script/step',round(scripts/d['steps']/1000,3));print({k:round(v,3) for k,v in list(means.items())[:13]})
(r/'test/work/strip-ledger.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
