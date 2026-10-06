from pathlib import Path
import runpy,json,copy,random,csv,gzip
out=Path(__file__).resolve().parent
ns=runpy.run_path(str(out/'build-two-workbook-contract.py')); tables=ns['allrows'];contract=json.loads((out/'TWO_WORKBOOK_CONTRACT.json').read_text())
baselines={n:ns[k] for n,k in [('space_enemy_candidates.json','candidate'),('space_enemy_routes.json','routes'),('space_enemy_reward_recipes.json','recipes')]}
def records(name,tab):return tab[('hyperspace_enemies.xlsx',name)]['records']
def project(tab):
 c=copy.deepcopy(ns['candidate']);r=copy.deepcopy(ns['routes']);p=copy.deepcopy(ns['recipes'])
 es=sorted(records('敌人',tab),key=lambda a:a['order']);c['enemies']={str(a['enemy_id']):c['enemies'][str(a['enemy_id'])] for a in es}
 for a in es:
  e=c['enemies'][str(a['enemy_id'])]
  for k,v in a.items():
   if k not in ['order','enemy_id']:e[ns['alias'].get(k,k)]=v
  mounts=sorted([m for m in records('武器安装',tab) if m['enemy_id']==a['enemy_id']],key=lambda m:m['order']);e['equipment']=[{'name':m['weapon_id']} for m in mounts]
 gs=sorted(records('编队',tab),key=lambda a:a['order']);c['groups']={str(a['group_id']):c['groups'][str(a['group_id'])] for a in gs}
 for a in gs:
  g=c['groups'][str(a['group_id'])];g['description']=a['description'];g['combatTier']=a['tier'];g['rewardBinding']['rewardReferenceDesignId']=a['reward_reference_id']
  old_positions=g['formation_positions'];g['slots']=[None]*15;g['formation_positions']=copy.deepcopy(old_positions)
  for s in records('编队槽位',tab):
   if s['group_id']==a['group_id']:g['slots'][s['slot_index']]=s['enemy_id'];g['formation_positions'][s['slot_index']]=[s['x'],s['y']]
 for route,cr in ns['cfg']['routes'].items():
  for tier in r['routes'][cr['weapon']]:r['routes'][cr['weapon']][tier]=[a['group_id'] for a in sorted(records('路线编排',tab),key=lambda a:a['order']) if a['route_id']==route and a['tier']==tier]
 for gid in p['groups']:
  allocations=[a for a in records('成员分配',tab) if a['group_id']==int(gid)];members={}
  for a in allocations:
   aa=members.setdefault((a['member_order'],a['slot_index']),[])
   if a['reference_member_ordinal'] is not None:aa.append(a)
  p['groups'][gid]=[{'slot':slot,'enemy_id':c['groups'][gid]['slots'][slot],'jewelDropRolls':len(aa),'reference_member_ordinals_for_resource_blocks':[a['reference_member_ordinal'] for a in sorted(aa,key=lambda a:a['order'])]} for (_,slot),aa in sorted(members.items())]
 return dict(zip(baselines,[c,r,p]))
for mode in ['original','shuffled']:
 t=copy.deepcopy(tables)
 if mode=='shuffled':
  rng=random.Random(20261006)
  for x in t.values():rng.shuffle(x['records'])
 for n,v in project(t).items():
  
  assert v==baselines[n],(mode,n)
  assert ns['dict_orders'](v)==ns['dict_orders'](baselines[n]),(mode,n,'dictionary ordering')
# Spreadsheet authoring adapter: one envelope containing contract + typed rows.
rowbook=json.loads((out/'WORKBOOK_CURRENT_ROWS.json').read_text());adapter={'source_commit':contract['source_commit'],'contract_version':1,'workbooks':[]}
for b in contract['workbooks']:
 rb=next(x for x in rowbook['workbooks'] if x['filename']==b['filename']);sheets=[]
 for s in b['sheets']:
  ar=next(x for x in rb['sheets'] if x['sheet']==s['sheet']);columns=[{'key':c['column'],'description':c['description_zh'],'type':c['type'],'unit':c['unit'],'constraint':c['constraint'],'editable':c['editable']} for c in s['columns']]
  assert ar['header']==[c['key'] for c in columns]
  assert all(len(row)==len(columns) for row in ar['data_rows'])
  readonly=all(not c['editable'] for c in columns)
  item={'name':s['sheet'],'columns':columns,'rows':ar['data_rows'],'readonly':readonly,'primary_key':s['primary_key']}
  if 'editable' in ar['header']:item['readonly_rows']=[i for i,row in enumerate(ar['data_rows']) if row[ar['header'].index('editable')] is False]
  sheets.append(item)
 adapter['workbooks'].append({'filename':b['filename'],'sheets':sheets})
(out/'AUTHORING_PACKAGE.json').write_text(json.dumps(adapter,ensure_ascii=False,indent=2)+'\n')
report=json.loads((out/'AUTHORING_ROWS_VALIDATION.json').read_text());report.update(enemy_route_recipe_roundtrip_equal=True,enemy_route_recipe_dict_orders_equal=True,shuffled_physical_rows_same_enemy_route_recipe_output=True,config_shuffle_verification='Fixed PK/order schema specified; full production importer shuffle check pending implementation',forward_semantics_reference='12ed3f896218deebb083e99c0300629028670cef',frozen_inputs=contract['frozen_noneditable_inputs'])
(out/'AUTHORING_ROWS_VALIDATION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
# Synchronize current field tables without changing any business value.
rows=json.loads(gzip.decompress((out/'ALL_CURRENT_FIELDS.json.gz').read_bytes()));old=list(csv.DictReader((out/'CONFIG_FIELDS.tsv').open(),delimiter='\t'));mapped={r['path']:r for r in rows if r['source_file'].endswith('/hyperspace_config.json')}
with (out/'CONFIG_FIELDS.tsv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(old[0]),delimiter='\t');w.writeheader()
 for a in old:
  r=mapped[a['path']]
  for key in a:
   if key in ['unit','description_zh','constraints','editable_in_proposal']:a[key]=r[key]
  w.writerow(a)
with gzip.open(out/'ALL_CURRENT_FIELDS.tsv.gz','wt',encoding='utf-8',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]),delimiter='\t');w.writeheader()
 for r in rows:w.writerow({k:json.dumps(v,ensure_ascii=False) if isinstance(v,(dict,list)) else v for k,v in r.items()})
print('PASS: original/shuffled enemy/routes/recipes exact projections; authoring envelope; no Excel/code writes')
