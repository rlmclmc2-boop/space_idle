from pathlib import Path
import json,gzip,statistics,collections,subprocess,hashlib,tarfile,io,re
ROOT=Path.cwd();P=ROOT/'test/evidence/weapon-value-exit-20261014/offline'
sets={'current':P.parent/'final','previous':P.parent.parent/'numeric-update-20261014/final'}
order=['A1','B1','B2','A2','A3','B3']
def stat(v):
 s=sorted(v);return {'n':len(v),'mean':statistics.mean(v),'median':statistics.median(v),'p95':s[min(len(s)-1,int(len(s)*.95))],'max':max(v)} if v else {}
def subset(d,indices):
 return {'frame_ms':stat([d['frames_us'][i]/1000 for i in indices]),'render':{view:{clock:stat([d['samples'][i]['render'][view][clock] for i in indices]) for clock in ['cpu_ms','gpu_ms']} for view in ['root','ship']}}
def audit(ref,manifest):
 blob=subprocess.check_output(['git','archive',ref,'space-battleship/scripts','space-battleship/shaders'])
 with tarfile.open(fileobj=io.BytesIO(blob)) as tar:data={m.name:tar.extractfile(m).read() for m in tar.getmembers() if m.isfile()}
 # git archive applies worktree CRLF conversion; the launcher overlays exact git-show bytes.
 for n in manifest:data[n]=subprocess.check_output(['git','show',ref+':'+n])
 def read(n):return data['space-battleship/scripts/'+n].decode('utf8').replace('\r\n','\n')
 def write(n,s):data['space-battleship/scripts/'+n]=re.sub(r'^[ \t]+',lambda m:m[0].replace(' ','\t'),s,flags=re.M).replace('\n','\r\n').encode('utf8')
 source=(ROOT/'test/evidence/presentation-strip-20261014/prepare_strip.py').read_text(encoding='utf8')
 # Replay only pure text transforms in memory; no copies, writes, project prep or game execution.
 source=source[source.index('def insert('):].split("print('Prepared strip")[0]
 exec(source,{'read':read,'write':write,'re':re,'profile':False,'G':'preload("res://strip_gate.gd")'})
 return {n:{'recorded':h,'expected':hashlib.sha256(data[n]).hexdigest(),'match':h==hashlib.sha256(data[n]).hexdigest()} for n,h in manifest.items()}
result={'runs':{},'hash_audit':{},'limits':['Recorded hashes are launcher hashes of prepared script files, not runtime attestation of every loaded script. All seven A/B changed production scripts are covered.','RenderingServer viewport measurements are existing render counters, may lag, do not cover all GDScript or submission/wait/scheduling and must not be added as a complete frame decomposition.','ProcessTimes is process-wide across threads over the entire sample window, not per-frame CPU attribution.','All acceptance phases arrays are empty (profile=false); ordinary-frame CPU execution versus submission/wait remains unresolved.']}
for group,path in sets.items():
 result['runs'][group]={}
 for name in order:
  d=json.load(gzip.open(path/(name+'.json.gz'),'rt',encoding='utf8'));cpu=json.loads((path/('cpu-'+name+'.json')).read_text());prev=0;steps=[];bound=[]
  for i,s in enumerate(d['samples']):
   steps.append(s['step']-prev)
   if any(prev<b<=s['step'] for b in [60,120,180,240]):bound.append(i)
   prev=s['step']
  follow=[i+1 for i in bound if i+1<len(steps)];ordinary=[i for i in range(len(steps)) if i not in bound+follow]
  row={'frames':len(steps),'cpu_ms':cpu['cpu_us']/1000,'cpu_window_s':cpu['cpu_window_seconds'],'cpu_per_frame_ms':cpu['cpu_us']/len(steps)/1000,'cpu_per_logic_step_ms':cpu['cpu_us']/240/1000,'user_ms':(cpu['end']['user_us']-cpu['begin']['user_us'])/1000,'kernel_ms':(cpu['end']['kernel_us']-cpu['begin']['kernel_us'])/1000,'steps_per_frame':dict(collections.Counter(steps)),'all':subset(d,list(range(len(steps)))),'ordinary':subset(d,ordinary),'by_logic_quarter':{},'ordinary_by_steps':{str(n):subset(d,[i for i in ordinary if steps[i]==n]) for n in sorted(set(steps))},'boundary_frames':[{'index':i,'step':d['samples'][i]['step'],'steps_in_frame':steps[i],'frame_ms':d['frames_us'][i]/1000,'render':d['samples'][i]['render']} for i in bound],'counts':d['counts'],'phase_spans_available':bool(d['phases']),'runtime_flags':{k:d[k] for k in ['source','dll_sha256','gpu_beams_enabled','damage_cache_enabled','mode','profile','extension_open']}}
  for q in range(4):
   ids=[i for i,s in enumerate(d['samples']) if q*60<s['step']<=(q+1)*60]
   row['by_logic_quarter'][str(q+1)]={'all':subset(d,ids),'ordinary':subset(d,[i for i in ids if i in ordinary]),'steps_per_frame':dict(collections.Counter(steps[i] for i in ids))}
  for label,lo,hi in [('first_half',0,120),('second_half',120,240)]:row[label]=subset(d,[i for i in ordinary if lo<d['samples'][i]['step']<=hi])
  result['runs'][group][name]=row
  if group=='current':
   ref='63b93069' if name.startswith('A') else '63bfa881'
   result['hash_audit'][name]=audit(ref,cpu['script_sha256'])
   assert all(x['match'] for x in result['hash_audit'][name].values()),{k:v for k,v in result['hash_audit'][name].items() if not v['match']}
   assert d['source'].startswith(ref) and not d['gpu_beams_enabled'] and not d['damage_cache_enabled'] and d['dll_sha256']== '052b231e64bae9efb9e2601fc221f26390ee5346758bed5f5da278b2235caf4e'
(P/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf8')
for group,runs in result['runs'].items():
 print(group)
 for name,r in runs.items():
  print(name,'cpu',r['cpu_ms'],'frame',round(r['all']['frame_ms']['mean'],3),'ordinary halves',[round(r[h]['frame_ms']['mean'],3) for h in ['first_half','second_half']],'root/ship cpu/gpu',[round(r['ordinary']['render'][v][c]['mean'],3) for v in ['root','ship'] for c in ['cpu_ms','gpu_ms']],'step_dist',r['steps_per_frame'])
