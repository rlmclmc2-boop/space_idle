from pathlib import Path
import sys,json,csv,gzip,hashlib,re,subprocess,collections,os
sys.dont_write_bytecode=True
repo=Path(os.environ.get('SPACE_IDLE_AUDIT_SOURCE','/workspace/final-unified-candidate'));project=repo/'space-battleship';out=Path(__file__).resolve().parent;pin='f9d31b92d2b80af1c4b663173f12e4f6a23b8841'
assert subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD']).decode().strip()==pin
sys.path.insert(0,str(project/'tools'));import hyperspace_workbook as hw;import openpyxl
files=['hyperspace_config.json','space_enemy_candidates.json','space_enemy_routes.json','space_enemy_reward_catalog.json','space_enemy_reward_recipes.json','space_enemy_reward_sources.json'];data={name:json.loads((project/'data'/name).read_text()) for name in files};config=data[files[0]]
assert hw.read_config((project/'config_excel/hyperspace_config.xlsx').read_bytes())==config
book=openpyxl.load_workbook(project/'config_excel/hyperspace_config.xlsx',read_only=True,data_only=False);sheet=book.active;xrows={('' if row[0].value is None else row[0].value):{'row':row_index,'type':row[1].value,'value':row[2].value} for row_index,row in enumerate(sheet.iter_rows(min_row=2),2)};book_rows=sheet.max_row;book.close()
scripts={p.name:p.read_text() for p in (project/'scripts').glob('*.gd')}
def refs(file,needle):
 return [f'space-battleship/scripts/{file}:{i}' for i,line in enumerate(scripts[file].splitlines(),1) if needle in line]
def node_type(v):return 'null' if v is None else 'bool' if isinstance(v,bool) else 'int' if isinstance(v,int) else 'float' if isinstance(v,float) else 'string' if isinstance(v,str) else 'array' if isinstance(v,list) else 'object'
def esc(s):return str(s).replace('~','~0').replace('/','~1')
def walk(v,parts=()):
 yield parts,v
 if isinstance(v,dict):
  for key,child in v.items():yield from walk(child,parts+(str(key),))
 elif isinstance(v,list):
  for i,child in enumerate(v):yield from walk(child,parts+(str(i),))
root_description={
'version':'配置格式版本；协议常量，不是策划参数','unlock_stage':'异空间可用最高到达关卡门槛','minimum_level':'允许探索的最低关卡','energy_rate':'在线游戏时间每秒充能','energy_cap':'基础能量容量；自动探索需满容量才派发','ticket':'手动探索基础票耗','minimum_duration':'自动探索最短耗时',
'warehouse_capacity':'基础仓库容量','overflow_capacity':'溢出仓固定容量','reforge_capacity_gain':'每次重铸增加仓库格数','initial_retention_capacity':'初始保留容量','retention_capacity_gain':'每次重铸增加保留格数','maximum_equipped':'全局无人机装备上限','maximum_legendary':'同时装备传说数量上限','maximum_ultimate':'同时装备究极数量上限','completion_budget':'单次advance最多结算数，性能保护而非奖励倍率',
'routes':'异空间路线到武器/专属材料的关联','quality_limits':'各来源品质词缀/挂设上限','modernization_tier_weights':'现代化费用的词缀阶级附加系数','hull_capacities':'按现有舰型ID的无人机槽位','quality_weights':'奖励结果相对抽签权重；总和1.09不代表独立概率','weapon_level_bonuses':'按来源品质增加武器有效等级，蓝色来源奖励保留','ultimate_weapon_bonus':'究极武器有效等级加成','affix_initial_probability':'首个词缀抽取概率','hanging_initial_probability':'首个挂设槽抽取概率','additional_probability_factor':'后续槽位概率递乘因子','tier_weights':'词缀阶级相对抽签/升阶判定权重','value_precision':'随机参数量化网格','amplification_rate':'每级放大增长率','amplification_start_level':'声明的放大起始等级；当前代码实际写死4','material_base_reward':'探索基础材料奖励','material_reward_level_step':'每隔多少关增加1份基础材料','material_reward_start_level':'材料成长起点，同时用于现代化报价；保留联动','dismantle_amounts':'按品质的拆解材料数和随机挂设副本数','maximum_filter_conditions':'筛选条件数量安全上限','maximum_filter_string_length':'筛选导入文本长度安全上限','maximum_forecast_attempts':'改造预估循环次数安全上限','maximum_command_id_length':'未消费的命令ID长度说明，不应假装有效参数','policies':'已支持策略或固定规则声明；未消费项锁定','forge_costs':'改造操作各材料/核心单价','lock_cost_multiplier':'每个已锁词缀对下次锁定费用的倍增系数','reroll_guarantee_multiplier':'保底最大值重洗的期望价倍数','modernization_cost_base':'现代化费用基数与舍入粒度','modernization_level_step':'现代化等级成本步长','modernization_legendary_multiplier':'传说现代化费用乘数','affixes':'已实现词缀定义、适用武器及各阶原值区间','hanging_modules':'已实现挂设的经验与效果成长','legendary_effects':'已实现传说效果参数区间与固定常量','late_supply_unlock_stage':'已通主线关卡达到后期补给门槛','late_energy_rate_multiplier':'后期充能最大倍率','late_material_reward_multiplier':'后期材料最大倍率','late_supply_ramp_seconds':'后期补给在线爬升时长'}
root_units={'energy_rate':'能量/游戏秒','energy_cap':'能量','ticket':'能量/次','minimum_duration':'游戏秒','late_supply_ramp_seconds':'游戏秒','unlock_stage':'关','minimum_level':'关','late_supply_unlock_stage':'关','material_reward_start_level':'关','material_reward_level_step':'关/份','modernization_level_step':'关','amplification_start_level':'关','material_base_reward':'份','modernization_cost_base':'材料份','warehouse_capacity':'格','overflow_capacity':'格','reforge_capacity_gain':'格/重铸','initial_retention_capacity':'格','retention_capacity_gain':'格/重铸','maximum_equipped':'架','maximum_legendary':'架','maximum_ultimate':'架','maximum_command_id_length':'字符','maximum_filter_string_length':'字符','maximum_filter_conditions':'条','maximum_forecast_attempts':'次','completion_budget':'次/advance','version':'版本号','ultimate_weapon_bonus':'有效等级','maximum_preset_count':'组'}
root_tables={'routes':'路线','quality_limits':'品质限制','hull_capacities':'舰型槽位','quality_weights':'奖励结果权重','weapon_level_bonuses':'品质等级奖励','modernization_tier_weights':'词缀阶级权重','tier_weights':'词缀阶级权重','dismantle_amounts':'品质拆解奖励','forge_costs':'改造费用','affixes':'词缀定义与阶级区间','hanging_modules':'挂设成长','legendary_effects':'传说参数与常量','policies':'固定规则与已支持策略'}
technical={'version','completion_budget','maximum_filter_conditions','maximum_filter_string_length','maximum_forecast_attempts','maximum_command_id_length'}
dead_roots={'amplification_start_level','maximum_command_id_length'}
dead_policy={'legendary_selection','sealed_unlock'}
def config_info(parts):
 root=parts[0];consumer_files=[];needle=root;status='consumed';kind='balance';editable=True;note=root_description[root];unit=root_units.get(root,'无量纲/按字段');table=root_tables.get(root,'全局标量')
 if root in technical:kind='technical_or_schema';editable=False;table='安全与运行约束（锁定）'
 if root in dead_roots:status='not_consumed';editable=False
 if root in ['energy_rate','energy_cap','late_energy_rate_multiplier','late_supply_ramp_seconds','late_supply_unlock_stage','late_material_reward_multiplier']:consumer_files=['hyperspace_system.gd','hyperspace_scheduler.gd']
 elif root in ['minimum_duration','ticket','minimum_level','unlock_stage']:consumer_files=['hyperspace_system.gd','hyperspace_panel.gd','hyperspace_commands.gd']
 elif root in ['warehouse_capacity','overflow_capacity','reforge_capacity_gain','initial_retention_capacity','retention_capacity_gain','maximum_equipped','maximum_legendary','maximum_ultimate','hull_capacities','quality_limits']:consumer_files=['drone_inventory.gd','hyperspace_permissions.gd','drone_rewards.gd']
 elif root in ['weapon_level_bonuses','ultimate_weapon_bonus','amplification_rate','amplification_start_level']:consumer_files=['drone_effect_aggregator.gd']
 elif root=='forge_costs' or root.startswith('modernization_') or root in ['lock_cost_multiplier','reroll_guarantee_multiplier','maximum_forecast_attempts']:consumer_files=['drone_forge.gd','hyperspace_commands.gd']
 elif root in ['maximum_filter_conditions','maximum_filter_string_length']:consumer_files=['hyperspace_filter.gd']
 elif root=='completion_budget':consumer_files=['hyperspace_scheduler.gd']
 elif root=='affixes':consumer_files=['drone_rewards.gd','drone_forge.gd','drone_inventory.gd','drone_effect_aggregator.gd'];unit='武器ID' if parts[-1]=='weapon' else 'bool' if parts[-1]=='amplified' else '原始加成；数量词缀最终投影有int截断'
 elif root=='hanging_modules':
  consumer_files=['drone_rewards.gd','drone_effect_aggregator.gd','hyperspace_system.gd'];unit={'base_exp':'经验/副本','exp_growth':'每级经验需求增长率','effect_growth':'每级效果增长率','unlock_stage':'最高到达关卡'}.get(parts[-1],'效果标签')
  if 'effects' in parts:status='not_consumed';kind='descriptive_rule';editable=False;note+='；effects是声明，真实接入按固定模块ID分支，不读取这组字符串'
 elif root=='legendary_effects':
  consumer_files=['drone_rewards.gd','drone_forge.gd','drone_inventory.gd','drone_effect_aggregator.gd'];effect=parts[1];needle='legendary_effects';unit='既有武器ID' if parts[-1]=='weapon' else '倍率/比例/计数，见实体列定义'
  if 'constants' in parts:consumer_files=['drone_combat_effects.gd','game.gd','hyperspace_system.gd'];needle=next((p for p in reversed(parts) if not p.isdigit()),effect)
  if parts[-1] in ['counting_policy','maximum_towers']:status='not_consumed';kind='descriptive_rule';editable=False;note+='；当前行为是固定实现，不通过此字段改变'
  if 'stored_parameter_ranges' in parts:consumer_files=['drone_inventory.gd'];needle='stored_parameter_ranges';kind='stored_value_compatibility';editable=False;note+='；仅校验已有存值，不用于新抽取，旧档迁移不在本轮'
 elif root=='policies':
  consumer_files=['drone_rewards.gd','drone_forge.gd','hyperspace_system.gd'];needle=parts[-1];unit='枚举/null';kind='supported_policy'
  if parts[-1] in dead_policy:status='not_consumed';kind='descriptive_rule';editable=False
  elif parts[-1] not in ['core_reward','legendary_repeat_action']:editable=False
 else:consumer_files=['drone_rewards.gd']
 references=[r for f in consumer_files for r in refs(f,needle)]
 if status=='not_consumed':references=[]
 if root=='version':references=[];status='schema_only'
 col=parts[-1] if len(parts)>1 else 'value'
 if len(parts)>3 and root in ['affixes','legendary_effects'] and parts[-1] in ['0','1']:col='minimum' if parts[-1]=='0' else 'maximum'
 constraint='保留当前JSON类型；数值有限；运行时C.number边界abs(value)<9e15；相关跨字段约束必须导入和启动均检查'
 if root in ['energy_rate','energy_cap','ticket','minimum_duration','value_precision','modernization_cost_base','modernization_level_step','late_supply_ramp_seconds']:constraint+='；>0'
 if root in ['affix_initial_probability','hanging_initial_probability','additional_probability_factor']:constraint+='；0≤value≤1'
 if root in ['tier_weights','modernization_tier_weights']:constraint+='；tier键1..5完整；相对权重/系数；保持原字典顺序'
 if root=='quality_weights':constraint+='；非负且合计>0；固定支持结果ID；按原插入顺序输出'
 if root=='affixes':constraint+='；仅已有实现ID/武器；阶1..5；min≤max，量化网格非空'
 if root=='forge_costs':constraint+='；已支持操作与已存在材料/core键；非负整数'
 if root in ['material_reward_start_level','modernization_level_step']:constraint+='；奖励起点与改造价格既有联动不拆分'
 if kind in ['descriptive_rule','technical_or_schema']:constraint+='；锁定，不提供任意玩法开关'
 return table,col,kind,editable,status,unit,note,constraint,references
records=[];trees=[];file_counts={}
for file,d in data.items():
 count=0
 for parts,v in walk(d):
  ptr=''.join('/'+esc(p) for p in parts);typ=node_type(v)
  if file=='hyperspace_config.json':trees.append({'path':ptr,'type':typ,'xlsx_row':xrows[ptr]['row'],'declared_type':xrows[ptr]['type'],'value':len(v) if isinstance(v,list) else None if isinstance(v,dict) else v})
  if isinstance(v,(dict,list)):continue
  count+=1
  table='';col=parts[-1] if parts else '';kind='binding_or_metadata';editable=False;status='consumed_through_parent';unit='ID/按字段';note='';constraint='保留类型、顺序与既有固定规则；引用必须存在';consumer=[]
  if file=='hyperspace_config.json':table,col,kind,editable,status,unit,note,constraint,consumer=config_info(parts)
  elif file=='space_enemy_candidates.json':
   if parts[0]=='enemies':
    table='异空间敌人';kind='combat_balance';editable=True;consumer=refs('hyperspace_route_loader.gd','row.')+refs('hyperspace_encounter_database.gd','registry.enemies');note='独立异空间敌人；不并入主线mon表'
    if len(parts)>2 and parts[2] in ['drops','rewardDrops','jewelDropRolls','res']:
     table='派生奖励投影（不编辑）';kind='derived_reward';editable=False;consumer=refs('hyperspace_reward_binding.gd','enemy.');note='实际入战前由主线预算和奖励分配覆盖；不能第二次手写材料/铁铀预算'
    elif 'equipment' in parts:table='异空间敌人武器安装';unit='已有enemy_weapon_base/weapon键引用';constraint+='；安装顺序保留；每个武器必须被现有数据库识别'
    elif parts[-1] in ['health','shield','dmgMultiple','shieldRecovery','shieldDelay']:unit={'health':'基础生命','shield':'基础护盾','dmgMultiple':'攻击倍率','shieldRecovery':'最大护盾比例/秒','shieldDelay':'游戏秒'}.get(parts[-1],'数值');constraint+='；health>0；shield/damage/recovery/delay≥0；shield/armourType∈{0,1,2}'
    elif parts[-1]=='id':editable=False;kind='stable_reference';constraint+='；正整数独立ID，不与主线冲突'
   elif parts[0]=='groups':
    table='异空间编队与槽位';kind='formation_binding';editable=True;consumer=refs('hyperspace_route_loader.gd','candidate.groups')+refs('hyperspace_manual_session.gd','formation_positions');note='40组、15槽，slots和formation_positions同索引'
    if 'rewardBinding' in parts:
     table='奖励参考关联';editable=parts[-1]=='rewardReferenceDesignId';kind='reward_reference' if editable else 'readonly_binding_state';consumer=refs('hyperspace_reward_binding.gd','ref_key');note='设计参考ID可关联；UNBOUND/BOUND状态由运行绑定管理'
    elif 'formation_positions' in parts:col='x' if parts[-1]=='0' and typ!='null' else 'y' if parts[-1]=='1' and typ!='null' else 'empty';unit='逻辑战场坐标';constraint+='；与slot空值一致，x54..518/y80..350；大型舰中心扇区/前后排序；需要现有显式阵型校验'
    elif 'slots' in parts:col='enemy_id';unit='已有异空间敌人ID或null';constraint+='；15源槽保留；非空槽引用必须存在'
   else:table='审核与来源元数据（锁定）';kind='acceptance_or_provenance';status='metadata_or_contract';note='版本、审核数量及来源记录不是自由调参开关';consumer=refs('hyperspace_route_loader.gd','candidate.get')
  elif file=='space_enemy_routes.json':
   table='异空间战斗路线';consumer=refs('hyperspace_route_loader.gd','binding.routes');note='按武器、战斗档位、顺序关联已有编队；各路线4普通4精英1boss1ultimate'
   if parts[0]=='routes':editable=True;kind='route_binding';col='group_id';unit='已有异空间group ID';constraint+='；路线/层级一致；不重用主线波次；顺序保留'
   else:kind='fixed_contract';table='固定规则与审核元数据（锁定）';status='contract_or_metadata';constraint+='；倍率继承和enemy_tier_offset=0保留'
  elif file=='space_enemy_reward_recipes.json':
   table='奖励成员分配';consumer=refs('hyperspace_reward_binding.gd','member.');note='每个参考成员ordinal恰好分配一次；总普通掉落/碎片预算不变'
   if 'reference_member_ordinals_for_resource_blocks' in parts:kind='reward_allocation';editable=True;col='reference_member_ordinal';unit='0起参考成员索引';constraint+='；完整覆盖0..reference_count-1，无重复；改变分配不可改总量'
   elif parts[-1] in ['enemy_id','jewelDropRolls']:kind='derived_reference';col=parts[-1];note+='；enemy_id从group.slot派生；jewelDropRolls=所分配ordinal数'
   elif parts[-1]=='slot':kind='reward_allocation';editable=True;unit='0起槽位索引';constraint+='；非空槽且每槽唯一'
   else:kind='schema_only';table='协议常量（锁定）';status='schema_only'
  elif file=='space_enemy_reward_catalog.json':
   table='奖励参考关联';consumer=refs('hyperspace_reward_binding.gd','reference.');note='引用正式主线monGroup/mon/level；不得复制其奖励金额为第二权威'
   if parts[0]=='references':
    if any(p in parts for p in ['early_drop_blocks','late_drop_blocks']):kind='derived_reward';table='主线奖励派生投影（不编辑）';unit='主线原始掉落值引用';note+='；晚段40/40与所引用正式主线实际组完全相等，早段需保留当前fallback依据'
    elif parts[-1] in ['source_design_group_id','late_reference_actual_level_id','late_reference_actual_group_id']:kind='reward_reference';editable=True;unit='正式主线既有ID引用';constraint+='；保持当前关联，跨表验证组确属关卡'
    elif parts[-1]=='reference_member_count':kind='derived_count';note+='；可从正式source_design_group_id组的非空slots派生，当前40/40相等'
    elif any(p in parts for p in ['late_stage_minimum','early_stage_range','early_existing_encounters','early_rule_only_no_existing_encounter']):kind='derived_or_fixed_rule';status='not_independently_consumed';note+='；runtime早晚分界仍固定≤5/≥6，不能编辑这些说明假装生效'
   else:table='历史来源元数据（锁定）';kind='provenance';status='metadata';consumer=[]
  else:
   table='主线波次派生引用（不新建策划调参数表）';kind='derived_reference';consumer=refs('hyperspace_reward_binding.gd','wave.');note='1960现有波次，仅引用stage/group/source_design；预算从正式主线读取，不复制数字';constraint+='；当前1960/1960与正式关卡组存在关联；source_group原设计身份需主线生成器明确提供，不能凭名称推断'
   if parts[-1]=='node':status='not_consumed_metadata';consumer=[]
   elif parts[0]!='waves':kind='schema_only' if parts[-1]=='schema_version' else 'provenance';status='metadata';consumer=[]
  record={'source_commit':pin,'source_file':'space-battleship/data/'+file,'path':ptr,'type':typ,'current_value':v,'current_authority':'config_excel/hyperspace_config.xlsx' if file=='hyperspace_config.json' else 'accepted separate JSON; no official XLSX projection found','current_xlsx':{'sheet':'hyperspace_config','row':xrows[ptr]['row'],'value_column':'C','type_column':'B'} if file=='hyperspace_config.json' else None,'suggested_entity':table,'suggested_column':col,'row_identity':list(parts[:-1]),'classification':kind,'editable_in_proposal':editable,'runtime_read_status':status,'unit':unit,'description_zh':note,'constraints':constraint,'consumer_locators':consumer,'consumer_locator_scope':'Text locators at verified parent traversal/member; not an automatic proof that a newly added key affects gameplay'}
  records.append(record)
 file_counts[file]=count
assert len(records)==16392 and len(config)==52 and book_rows==521
with gzip.open(out/'ALL_CURRENT_FIELDS.json.gz','wt',encoding='utf-8') as f:json.dump(records,f,ensure_ascii=False,indent=1)
(out/'CONFIG_TREE_NODES.json').write_text(json.dumps(trees,ensure_ascii=False,indent=2)+'\n')
head=['source_file','path','type','current_value','current_xlsx','suggested_entity','suggested_column','classification','editable_in_proposal','runtime_read_status','unit','description_zh','constraints','consumer_locators']
def tsv_record(r):return {k:(json.dumps(r[k],ensure_ascii=False,separators=(',',':')) if isinstance(r[k],(dict,list,bool)) or r[k] is None else r[k]) for k in head}
with (out/'CONFIG_FIELDS.tsv').open('w',encoding='utf-8',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=head,delimiter='\t');writer.writeheader();writer.writerows(tsv_record(r) for r in records if r['source_file'].endswith('/hyperspace_config.json'))
with gzip.open(out/'ALL_CURRENT_FIELDS.tsv.gz','wt',encoding='utf-8',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=head,delimiter='\t');writer.writeheader();writer.writerows(tsv_record(r) for r in records)
keys_order={file:{''.join('/'+esc(p) for p in parts):list(v.keys()) for parts,v in walk(d) if isinstance(v,dict)} for file,d in data.items()};(out/'CURRENT_DICTIONARY_ORDER.json').write_text(json.dumps(keys_order,ensure_ascii=False,indent=1)+'\n')
source_files=[project/'data'/name for name in files]+[project/'config_excel/hyperspace_config.xlsx',project/'tools/hyperspace_workbook.py',project/'tools/config_workbooks.py',project/'tools/import_workbook.py']
manifest={'source_commit':pin,'file_hashes':{str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files},'scalar_leaf_counts':file_counts,'total_scalar_leaves':len(records),'config_root_fields':52,'workbook_rows_including_header':521,'config_container_and_scalar_nodes':len(trees),'workbook_json_semantic_equal':True,'crosscheck_evidence':'101bd0f2c772147796f612abad395489e37bb97f','numeric_changes':False,'xlsx_written':False,'code_changed':False,'source_repo_clean':subprocess.check_output(['git','-C',str(repo),'status','--porcelain']).decode()==''};(out/'SOURCE_AUDIT.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:manifest[k] for k in ['scalar_leaf_counts','total_scalar_leaves','config_root_fields','workbook_rows_including_header','source_repo_clean']},ensure_ascii=False))
