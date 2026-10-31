import openpyxl,re,json,collections,math
from pathlib import Path
root=Path(__file__).resolve().parents[4];data=json.loads((root/'docs/ui-redesign-plan/g1-internal/art/battle/geometry.json').read_text())
def rows(f,s=None):
 w=openpyxl.load_workbook(root/'config_excel'/f,data_only=True);return list((w[s] if s else w.active).values)
m=rows('mon.xlsx');mon={r[0]:dict(zip(m[0],r)) for r in m[1:] if isinstance(r[0],int)};gs=rows('monGroup.xlsx');level=rows('level.xlsx');li=level[0].index('monGroup');reachable={int(id) for r in level[1:] for id in re.findall(r'(\d+)\s*\|',str(r[li]))};records=[]
ranked=['anchor','reactive','shielded','command'];armor={'scout':2,'sentry':2,'interceptor':1,'swarm':1,'anchor':1,'reactive':1,'shielded':1,'command':1}
def key(e,tier,leader):
 size=int(e['size']);ar=e.get('archetype_id');at=int(e.get('armourType',e.get('armour_type',0)))
 if ar not in armor or armor[ar]!=at:ar=('scout' if size==1 else 'sentry') if at==2 else ('shielded' if size==3 and float(e.get('shield') or 0)>0 else {1:'swarm',2:'interceptor',3:'reactive',4:'anchor',5:'command',6:'command'}[size])
 rank='boss' if tier in ['boss','ultimate'] and leader else 'elite' if tier=='elite' else ''
 return 'enemy_opening_'+ar+('_'+rank if ar in ranked and rank else ''),rank

def rec(gid,tier,members,source,positions=None):
 leader=max(range(len(members)),key=lambda i:members[i]['size']) if members else -1;entities=[]
 for i,e in enumerate(members):
  k,rank=key(e,tier,i==leader);span=data['enemies'][k].get('display_span',[1,1]);weapons=[]
  for wk,num in re.findall(r'([A-Za-z_\-]+)\s*\|\s*(\d+)',str(e.get('equipment',''))):weapons.extend([wk.replace('_mon','').replace('-mon','')]*int(num))
  if not weapons:weapons=e.get('weapons',['laser'])
  entities.append({'has_shield':float(e.get('shield') or 0)>0,'weapons':weapons,'source_index':i,'id':e.get('id',e.get('enemy_id')),'size':e['size'],'visual_key':k,'encounter_tier':tier,'encounter_leader':i==leader and tier in ['boss','ultimate'],'conditional_tier_span':[3,2] if rank=='boss' else [2,2] if rank=='elite' else [1,1],'conditional_art_span':span})
 if positions is None:
  positions=[None]*len(members);order=sorted(range(len(members)),key=lambda i:(-members[i]['size'],entities[i]['id'],i));nr=math.ceil(len(order)/5);cursor=0
  for row in range(nr):
   count=min(5,math.ceil((len(order)-cursor)/(nr-row)));berths=sorted(range(count),key=lambda c:(abs(c-(count-1)/2),c));spacing=min(160,456/max(1,count-1))
   for c in berths:positions[order[cursor]]=[286+(c-(count-1)/2)*spacing,140 if nr==1 else [110,270,350][row]];cursor+=1
 records.append({'current_positions':positions,'group':gid,'tier':tier,'source':source,'count':len(entities),'tier_cells':sum(x['conditional_tier_span'][0]*x['conditional_tier_span'][1] for x in entities),'art_cells':sum(x['conditional_art_span'][0]*x['conditional_art_span'][1] for x in entities),'entities':entities})
for r in gs[1:]:
 if not isinstance(r[0],int) or r[0] not in reachable:continue
 ids=[int(x) for x in re.findall(r'\d+',str(r[2])) if int(x) in mon];rec(r[0],r[3] or 'normal',[mon[i] for i in ids],'main reachable level.xlsx')
h=rows('hyperspace_enemies.xlsx','敌人');hm={r[1]:dict(zip(h[0],r)) for r in h[1:] if isinstance(r[0],int)};hs=rows('hyperspace_enemies.xlsx','编队槽位');bygroup=collections.defaultdict(list)
for r in hs[1:]:
 if isinstance(r[0],int) and isinstance(r[1],int):bygroup[r[0]].append(r)
inst=rows('hyperspace_enemies.xlsx','武器安装');installed=collections.defaultdict(list)
for r in inst[1:]:
 if isinstance(r[0],int) and isinstance(r[1],int):installed[r[0]].append((r[1],r[2].replace('_mon','').replace('-mon','')))
for id,v in hm.items():v['weapons']=[k for _,k in sorted(installed[id])]
hg=rows('hyperspace_enemies.xlsx','编队')
for r in hg[1:]:
 if isinstance(r[0],int):rec(r[1],r[3],[hm[s[2]] for s in sorted(bygroup[r[1]],key=lambda v:v[1])],'hyperspace configured routes',[[s[3],s[4]] for s in sorted(bygroup[r[1]],key=lambda v:v[1])])
result={'kind':'Conditional occupancy demand, no classification approval; art_span is authored metadata condition, tier_span is encounter-rank condition','records':records}
Path('/tmp/battle-group-demands.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
for source in ['main reachable level.xlsx','hyperspace configured routes']:
 values=[x for x in records if x['source']==source];print(source,'groups',len(values),'maxcount',max(x['count'] for x in values))
 for kind in ['art_cells','tier_cells']:
  high=sorted(values,key=lambda x:(x[kind],x['count']),reverse=True)[:4];print(kind,[(x['group'],x['tier'],x['count'],x[kind]) for x in high])
