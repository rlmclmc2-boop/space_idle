from pathlib import Path
import json,gzip,copy,csv,hashlib,os
out=Path(__file__).resolve().parent
original=json.loads((out/'SHEET_COLUMN_CONTRACT.json').read_text());defs={s['sheet']:s for s in original['sheets']};project=Path(os.environ.get('SPACE_IDLE_AUDIT_SOURCE','/workspace/final-unified-candidate'))/'space-battleship';cfg=json.loads((project/'data/hyperspace_config.json').read_text());candidate=json.loads((project/'data/space_enemy_candidates.json').read_text());routes=json.loads((project/'data/space_enemy_routes.json').read_text());catalog=json.loads((project/'data/space_enemy_reward_catalog.json').read_text());recipes=json.loads((project/'data/space_enemy_reward_recipes.json').read_text());inventory=json.loads(gzip.decompress((out/'ALL_CURRENT_FIELDS.json.gz').read_bytes()));by_path={r['path']:r for r in inventory if r['source_file'].endswith('/hyperspace_config.json')};new=json.loads((out/'NEW_NUMERIC_FIELDS_DRAFT.json').read_text());newmap={r['path'][1:]:r for r in new if r['path'][1:] not in cfg}
books={'hyperspace_config.xlsx':[],'hyperspace_enemies.xlsx':[]};allrows={}
def attach(book,oldname,newname,rows,modify=None):
 s=copy.deepcopy(defs[oldname]);s['sheet']=newname;s['entity_id']=newname;s['workbook']=book
 if modify:modify(s)
 for c in s['columns']:
  if c['column'] in s['primary_key']:
   c['editable']=False;c['constraint']+='；固定结构身份列，必须与基线等值，不能只改物理行冒充结构变化'
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
def original_legend_semantics(effect,name):
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
def legend_semantics(effect,name):
 specific={
 ('higgs_cannon','damage_bonus'):('炮伤害加成比例；2=+200%，实际×3','希格斯作用于炮类输出。调大炮伤更高，调小更低；是(1+加成)，不是直接倍率。'),
 ('higgs_cannon','area_bonus'):('射线宽度加成比例','希格斯炮射线宽度×(1+此值)。调大覆盖横向范围更宽，调小更窄；1表示宽度×2，不是面积×2。'),
 ('higgs_cannon','maximum_cannon_sources'):('炮类武器来源数上限/个','希格斯装备组合限制：主舰及无人机的炮类来源总数不得超过此值。调大放宽炮源组合，调小更严格；不是伤害倍率。'),
 ('scatter_pulse','single_target_bonus'):('单目标激光伤害加成比例','只有一个存活目标时，激光伤害×(1+此值)。调大单目标伤害更高，调小更低；2为实际×3。'),
 ('precise_guidance','stack_multiplier'):('每已有层数的复合倍率底数','精确制导按每目标已有命中层数：伤害=base×此值^layers。调大后续命中成长更快，调小更慢；1.5为每层再×1.5，不是固定加50%。'),
 ('precise_guidance','stack_limit_enabled'):('既有层数封顶开关','true时将下一层限制在stack_limit，false时不封顶。已有实现的上限设置，默认false；不是单层伤害加成。'),
 ('precise_guidance','stack_limit'):('最大累计命中层数/层','只有stack_limit_enabled=true才使用。调大允许更高复合层数，调小更早封顶；默认0且开关关闭，不表示默认无加成。'),
 ('precise_guidance','counting_policy'):('固定命中计数说明','只读、此字符串未被消费者读取。实际固定为每发射批次对每目标的首次命中计层，二次/连锁不无限叠层；改文字不改变规则。'),
 ('prism_tower','nearby_targets'):('额外连锁目标/跳数','棱镜塔主激光允许的额外连锁目标数。调大可波及更多目标，调小更少；仍需实际存在合法目标。'),
 ('prism_tower','maximum_towers'):('塔数量说明/个','只读、未消费字段，实际实现同一时刻只有一座激活棱镜塔。保持1；修改此值不能增加塔数量。'),
 ('prism_tower','maximum_multiplier_bonus'):('激光既有最大倍率的加法增量','棱镜塔增加持续激光既有最大倍率上限。调大上限更高，调小更低；加1.3到原上限，不是独立总倍率×1.3。'),
 ('strange_matter','damage_multiplier'):('直接伤害倍率','奇异物质延迟生成炮击的伤害为触发命中原伤害×此值。调大生成伤害更高，调小更低；1.3即×1.3。'),
 ('strange_matter','spawn_probability'):('非击杀炮击命中生成1个的概率，0..1','调大非击杀命中更易生成，调小更少；0.4为40%。击杀直接按kill_spawns生成，不经过本概率。'),
 ('strange_matter','delay'):('游戏秒','奇异物质生成的炮击从触发到释放的延迟。调大更晚释放，调小更早；不提高伤害或生成概率。'),
 ('strange_matter','kill_spawns'):('击杀生成数量/个','炮击已击杀目标时固定生成此数量的奇异物质炮击。调大击杀后更多，调小更少；不乘spawn_probability。'),
 ('laser_charge','maximum_bonus'):('激光伤害加成上限比例','镭射充能伤害×(1+min(此值,每激光来源加成×激光来源数))。调大只提高上限，来源不足时不增加伤害；2为最多实际×3。'),
 ('laser_charge','bonus_per_laser'):('每激光来源加成比例','镭射充能按主舰及无人机激光来源数累加，并受maximum_bonus封顶。调大每个来源收益更高，调小更低；0.5为每源+50%。'),
 ('wild_missile','attack_period'):('特殊攻击前的普通主导弹攻击批次数','狂野导弹按主发射批次计数。调大特殊攻击更稀疏，调小更频繁；N=3为普通、普通、普通、特殊，总周期4，不按单颗弹计。'),
 ('wild_missile','blast_fraction'):('特殊主击伤害比例，0..1','狂野导弹额外爆炸按特殊主击伤害乘此值。调大爆炸更强，调小更弱；0.5为主击的50%，不是发生概率。'),
 ('wild_missile','damage_multiplier'):('特殊导弹直接伤害倍率','狂野导弹特殊主攻击伤害乘此值。调大特殊攻击更强，调小更弱；7即×7，不是+700%。普通攻击频率另由attack_period控制。'),
 ('endless_beam','maximum_multiplier_bonus'):('激光既有最大倍率的加法增量','无尽光束增加持续激光既有最大倍率上限。调大上限更高，调小更低；加到原上限，不是独立总倍率。'),
 ('dodge_counter','maximum_dodge'):('闪避概率上限，0..1','实际=min(现有武器最高暴击概率,此上限)。调大只放宽上限，武器暴击不足时无增益；0.75是最多75%，不是固定实际闪避率。'),
 ('dodge_counter','counter_damage_bonus'):('闪避反击伤害加成比例','触发且反击冷却已到的武器反击伤害×(1+此值)。调大反击更强，调小更弱；0.7为实际×1.7。'),
 ('dodge_counter','cooldown'):('反击冷却游戏秒','限制闪避后发起反击的最短间隔，不限制本身闪避判定。调大反击更稀疏，调小更频繁；必须>0。'),
 ('drone_master','maximum_reduction'):('舰队品质折算的减伤上限比例','统御实际减伤=此值×已装备未失效机的最大品质系数/究极系数。调大减伤更强，调小更弱；取最大不累加，0.5为究极条件下最多50%。'),
 ('black_hole','period'):('两次开启间隔/游戏秒','黑洞两次开启的间隔，包含吸收窗口。调大开启更稀疏，调小更频繁；必须≥absorption_duration，首次也需等待此间隔。'),
 ('black_hole','absorption_duration'):('吸收窗口/游戏秒','黑洞窗口内吸收敌方攻击，并累计己方攻击伤害，结束时释放。调大覆盖时间更长且爆发更晚，调小更短更早；不得超过period。'),
 ('black_hole','damage_multiplier'):('储存己方伤害释放倍率','黑洞结束时把窗口内储存的己方攻击伤害乘此值释放。调大释放伤害更高，调小更低；敌方被吸收伤害不加入储存。'),
 ('drone_rebuild','maximum_stacks'):('本战斗牺牲重建层数上限/层','重建最多牺牲此数量的可用无人机，每次增加一层。调大允许更多次重建，调小更少；还受实际可牺牲无人机数限制，不销毁仓库机。'),
 ('drone_rebuild','damage_and_defence_bonus'):('每牺牲层伤害及防御加成比例','每次牺牲重建把此值累加到伤害/防御加成。调大每层更强，调小更弱；0.7每层+70%，两层+140%后乘×2.4。')}
 if (effect,name) in specific:return specific[(effect,name)]
 if effect=='drone_master' and name.startswith('quality_ratios/'):
  quality=name.split('/')[-1]
  if quality=='ultimate':return '品质归一化分母/无量纲','究极品质系数同时作为分母，必须>0且不小于其他品质系数。单独调大降低非究极品质折算，调小反之；究极自身比值仍1。'
  return '相对品质系数/无量纲','统御取已装备未失效无人机中最高品质系数。调大此品质系数可提高它的减伤折算，调小更低；必须0..究极系数，不是独立减伤概率。'
 return original_legend_semantics(effect,name)
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
 for c in s['columns']:c['editable']=False;c['constraint']+='；阶段1是固定只读来源关联；catalog预算由正式主线及早段回退预算唯一派生'
 s['columns'].insert(2,{'column':'reference_member_count','type':'int','description_zh':'从正式原设计组非空slots导出的参考成员数','unit':'个','constraint':'现值锁定，与正式monGroup实时派生值一致；不是第二份可调预算','editable':False})
 s['note']='本页固定来源关联只读；catalog的15早段/40晚段预算从本次主线投影刷新；25无早段实例的95块独立预算见早段回退预算；sources1960结构冻结并校验。'
attach('hyperspace_enemies.xlsx','奖励参考','奖励参考',[{'reference_id':key,'source_design_group_id':row['source_design_group_id'],'reference_member_count':row['reference_member_count'],'late_reference_level_id':row['late_reference_actual_level_id'],'late_reference_group_id':row['late_reference_actual_group_id'],'boundary_note':'早段1..5，晚段≥6；已有预算取主线，95独立块取回退预算页；sources结构冻结'} for key,row in catalog['references'].items()],reward_ref_schema)
def allocation_schema(s):
 s['columns'].insert(1,{'column':'member_order','type':'int','description_zh':'组内原recipe成员记录顺序','unit':'0起序号','constraint':'同group/slot重复值一致；组内唯一成员顺序连续；锁定；导出按它排列成员','editable':False})
 s['columns'].insert(3,{'column':'order','type':'int_or_blank','description_zh':'同成员内原ordinal数组顺序；零预算成员填空','unit':'0起序号','constraint':'同group/slot内唯一连续，锁定；数组按它输出，不按ordinal数值猜排序','editable':False})
 s['columns'][-1]['type']='int_or_blank';s['columns'][-1]['constraint']+='；零预算成员必须保留一行，order与ordinal都为空，导出[]和jewelDropRolls=0';s['primary_key']=['group_id','slot_index','order'];s['note']='每行一个预算块分配；member_order与局部order保留原数组序。enemy_id和jewelDropRolls派生。不给用户金额列。'
attach('hyperspace_enemies.xlsx','奖励成员分配','成员分配',[{'group_id':int(key),'member_order':i,'slot_index':member['slot'],'order':j if ordinal is not None else None,'reference_member_ordinal':ordinal} for key,members in recipes['groups'].items() for i,member in enumerate(members) for j,ordinal in enumerate(member['reference_member_ordinals_for_resource_blocks'] or [None])],allocation_schema)
# Only the 25 references without early mainline instances own editable fallback numbers.
defs['早段回退预算']={'sheet':'早段回退预算','primary_key':['reference_id','reference_member_ordinal','drop_order'],'columns':[
 {'column':'reference_id','type':'string','description_zh':'无早段主线实例的既有奖励参考ID','unit':'稳定ID','constraint':'仅既有25参考；锁定；不复制有主线来源的预算','editable':False},
 {'column':'reference_member_ordinal','type':'int','description_zh':'参考成员预算块索引','unit':'0起索引','constraint':'每参考0..count-1；原95块结构锁定','editable':False},
 {'column':'drop_order','type':'int','description_zh':'块内掉落数组顺序','unit':'0起序号','constraint':'现有每块一项，order0锁定；不新增条目','editable':False},
 {'column':'resource_id','type':'int','description_zh':'回退掉落资源引用','unit':'正式res资源ID','constraint':'必须存在于本次正式主线投影resources；不复制资源本身数值','editable':True},
 {'column':'amount','type':'number','description_zh':'仅来源无匹配且资源参考关≤5时的回退掉落数量','unit':'资源份/预算块','constraint':'非负有限且<9e15；不影响15已有主线早段模板及40晚段预算','editable':True},
 {'column':'chance','type':'float','description_zh':'该回退掉落发生概率','unit':'概率，1=100%','constraint':'有限，0..1','editable':True}],
 'json_targets':['space_enemy_reward_catalog.json /references/*/early_drop_blocks'],
 'note':'仅25无实例参考的95块真实独立回退数值。15有实例早段及40晚段从本次主线投影刷新，不作为第二个金额权威。'}
attach('hyperspace_enemies.xlsx','早段回退预算','早段回退预算',[{'reference_id':key,'reference_member_ordinal':i,'drop_order':j,'resource_id':drop['resourceId'],'amount':drop['amount'],'chance':drop['chance']} for key,ref in catalog['references'].items() if not ref['early_existing_encounters'] for i,block in enumerate(ref['early_drop_blocks']) for j,drop in enumerate(block)])
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
# Consumer-reviewed Chinese remarks; separate from all business literals/types/orders.
remarks=json.loads((out/'INDEPENDENT_REMARKS_SUGGESTIONS.json').read_text())
identity_columns={'基础参数':['key'],'传说随机参数':['effect_id','parameter'],'传说常量':['effect_id','constant_path']}
for advice in remarks['rows']:
 table=allrows[('hyperspace_config.xlsx',advice['sheet'])]
 record=next(r for r in table['records'] if [r[k] for k in identity_columns[advice['sheet']]]==advice['identity'])
 record['unit']=advice['unit'];record['description']=advice['description']
 # Keep expanded examples/directions already reviewed, except where the suggestion fixes a subtle source rule.
 if advice['sheet']=='基础参数' and advice['identity'][0] not in ['initial_retention_capacity','retention_capacity_gain']:
  details=by_path.get('/'+advice['identity'][0],newmap.get(advice['identity'][0],{})).get('description_zh','')
  if '调小' in details and '调小' not in record['description']:record['description']+=' '+details
for book,ss in books.items():
 for definition in ss:
  table=allrows[(book,definition['sheet'])]
  for column in definition['columns']:
   suggestion=remarks['column_descriptions'].get(definition['sheet'],{}).get(column['column'])
   if suggestion:column['description_zh']=suggestion
   if column['column'] in definition['primary_key']:column['editable']=False
  header=[c['column'] for c in definition['columns']]
  table['data_rows']=[[r.get(k) for k in header] for r in table['records']]
  table['description_row']=[f"{c['description_zh']}｜单位：{c['unit']}｜约束：{c['constraint']}" for c in definition['columns']]
contract={'contract_version':1,'status':'machine-readable authoring interface, not production importer','source_commit':'f9d31b92d2b80af1c4b663173f12e4f6a23b8841','layout':original['layout'],'workbooks':[{'filename':name,'sheets':ss} for name,ss in books.items()],'ordering':original['ordering'],'new_numeric_defaults':new,'output_targets':['hyperspace_config.json','space_enemy_candidates.json','space_enemy_routes.json','space_enemy_reward_recipes.json','space_enemy_reward_catalog.json'],'frozen_noneditable_inputs':{name:hashlib.sha256((project/'data'/name).read_bytes()).hexdigest() for name in ['space_enemy_reward_sources.json']},'existing_root_order':list(cfg),'catalog_derivation':{'late':'Each reference late_reference_actual_group_id current mainline drops in occupied slot order','early_existing':'First listed early_existing_encounters current mainline group drops; validate every listed group identity/count','early_without_instance':'Only95 literal drop rows from早段回退预算','metadata':'Keep fixed reference identity/order and source_hashes audit origin; not a new acceptance certificate'},'schema_rules':'Fixed invariant metadata stays code/locked contract. Derived candidate drop projections and audit metadata remain frozen; no mainline numeric duplicate; no old-save migration.'}
(out/'TWO_WORKBOOK_CONTRACT.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
author={'source_commit':contract['source_commit'],'contract_version':1,'workbooks':[{'filename':name,'sheets':[{k:v for k,v in allrows[(name,s['sheet'])].items() if k!='records'} for s in ss]} for name,ss in books.items()]}
(out/'WORKBOOK_CURRENT_ROWS.json').write_text(json.dumps(author,ensure_ascii=False,indent=2)+'\n')
summary={name:{s['sheet']:len(allrows[(name,s['sheet'])]['records']) for s in ss} for name,ss in books.items()}
(out/'AUTHORING_ROWS_VALIDATION.json').write_text(json.dumps({'workbook_row_counts':summary,'existing_52_config_roots_roundtrip_equal':True,'new_roots':{k:r['current_value'] for k,r in newmap.items()},'existing_config_dictionary_orders_preserved':True,'workbooks_written':False,'production_code_changed':False,'ordinal_order_preserved':True},ensure_ascii=False,indent=2)+'\n');print(json.dumps(summary,ensure_ascii=False));print('existing52-root equal; new3 numeric defaults; sheets21')
with (out/'TWO_WORKBOOK_COLUMNS.tsv').open('w',encoding='utf-8',newline='') as f:
 w=csv.DictWriter(f,fieldnames=['workbook','sheet','primary_key','column','type','description_zh','unit','constraint','editable'],delimiter='\t');w.writeheader()
 for filename,ss in books.items():
  for s in ss:
   for c in s['columns']:w.writerow({'workbook':filename,'sheet':s['sheet'],'primary_key':'+'.join(s['primary_key']),**c})
