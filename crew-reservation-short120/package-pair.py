from pathlib import Path
import json,collections,hashlib,gzip,shutil
w=Path(__file__).parent;ds=json.loads((w/'decoded-pair.json').read_text());src=ds[2];root=Path('/workspace/evidence-stage/hyperspace-closeout-20261006/crew-reservation-short120');root.mkdir(exist_ok=True);result={}
for i,(arm,proj,label) in enumerate([('original','unified-e528-post60-qa','sol-e528-postreforge-crew-original120'),('fixed','crew-reservation-fix-qa','sol-crew-reservation-postreforge120')]):
 d=Path('/workspace/sol-validation')/proj/'diagnostics'/label;cp=ds[i];r=[json.loads(x) for x in (d/'actions.jsonl').read_text().splitlines()];c=cp['controller'];paid=[x for x in r if x['kind']=='observed_paid_crew_batch'];rel=[x for x in r if x['kind']=='domain_action' and x['choice']['kind']=='crew_release'];assign=[x for x in r if x['kind']=='click' and x.get('action_kind')=='crew_assign'];pending={};cycles=[]
 for x in r:
  if x['kind']=='click' and x.get('action_kind')=='crew_assign':pending[x['crew']]=x['x1_seconds']
  if x['kind']=='domain_action' and x['choice']['kind']=='crew_release':
   who=x['choice']['crew']
   if who in pending:cycles.append({'crew':who,'assigned':pending.pop(who),'released':x['x1_seconds'],'duration':x['x1_seconds']-pending.get(who,x['x1_seconds'])})
 # Compute duration after saved timestamp (not popped lookup).
 for x in cycles:x['duration']=x['released']-x['assigned']
 result[arm]={'cp_x1':cp['x1_seconds'],'cp_sha256':cp['sha256'],'click_delta':c['clicks']-src['controller']['clicks'],'native_click_records':sum(x['kind']=='click' for x in r),'domain_records':sum(x['kind']=='domain_action' for x in r),'releases':rel,'assignments':assign,'cycles':cycles,'paid_batch_events':paid,'actual_paid_batch_count':len(paid),'deaths_delta':c['deaths']-src['controller']['deaths'],'current_crew':cp['save']['crew'],'final_loadout':cp['save']['loadout'],'resources':cp['save']['resources'],'space_reservation':cp['space_policy'].get('space_crew_reservation'),'space_auto':cp['hyperspace']['auto'],'input_failure':c['input_failure'],'script_errors':(d/'run.log').read_text().count('SCRIPT ERROR:')}
 out=root/arm;out.mkdir(exist_ok=True)
 for f in d.iterdir():
  if not f.is_file():continue
  if f.suffix in ['.bin','.jsonl','.log'] or f.name.endswith('.previous') or f.name.startswith('save_'):
   with open(out/(f.name+'.gz'),'wb') as z:
    with gzip.GzipFile(fileobj=z,mode='wb',mtime=0) as g:g.write(f.read_bytes())
  else:shutil.copy2(f,out/f.name)
assert result['original']['cp_x1']==result['fixed']['cp_x1'];(root/'COMPARISON.json').write_text(json.dumps(result,indent=2)+'\n')
for f in w.iterdir():
 if not f.is_file():continue
 if f.suffix=='.bin' or f.name=='decoded-pair.json':
  with open(root/(f.name+'.gz'),'wb') as z:
   with gzip.GzipFile(fileobj=z,mode='wb',mtime=0) as g:g.write(f.read_bytes())
 else:shutil.copy2(f,root/f.name)
for n in ['qa-manifest.json','.qa-import-complete.json']:shutil.copy2('/workspace/sol-validation/crew-reservation-fix-qa/'+n,root/('fixed-'+n.lstrip('.')))
print({k:{'cp':v['cp_x1'],'click_delta':v['click_delta'],'releases':len(v['releases']),'cycles':len(v['cycles']),'paid_batches':v['actual_paid_batch_count'],'failure':v['input_failure']} for k,v in result.items()})
