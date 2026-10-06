import json, hashlib
from pathlib import Path
p=Path('/tmp/hyperspace-excel-audit-f9d31b9/space-battleship/data')
a=json.load(open('/tmp/hyperspace-forward-4280/AUTHORING_PACKAGE.json'));c=json.load(open('/tmp/hyperspace-forward-4280/TWO_WORKBOOK_CONTRACT.json'))
sheets={s['name']:s for w in a['workbooks'] for s in w['sheets']}
def rows(n):return [dict(zip([v['key'] for v in sheets[n]['columns']],r)) for r in sheets[n]['rows']]
def ptr(*x):return '/'+ '/'.join(str(k).replace('~','~0').replace('/','~1') for k in x)
cfg=json.loads((p/'hyperspace_config.json').read_text());mapped={}
def add(path,v):
 assert path not in mapped,('duplicate',path);mapped[path]=v
for r in rows('基础参数'):add(ptr(r['key']),r['value'])
for r in rows('固定规则_兼容说明'):add(r['key'],r['value'])
for r in rows('路线'):
 for k in ['weapon','material']:add(ptr('routes',r['route_id'],k),r[k])
for r in rows('品质'):
 q=r['quality'];add(ptr('quality_weights',q),r['weight'])
 if q=='ultimate_core':
  assert all(r[k] is None for k in ['affix_limit','hanging_limit','weapon_level_bonus','dismantle_amount']);continue
 add(ptr('quality_limits',q,'affixes'),r['affix_limit']);add(ptr('quality_limits',q,'hangings'),r['hanging_limit'])
 add(ptr('weapon_level_bonuses',q),r['weapon_level_bonus']);add(ptr('dismantle_amounts',q),r['dismantle_amount'])
for r in rows('舰型容量'):add(ptr('hull_capacities',r['hull_id']),r['capacity'])
for r in rows('阶级权重'):
 add(ptr('tier_weights',r['tier']),r['draw_weight']);add(ptr('modernization_tier_weights',r['tier']),r['modernization_weight'])
for r in rows('词缀定义'):
 for k in ['weapon','amplified']:add(ptr('affixes',r['affix_id'],k),r[k])
for r in rows('词缀区间'):
 for i,k in enumerate(['minimum','maximum']):add(ptr('affixes',r['affix_id'],'ranges',r['tier'],i),r[k])
for r in rows('挂设成长'):
 for k in ['base_exp','exp_growth','effect_growth','unlock_stage']:add(ptr('hanging_modules',r['module_id'],k),r[k])
for r in rows('传说定义'):add(ptr('legendary_effects',r['effect_id'],'weapon'),r['weapon'])
for r in rows('传说随机参数'):
 for i,k in enumerate(['minimum','maximum']):add(ptr('legendary_effects',r['effect_id'],'parameters',r['parameter'],i),r[k])
for r in rows('传说常量'):add(ptr('legendary_effects',r['effect_id'],'constants')+'/'+r['constant_path'],r['value'])
for r in rows('改造费用'):add(ptr('forge_costs',r['operation'],r['resource']),r['amount'])
def flatten(x,path=''):
 out={}
 if isinstance(x,dict):
  for k,v in x.items():out.update(flatten(v,path+ptr(k)))
 elif isinstance(x,list):
  for k,v in enumerate(x):out.update(flatten(v,path+ptr(k)))
 else:out[path]=x
 return out
f=flatten(cfg);missing=set(f)-set(mapped);extra=set(mapped)-set(f);diff=[k for k in f if k in mapped and f[k]!=mapped[k]]
assert not missing and not diff,(missing,diff)
assert extra=={'/modernization_base_coefficient','/auto_duration_crew_base','/auto_ticket_crew_base'},extra
assert c['existing_root_order']==list(cfg)
recipe=json.loads((p/'space_enemy_reward_recipes.json').read_text())['groups'];members={};sheetrows=rows('成员分配')
for r in sheetrows:
 assert (r['order'] is None)==(r['reference_member_ordinal'] is None),r
 key=(str(r['group_id']),r['member_order']);members.setdefault(key,[]).append(r)
new={};empty=0;zero=0
for (gid,order),rs in sorted(members.items(),key=lambda t:(int(t[0][0]),t[0][1])):
 slot=rs[0]['slot_index'];assert all(r['slot_index']==slot for r in rs)
 if rs[0]['order'] is None:assert len(rs)==1;ordinal=[];empty+=1
 else:
  rs.sort(key=lambda r:r['order']);assert [r['order'] for r in rs]==list(range(len(rs)));ordinal=[r['reference_member_ordinal'] for r in rs];zero+=ordinal.count(0)
 original=recipe[gid][order];assert original['slot']==slot and original['reference_member_ordinals_for_resource_blocks']==ordinal and original['jewelDropRolls']==len(ordinal),(gid,order)
 new.setdefault(gid,[]).append((slot,ordinal))
assert len(members)==sum(len(v) for v in recipe.values())
assert empty==85
cand=json.loads((p/'space_enemy_candidates.json').read_text());slots={(gid,i):v for gid,g in cand['groups'].items() for i,v in enumerate(g['slots']) if v is not None}
assert len(slots)==223
assert set((gid,rs[0]['slot_index']) for (gid,_),rs in members.items())==set(slots)
for (gid,_),rs in members.items():assert recipe[gid][rs[0]['member_order']]['enemy_id']==slots[(gid,rs[0]['slot_index'])]
frozen={k:hashlib.sha256((p/k).read_bytes()).hexdigest()==v for k,v in c['frozen_noneditable_inputs'].items()};assert all(frozen.values())
summary={'candidate':a['source_commit'],'contract':'dcf5d8ed8b179b5844daa25af3a3f79476989e9b','sheets':len(sheets),'existing_config_roots':len(cfg),'existing_config_leaves':len(f),'missing_leaves':sorted(missing),'value_differences':diff,'new_root_defaults':sorted(extra),'assignment_sheet_rows':len(sheetrows),'recipe_members':len(members),'zero_budget_members_preserved':empty,'nonempty_ordinal_0_occurrences':zero,'all_nonempty_fleet_slots_covered':len(slots),'frozen_hash_matches':frozen,'sources_waves':len(json.loads((p/'space_enemy_reward_sources.json').read_text())['waves']),'scope':'Read-only package checks, not final XLSX/import/runtime acceptance'}
print(json.dumps(summary,ensure_ascii=False,indent=2))
Path('/tmp/hyperspace-forward-4280/package-check.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
