"""Read-only, pinned Git-tree census. Lexical references are not a call graph or coverage trace."""
from pathlib import Path
import subprocess,re,csv,json,collections,argparse
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path.cwd());p.add_argument('--output',type=Path,required=True);a=p.parse_args()
BASE='e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3';out=a.output;out.mkdir(parents=True,exist_ok=True)
def git(*args):return subprocess.check_output(['git','-C',str(a.repo),*args])
def category(path):
 if path.startswith('test/'):
  return 'test_source' if Path(path).suffix in {'.gd','.py','.ps1','.bat','.cmd'} and not any(x in path for x in ['/evidence/','/performance_evidence/','/work/']) else 'test_support_or_evidence'
 if path.startswith('space-battleship/scripts/'):return 'runtime_script'
 if path.startswith('space-battleship/addons/native_battle/src/'):return 'native_source'
 if path.startswith('space-battleship/addons/'):return 'addon_support'
 if path.startswith('space-battleship/data/'):return 'runtime_data'
 if path.startswith('space-battleship/config_excel/'):return 'authoring_workbook'
 if path.startswith(('space-battleship/tools/','tools/')):return 'tooling'
 if path.startswith('space-battleship/assets/'):return 'asset'
 if path.startswith('space-battleship/dev/'):return 'dev_and_runtime_art_support'
 if path.startswith(('space-battleship/docs/','space-battleship/evidence/','space-battleship/art_sources/')):return 'documentation_or_evidence'
 return 'root_and_auxiliary'
items=[]
for record in git('ls-tree','-r','-l','-z',BASE).split(b'\0'):
 if not record:continue
 meta,path=record.split(b'\t',1);mode,kind,blob,size=meta.decode().split();path=path.decode()
 items.append({'path':path,'blob':blob,'bytes':int(size) if size!='-' else 0,'category':category(path),'extension':Path(path).suffix,'scope':'inventory_only'})
source_ext={'.gd','.gdshader','.py','.cpp','.h','.ps1','.cmd','.bat','.tscn','.godot','.cfg','.html'}
# Only active code locations are structurally scanned; embedded historical code remains inventory-only.
scan_cats={'runtime_script','native_source','addon_support','tooling','root_and_auxiliary','dev_and_runtime_art_support','test_source','asset'}
texts={};symbols=[];classes={}
for row in items:
 if row['extension'] not in source_ext or row['category'] not in scan_cats:continue
 raw=git('show',BASE+':'+row['path']).decode('utf-8',errors='replace');texts[row['path']]=raw;row['scope']='lexical_structure_scan';row['lines']=len(raw.splitlines())
 if row['extension']=='.gd':
  for name in re.findall(r'^class_name\s+(\w+)',raw,re.M):classes[name]=row['path']
 for n,line in enumerate(raw.splitlines(),1):
  m=re.match(r'\s*(?:static\s+)?(?:func|def)\s+(\w+)\s*\(',line)
  if m:symbols.append({'path':row['path'],'line':n,'symbol':m[1]})
paths={r['path'] for r in items};edges=[];events=[];states=[];datarefs=[]
for path,raw in texts.items():
 for n,line in enumerate(raw.splitlines(),1):
  if line.lstrip().startswith(('#','//',';')):continue
  for target in re.findall(r'["\']res://([^"\']+)["\']',line):
   target='space-battleship/'+target
   edge={'source':path,'line':n,'target':target,'kind':'literal_resource_reference','target_in_baseline':target in paths};edges.append(edge)
   if target.startswith('space-battleship/data/'):datarefs.append(edge)
  if path.endswith('.gd'):
   for cls,target in classes.items():
    if target!=path and re.search(r'\b'+cls+r'\b',line):edges.append({'source':path,'line':n,'target':target,'kind':'class_token_reference','target_in_baseline':True})
   for event in re.findall(r'event\.emit\(\s*["\']([^"\']+)',line):events.append({'path':path,'line':n,'event':event})
   if re.search(r'\bprofile\b|\bstat_cache\b|\bnative_execution\b',line) and (re.search(r'(?<![=!<>])=(?!=)',line) or re.search(r'\.(?:append|erase|clear|merge)\(',line)):
    states.append({'path':path,'line':n,'candidate':line.strip()})
def write_csv(name,rows,fields):
 with (out/name).open('w',encoding='utf-8',newline='') as f:
  w=csv.DictWriter(f,fieldnames=fields,lineterminator="\n");w.writeheader();w.writerows({k:r.get(k,'') for k in fields} for r in rows)
write_csv('files.csv',items,['path','blob','bytes','category','extension','scope','lines'])
write_csv('symbols.csv',symbols,['path','line','symbol'])
write_csv('references.csv',edges,['source','line','target','kind','target_in_baseline'])
write_csv('data_references.csv',datarefs,['source','line','target','kind','target_in_baseline'])
write_csv('event_emissions.csv',events,['path','line','event'])
write_csv('state_reference_candidates.csv',states,['path','line','candidate'])
by=collections.defaultdict(lambda:{'files':0,'bytes':0,'scanned_files':0,'scanned_lines':0})
for r in items:
 b=by[r['category']];b['files']+=1;b['bytes']+=r['bytes'];b['scanned_files']+=r['scope']=='lexical_structure_scan';b['scanned_lines']+=r.get('lines',0)
fanout=collections.defaultdict(set)
for e in edges:
 if e['target'].endswith(('.gd','.cpp','.h')):fanout[e['source']].add(e['target'])
sumdata={'baseline':BASE,'files':len(items),'tracked_bytes':sum(r['bytes'] for r in items),'categories':dict(sorted(by.items())),'scanned_files':len(texts),'function_declarations':len(symbols),'literal_or_class_reference_rows':len(edges),'event_emissions':len(events),'distinct_event_names':len({r['event'] for r in events}),'state_candidates':len(states),'top_code_reference_fanout':sorted([{'path':k,'distinct_targets':len(v)} for k,v in fanout.items()],key=lambda r:(-r['distinct_targets'],r['path']))[:15],'limitations':['Lexical extraction is not a complete semantic dependency graph.','State candidates include reads and local aliases; they are not confirmed mutations.','Inventory and scans do not prove line, branch, behavior, asset or security coverage.','Test execution does not imply coverage of every imported module.']}
(out/'summary.json').write_text(json.dumps(sumdata,ensure_ascii=False,indent=2)+'\n');print(json.dumps(sumdata,ensure_ascii=False,indent=2))
