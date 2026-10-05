"""Index actual cleared-stage snapshots; highestLevel=N is not clear N."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--directory',type=Path,required=True);p.add_argument('--source-manifest',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
manifest=json.loads(a.source_manifest.read_text());rows=[]
for f in a.directory.rglob('save_*.json'):
 try:
  d=json.loads(f.read_text());s=d['save']
  if d['code_fingerprint']!=manifest['fingerprint']:continue
  rows.append({'path':str(f.resolve()),'x1':d['x1_seconds'],'round':s['hyperspace']['round_id'],'highest':s['highestLevel'],'cleared':s['cleared'],'journey':s.get('journey',{}),'active_manual':s['hyperspace']['active'].get('mode')=='manual','reforges':s['hyperspace']['inventory']['reforge_count']})
 except (KeyError,ValueError,OSError):continue
rows.sort(key=lambda r:r['x1']);phases={}
for round_id in sorted({int(r['round']) for r in rows}):
 same=[r for r in rows if int(r['round'])==round_id]
 for stage in [10,20,30,34,35,60]:
  match=next((r for r in same if stage in r['cleared']),None)
  if match:phases[f'round{round_id}-clear{stage}']=match
post=next((r for r in rows if r['reforges']>0),None)
if post:
 phases['first-post-reforge']=post;pre=next((r for r in reversed(rows) if r['x1']<post['x1'] and r['reforges']==0),None)
 if pre:phases['last-pre-reforge-snapshot']={**pre,'gap_to_first_post_snapshot':post['x1']-pre['x1'],'scope':'Nearest recorded snapshot; not guaranteed the instant before the transaction'}
result={'source_manifest':str(a.source_manifest),'phases':phases,'snapshots':rows,'scope':'Only matching fingerprint snapshots; cleared list is authority. Passive probe accepts these JSON snapshots. Native policy continuation uses complete checkpoint.bin; JSON snapshots omit QA memory.'};a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2));print(json.dumps(phases,indent=2))
