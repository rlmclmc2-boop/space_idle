from pathlib import Path
import json,gzip,copy,csv,hashlib,os
out=Path(__file__).resolve().parent
original=json.loads((out/'SHEET_COLUMN_CONTRACT.json').read_text());defs={s['sheet']:s for s in original['sheets']};project=Path(os.environ.get('SPACE_IDLE_AUDIT_SOURCE','/workspace/final-unified-candidate'))/'space-battleship';cfg=json.loads((project/'data/hyperspace_config.json').read_text());candidate=json.loads((project/'data/space_enemy_candidates.json').read_text());routes=json.loads((project/'data/space_enemy_routes.json').read_text());catalog=json.loads((project/'data/space_enemy_reward_catalog.json').read_text());recipes=json.loads((project/'data/space_enemy_reward_recipes.json').read_text());inventory=json.loads(gzip.decompress((out/'ALL_CURRENT_FIELDS.json.gz').read_bytes()));by_path={r['path']:r for r in inventory if r['source_file'].endswith('/hyperspace_config.json')};new=json.loads((out/'NEW_NUMERIC_FIELDS_DRAFT.json').read_text());newmap={r['path'][1:]:r for r in new if r['path'][1:] not in cfg}
books={'hyperspace_config.xlsx':[],'hyperspace_enemies.xlsx':[]};allrows={}
def attach(book,oldname,newname,rows,modify=None):
 s=copy.deepcopy(defs[oldname]);s['sheet']=newname;s['entity_id']=newname;s['workbook']=book
 if modify:modify(s)
 books[book].append(s)
 header=[c['column'] for c in s['columns']]
 data_rows=[[r.get(k) for k in header] for r in rows]
 assert all(set(r)<=set(header) for r in rows),(newname,set(rows[0])-set(header) if rows else '')
 allrows[(book,newname)]={'sheet':newname,'header':header,'description_row':[f"{c['description_zh']}｜单位：{c['unit']}｜约束：{c['constraint']}" for c in s['columns']],'type_row':[c['type'] for c in s['columns']],'data_rows':data_rows,'records':rows}
 return s
scalars=[]
for key,v in cfg.items():
 if isinstance(v,(dict,list)) or key in ['version','maximum_command_id_length']:continue
 r=by_path['/'+key];scalars.append({'key':key,'data_type':r['type'],'value':v,'unit':r['unit'],'description':r['description_zh'],'constraint':r['constraints'],'editable':r['editable_in_proposal'] or key=='amplification_start_level'})
for key,r in newmap.items():scalars.append({'key':key,'data_type':r['type'],'value':r['current_value'],'unit':r['unit'],'description':r['description_zh'],'constraint':r['constraints'],'editable':True})
attach('hyperspace_config.xlsx','标量配置','基础参数',scalars)
attach('hyperspace_config.xlsx','路线','路线',[{'order':i,'route_id':key,**row} for i,(key,row) in enumerate(cfg['routes'].items())])
qualities=[]
for i,(q,w) in enumerate(cfg['quality_weights'].items()):
 r={'order':i,'quality':q,'weight':w,'affix_limit':None,'hanging_limit':None,'weapon_level_bonus':None,'dismantle_amount':None}
 if q!='ultimate_core':r.update(affix_limit=cfg['quality_limits'][q]['affixes'],hanging_limit=cfg['quality_limits'][q]['hangings'],weapon_level_bonus=cfg['weapon_level_bonuses'][q],dismantle_amount=cfg['dismantle_amounts'][q])
 qualities.append(r)
def quality_schema(s):
 s['columns'].insert(2,copy.deepcopy(defs['奖励权重']['columns'][2]));s['columns'][1]['constraint']='white/blue/gold/legendary/ultimate_core固定集合；核心行的非weight列必须空';s['columns'][1]['description_zh']='来源品质或独占核心抽签结果'
 for c in s['columns'][3:]:c['type']='int_or_blank';c['constraint']+='；仅ultimate_core行必须空，导出时不新增对应品质字段'
 s['json_targets']+=['hyperspace_config.json /quality_weights'];s['note']='5行按order输出quality_weights；其余4种来源品质投影限制/等级奖励/拆解。究极等级奖励在基础参数；不新增第五种origin_quality。'
attach('hyperspace_config.xlsx','品质','品质',qualities,quality_schema)
attach('hyperspace_config.xlsx','舰型槽位','舰型容量',[{'order':i,'hull_id':key,'capacity':v} for i,(key,v) in enumerate(cfg['hull_capacities'].items())])
attach('hyperspace_config.xlsx','阶级权重','阶级权重',[{'order':i,'tier':int(tier),'draw_weight':v,'modernization_weight':cfg['modernization_tier_weights'][tier]} for i,(tier,v) in enumerate(cfg['tier_weights'].items())])
attach('hyperspace_config.xlsx','词缀定义','词缀定义',[{'order':i,'affix_id':key,'weapon':row['weapon'],'amplified':row['amplified']} for i,(key,row) in enumerate(cfg['affixes'].items())])
attach('hyperspace_config.xlsx','词缀区间','词缀区间',[{'affix_id':key,'tier':int(tier),'minimum':b[0],'maximum':b[1]} for key,row in cfg['affixes'].items() for tier,b in row['ranges'].items()])
attach('hyperspace_config.xlsx','挂设','挂设成长',[{'order':i,'module_id':key,**{k:row[k] for k in ['base_exp','exp_growth','effect_growth','unlock_stage']},'effects_note':'；'.join(row['effects'])} for i,(key,row) in enumerate(cfg['hanging_modules'].items())])
attach('hyperspace_config.xlsx','传说定义','传说定义',[{'order':i,'effect_id':key,'weapon':row['weapon'],'score_parameter_note':next(iter(row['parameters']), '')} for i,(key,row) in enumerate(cfg['legendary_effects'].items())])
def legend_semantics(effect,name):
 if name=='area_bonus':return '射线宽度加成比例','宽度倍率=1+area_bonus；1表示宽度×2，不是任意面积倍数'
 if name=='maximum_dodge':return '闪避概率上限，0..1','实际闪避概率=min(现有武器最高暴击概率,上限)，不是固定实际闪避率'
 if name=='damage_and_defence_bonus':return '每牺牲层伤害/防御加成比例','逐次牺牲累加；0.7为每层+70%'
 if name=='spawn_probability':return '非击杀炮击命中生成1个的概率，0..1','击杀分支使用kill_spawns绕过此概率'
 if name=='maximum_cannon_sources':return '炮类武器来源数上限/个','参与统计的炮类来源数上限'
 if name in ['damage_bonus','single_target_bonus','maximum_bonus','counter_damage_bonus']:return '加成比例；2=+200%，实际×3','加到1后作伤害倍率，不是直接倍率'
 if name=='damage_multiplier':return '直接伤害倍率','1.3表示伤害×1.3'
 if name=='maximum_multiplier_bonus':return '既有激光最大倍率的加法增量','加到既有最大倍率，不是独立总倍率'
 if name=='maximum_reduction':return '上限减伤比例','按装备未失效无人机的最大品质系数/ultimate系数折算，取最大不累加；0.5是上限50%'
 if name=='stack_multiplier':return '每已有层数的复合倍率底数','伤害=base×multiplier^layers，不是每层相加；limit关闭时stack_limit不参与'
 if name in ['delay','cooldown','period','absorption_duration']:return '游戏秒','按游戏时间计时'
 if name=='attack_period':return '特殊攻击前的普通主导弹攻击批次数','N=3为普通、普通、普通、特殊，总周期4；不按导弹颗数计数'
 if name=='blast_fraction':return '主击伤害比例','0.5表示主击伤害的50%'
 if name in ['maximum_stacks','stack_limit']:return '层','堆叠层数'
 if name=='stack_limit_enabled':return '开关','关闭时stack_limit不参与；不是倍率'
 if name=='kill_spawns':return '个','击杀后生成数量'
 if name=='nearby_targets':return '额外连锁目标/跳数','连锁额外目标数'
 if name.startswith('quality_ratios/') or name in ['white','blue','gold','legendary','ultimate']:return '无量纲相对品质系数','统御取已装备未失效无人机最大品质系数/ultimate系数；ultimate是正数归一分母，不是各品质独立减伤概率'
 if name=='bonus_per_laser':return '每激光来源加成比例','每个激光来源的加成比例'
 return '无量纲/固定枚举','现有固定效果语义；不新增消费者'
def param_schema(s):
 s['columns']=[c for c in s['columns'] if not c['column'].startswith('stored_')];s['columns'] += [copy.deepcopy(defs['传说常量']['columns'][4]),copy.deepcopy(defs['传说常量']['columns'][5])];s['json_targets']=['hyperspace_config.json /legendary_effects/*/parameters'];s['note']='同effect内order保留参数首键和随机数调用次序；stored许可范围只在固定规则_兼容说明一处导出，不重复。'
attach('hyperspace_config.xlsx','传说区间','传说随机参数',[{'effect_id':key,'order':i,'parameter':p,'minimum':b[0],'maximum':b[1],'unit':legend_semantics(key,p)[0],'description':legend_semantics(key,p)[1]} for key,row in cfg['legendary_effects'].items() for i,(p,b) in enumerate(row['parameters'].items())],param_schema)
def leaf(v,parts=()):
 if isinstance(v,dict):
  for key,child in v.items():yield from leaf(child,parts+(key,))
 elif isinstance(v,list):
  for i,child in enumerate(v):yield from leaf(child,parts+(str(i),))
 else:yield parts,v
constants=[]
for e,row in cfg['legendary_effects'].items():
 for parts,v in leaf(row['constants']):
  ptr='/legendary_effects/'+e+'/constants/'+'/'.join(parts);r=by_path[ptr];name=parts[-1];u={'delay':'游戏秒','cooldown':'游戏秒','period':'游戏秒','absorption_duration':'游戏秒','spawn_probability':'概率，1=100%','blast_fraction':'比例，1=100%','attack_period':'普通攻击批次数','maximum_stacks':'层','kill_spawns':'次','nearby_targets':'个','maximum_cannon_sources':'个','stack_limit':'层','stack_multiplier':'倍率','bonus_per_laser':'加成/激光来源'}.get(name,'无量纲/固定枚举')
  u,semantic=legend_semantics(e,'/'.join(parts));constraint=r['constraints']
  if name in ['delay','cooldown','period','absorption_duration']:constraint+='；当前支持计时参数>0，黑洞周期不得短于吸收窗口'
  if name in ['spawn_probability','blast_fraction']:constraint+='；0..1'
  if name=='ultimate' and parts[0]=='quality_ratios':constraint+='；>0，作为统御归一化分母'
  constants.append({'effect_id':e,'constant_path':'/'.join(parts),'data_type':r['type'],'value':v,'unit':u,'description':e+'：'+name+'；'+semantic+'；'+r['description_zh'],'constraint':constraint,'editable':r['editable_in_proposal']})
attach('hyperspace_config.xlsx','传说常量','传说常量',constants)
def cost_schema(s):
 s['columns'].insert(3,{'column':'resource_order','type':'int','description_zh':'同一操作中资源键的原插入顺序','unit':'0起序号','constraint':'同operation内唯一连续且锁定，不能依物理行排序','editable':False})
attach('hyperspace_config.xlsx','改造费用','改造费用',[{'operation_order':i,'operation':op,'resource_order':j,'resource':res,'amount':v} for i,(op,cost) in enumerate(cfg['forge_costs'].items()) for j,(res,v) in enumerate(cost.items())],cost_schema)
fixed=[]
for r in inventory:
 if not r['source_file'].endswith('/hyperspace_config.json'):continue
 ptr=r['path']
 if ptr in ['/version','/maximum_command_id_length'] or ptr.startswith('/policies/') or ('/hanging_modules/' in ptr and '/effects/' in ptr) or '/stored_parameter_ranges/' in ptr:
  fixed.append({'key':ptr,'data_type':r['type'],'value':r['current_value'],'unit':r['unit'],'description':r['description_zh'],'constraint':r['constraints']+'；现值锁定，只说明，不提供任意参数开关','editable':False})
def fixed_schema(s):s['json_targets']=['Existing readonly JSON leaves: version, maximum_command_id_length, policies, hanging effects labels, stored_parameter_ranges'];s['note']='key是精确既有JSON Pointer；固定/未消费/存值兼容字段锁定保留。trigger深度/审核/序列化等代码不变量只在README说明，不增假参数键。'
attach('hyperspace_config.xlsx','保护与策略','固定规则_兼容说明',fixed,fixed_schema)
# Enemy workbook
alias={'description':'des','armour_type':'armourType','shield_type':'shieldType','shield_recovery':'shieldRecovery','shield_delay':'shieldDelay','damage_multiplier':'dmgMultiple'}
enemy_rows=[]
for i,(key,row) in enumerate(candidate['enemies'].items()):
 r={'order':i,'enemy_id':int(key)}
 for c in defs['异空间敌人']['columns'][2:]:r[c['column']]=row[alias.get(c['column'],c['column'])]
 enemy_rows.append(r)
attach('hyperspace_enemies.xlsx','异空间敌人','敌人',enemy_rows)
attach('hyperspace_enemies.xlsx','敌人武器','武器安装',[{'enemy_id':int(key),'order':i,'weapon_id':row['name']} for key,e in candidate['enemies'].items() for i,row in enumerate(e['equipment'])])
attach('hyperspace_enemies.xlsx','异空间编队','编队',[{'order':i,'group_id':int(key),'description':row['description'],'tier':row['combatTier'],'reward_reference_id':row['rewardBinding']['rewardReferenceDesignId']} for i,(key,row) in enumerate(candidate['groups'].items())])
attach('hyperspace_enemies.xlsx','编队槽位','编队槽位',[{'group_id':int(key),'slot_index':i,'enemy_id':enemy,'x':row['formation_positions'][i][0],'y':row['formation_positions'][i][1]} for key,row in candidate['groups'].items() for i,enemy in enumerate(row['slots']) if enemy is not None])
attach('hyperspace_enemies.xlsx','路线编队','路线编排',[{'route_id':route,'tier':tier,'order':i,'group_id':gid} for route,row in cfg['routes'].items() for tier,groups in routes['routes'][row['weapon']].items() for i,gid in enumerate(groups)])
def reward_ref_schema(s):
 for c in s['columns']:c['editable']=False;c['constraint']+='；阶段1是冻结派生基线的只读关联预览，导入只校验等值，不改写catalog'
 s['columns'].insert(2,{'column':'reference_member_count','type':'int','description_zh':'从正式原设计组非空slots导出的参考成员数','unit':'个','constraint':'现值锁定，与正式monGroup实时派生值一致；不是第二份可调预算','editable':False})
 s['note']='catalog与1960 sources阶段1只读取/hash校验，不生成。不将早段fallback、晚段drop块或主线金额写进工作簿；本页参考ID供编队关联使用。来源缺口未补，不声称完全重生成。'
attach('hyperspace_enemies.xlsx','奖励参考','奖励参考',[{'reference_id':key,'source_design_group_id':row['source_design_group_id'],'reference_member_count':row['reference_member_count'],'late_reference_level_id':row['late_reference_actual_level_id'],'late_reference_group_id':row['late_reference_actual_group_id'],'boundary_note':'早段1..5，晚段≥6；catalog/sources冻结基线，当前无完整派生来源'} for key,row in catalog['references'].items()],reward_ref_schema)
def allocation_schema(s):
 s['columns'].insert(1,{'column':'member_order','type':'int','description_zh':'组内原recipe成员记录顺序','unit':'0起序号','constraint':'同group/slot重复值一致；组内唯一成员顺序连续；锁定；导出按它排列成员','editable':False})
 s['columns'].insert(3,{'column':'order','type':'int_or_blank','description_zh':'同成员内原ordinal数组顺序；零预算成员填空','unit':'0起序号','constraint':'同group/slot内唯一连续，锁定；数组按它输出，不按ordinal数值猜排序','editable':False})
 s['columns'][-1]['type']='int_or_blank';s['columns'][-1]['constraint']+='；零预算成员必须保留一行，order与ordinal都为空，导出[]和jewelDropRolls=0';s['primary_key']=['group_id','slot_index','order'];s['note']='每行一个预算块分配；member_order与局部order保留原数组序。enemy_id和jewelDropRolls派生。不给用户金额列。'
attach('hyperspace_enemies.xlsx','奖励成员分配','成员分配',[{'group_id':int(key),'member_order':i,'slot_index':member['slot'],'order':j if ordinal is not None else None,'reference_member_ordinal':ordinal} for key,members in recipes['groups'].items() for i,member in enumerate(members) for j,ordinal in enumerate(member['reference_member_ordinals_for_resource_blocks'] or [None])],allocation_schema)
# Coverage proof: round-trip proposed rows to existing config in memory. No workbook writing.
projected={};
for r in scalars:projected[r['key']]=r['value']
projected['routes']={r['route_id']:{'weapon':r['weapon'],'material':r['material']} for r in allrows[('hyperspace_config.xlsx','路线')]['records']}
qrows=allrows[('hyperspace_config.xlsx','品质')]['records'];projected['quality_weights']={r['quality']:r['weight'] for r in qrows};projected['quality_limits']={r['quality']:{'affixes':r['affix_limit'],'hangings':r['hanging_limit']} for r in qrows if r['quality']!='ultimate_core'};projected['weapon_level_bonuses']={r['quality']:r['weapon_level_bonus'] for r in qrows if r['quality']!='ultimate_core'};projected['dismantle_amounts']={r['quality']:r['dismantle_amount'] for r in qrows if r['quality']!='ultimate_core'}
projected['hull_capacities']={r['hull_id']:r['capacity'] for r in allrows[('hyperspace_config.xlsx','舰型容量')]['records']};tiers=allrows[('hyperspace_config.xlsx','阶级权重')]['records'];projected['tier_weights']={str(r['tier']):r['draw_weight'] for r in tiers};projected['modernization_tier_weights']={str(r['tier']):r['modernization_weight'] for r in tiers}
projected['affixes']={r['affix_id']:{'ranges':{},'amplified':r['amplified'],'weapon':r['weapon']} for r in allrows[('hyperspace_config.xlsx','词缀定义')]['records']}
for r in allrows[('hyperspace_config.xlsx','词缀区间')]['records']:projected['affixes'][r['affix_id']]['ranges'][str(r['tier'])]=[r['minimum'],r['maximum']]
projected['forge_costs']={}
for r in allrows[('hyperspace_config.xlsx','改造费用')]['records']:projected['forge_costs'].setdefault(r['operation'],{})[r['resource']]=r['amount']
projected['hanging_modules']={r['module_id']:{k:r[k] for k in ['base_exp','exp_growth','effect_growth','unlock_stage']} for r in allrows[('hyperspace_config.xlsx','挂设成长')]['records']}
projected['legendary_effects']={r['effect_id']:{'weapon':r['weapon'],'parameters':{},'constants':{}} for r in allrows[('hyperspace_config.xlsx','传说定义')]['records']}
for r in allrows[('hyperspace_config.xlsx','传说随机参数')]['records']:projected['legendary_effects'][r['effect_id']]['parameters'][r['parameter']]=[r['minimum'],r['maximum']]
def set_value(root,parts,value):
 node=root
 for i,key in enumerate(parts):
  if i==len(parts)-1:
   if isinstance(node,list):
    while len(node)<=int(key):node.append(None)
    node[int(key)]=value
   else:node[key]=value
  else:
   if isinstance(node,dict):node=node.setdefault(key,[] if parts[i+1].isdigit() else {})
   else:
    while len(node)<=int(key):node.append(None)
    node=node[int(key)]
for r in allrows[('hyperspace_config.xlsx','传说常量')]['records']:set_value(projected['legendary_effects'][r['effect_id']]['constants'],r['constant_path'].split('/'),r['value'])
for r in fixed:set_value(projected,r['key'].strip('/').split('/'),r['value'])
assert {k:projected[k] for k in cfg}==cfg;assert set(projected)==set(cfg)|set(newmap)
# Reorder every object using original dictionary skeleton; new three root fields appended.
def preserve_order(v,baseline):
 if isinstance(baseline,dict):return {k:preserve_order(v[k],x) for k,x in baseline.items()}
 if isinstance(baseline,list):return [preserve_order(a,b) for a,b in zip(v,baseline)]
 return v
ordered=preserve_order(projected,cfg);ordered.update(newmap and {k:projected[k] for k in newmap})
def dict_orders(v,p=''):
 d={}
 if isinstance(v,dict):
  d[p]=list(v)
  for k,x in v.items():d.update(dict_orders(x,p+'/'+k))
 elif isinstance(v,list):
  for i,x in enumerate(v):d.update(dict_orders(x,p+'/'+str(i)))
 return d
assert {k:v for k,v in dict_orders(ordered).items() if k!=''}=={k:v for k,v in dict_orders(cfg).items() if k!=''}
contract={'contract_version':1,'status':'machine-readable authoring interface, not production importer','source_commit':'f9d31b92d2b80af1c4b663173f12e4f6a23b8841','layout':original['layout'],'workbooks':[{'filename':name,'sheets':ss} for name,ss in books.items()],'ordering':original['ordering'],'new_numeric_defaults':new,'output_targets':['hyperspace_config.json','space_enemy_candidates.json','space_enemy_routes.json','space_enemy_reward_recipes.json'],'frozen_noneditable_inputs':{name:hashlib.sha256((project/'data'/name).read_bytes()).hexdigest() for name in ['space_enemy_reward_catalog.json','space_enemy_reward_sources.json']},'existing_root_order':list(cfg),'schema_rules':'Fixed invariant metadata stays code/locked contract. Derived candidate drop projections and audit metadata remain frozen; no mainline numeric duplicate; no old-save migration.'}
(out/'TWO_WORKBOOK_CONTRACT.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
author={'source_commit':contract['source_commit'],'contract_version':1,'workbooks':[{'filename':name,'sheets':[{k:v for k,v in allrows[(name,s['sheet'])].items() if k!='records'} for s in ss]} for name,ss in books.items()]}
(out/'WORKBOOK_CURRENT_ROWS.json').write_text(json.dumps(author,ensure_ascii=False,indent=2)+'\n')
summary={name:{s['sheet']:len(allrows[(name,s['sheet'])]['records']) for s in ss} for name,ss in books.items()}
(out/'AUTHORING_ROWS_VALIDATION.json').write_text(json.dumps({'workbook_row_counts':summary,'existing_52_config_roots_roundtrip_equal':True,'new_roots':{k:r['current_value'] for k,r in newmap.items()},'existing_config_dictionary_orders_preserved':True,'workbooks_written':False,'production_code_changed':False,'ordinal_order_preserved':True},ensure_ascii=False,indent=2)+'\n');print(json.dumps(summary,ensure_ascii=False));print('existing52-root equal; new3 numeric defaults; sheets20')
with (out/'TWO_WORKBOOK_COLUMNS.tsv').open('w',encoding='utf-8',newline='') as f:
 w=csv.DictWriter(f,fieldnames=['workbook','sheet','primary_key','column','type','description_zh','unit','constraint','editable'],delimiter='\t');w.writeheader()
 for filename,ss in books.items():
  for s in ss:
   for c in s['columns']:w.writerow({'workbook':filename,'sheet':s['sheet'],'primary_key':'+'.join(s['primary_key']),**c})
