# 09 配置事实附录

[回唯一入口](README.md)。本附录从基线工作簿直接读取，数据行第4行起，首列空行不计业务记录。数值是审阅快照，运行权威仍为Excel；大规模敌舰/编组/关卡不逐行抄写。公式、归属、结算规则在01～06，已定规则索引在08。第0节是新设计目标值，其余表格和指纹保留main历史快照，不表示工作簿已修改。

## 0. 已定规则到目标Excel的映射

**本次仅修改文档，xlsx及生成JSON均未修改。** 下列是实施时应写入Excel的目标定义。后续main快照的repeat_b2_repeats=1、minimum_level=5、ticket=108000是原始证据，不再是新游戏对应规则。base_critical_rate=0.25则保留：它仅在critical主效果生效时提供，不是武器天生概率；原表“所有我方武器基础暴击率”的文案不能覆盖实际生效条件。编译新配置前应应用本节目标，不能只照搬旧表值。已有字段原值可留在迁移记录，不能作为运行回退。

| 已定规则 | 目标工作簿/字段 | 目标值与说明 |
|---|---|---|
| 装备进化保留 | 新equipment_evolution.xlsx：interval、first_stat_multiplier、later_stat_multiplier | 20、1.6、1.5；按付费等级升阶，虚拟等级不授阶 |
| 进化材料 | 同表material_id、material_cost_per_tier | degenerate_matter、10；每跨20级付10×目标阶数，未开放材料时停在门槛前 |
| 进化表现 | 同表visual_palette、visual_strength_start、visual_strength_per_tier | 原10色依次53d9ff/78b7ff/a9a6ff/d9a0ff/ff9eca/ffad91/ffd278/d8ed78/94e8b4/f7e6b0；0.4、0.06；视觉色阶上限不限制数值阶数 |
| 禁止第二代连发 | enhance_config.xlsx：repeat_b2_repeats及des | 0；说明“额外攻击不再触发连发”；保留B2节点/已有选择但功能不启用，不补另一个效果 |
| 武器天生率与强化主效果 | enhance_config.xlsx：base_critical_rate及des | 0.25保留；说明“critical主效果生效时，为所有合法武器提供25%暴击率，与单件装备等级无关；武器本身没有天生基础暴击率”；A/B2/无人机原加成保留 |
| 保底暴击与原率爆伤 | enhance_config.xlsx：critical_b3_guaranteed_rate及说明；ui_content.xlsx的保底暴击说明 | 1保留。说明“暴击效果触发率固定为100%；额外暴击伤害仍按原暴击率出现。强制补足部分不附赠爆伤，原有爆伤机会保留”；按02保留main两次判定，第二次R不含无人机C。base_critical_multiplier2/critical_growth0.3保留，不新增固定无爆伤倍率字段 |
| 超空间起层 | hyperspace_config.xlsx：minimum_level | 1；路线已过0层时首挑战1层，此后current+1 |
| 所有模式无门票 | hyperspace_config.xlsx：ticket | 0；手动/单次/自动均免费，不保留108000作隐含回退，无票额退款 |
| 探索时长下限 | hyperspace_config.xlsx：minimum_duration及说明 | 10游戏秒；单次max(10,best)，自动max(10,best×20/(20+crewLevel))，不限制手动实际战斗时长 |
| 星系平均每秒收入 | 新economy_rules.xlsx：income_window_seconds；galaxy_config.xlsx新增income_basis | 60；native_average_per_second。窗口原生生产总额/60再乘比例，income_interval仍10秒；不是把建筑比例再乘或除60 |
| 完成余时与顺序 | 新battle_rules.xlsx：task_completion_tail_policy、same_time_order | discard_task_tail_within_fixed_step；shared_then_defence_then_birth_then_contact。实际阶段和稳定来源顺序按01，不丢整步、并行任务或战斗周期 |
| 目标排序保留 | 新battle_geometry.xlsx：target_slot_center、target_order | 4.5；nonresistant_y_desc_slot_distance_slot。15槽仍按槽位锚排序 |
| 新战场恢复/导入补偿 | 新game_rules.xlsx：load_battle_mode、import_offline_particles | fresh_encounter、true；保存长期历史/任务/奖励/时间余量，恢复新场；offlineMax仍12小时，微粒速率/容量按01 |
| 普通/极端价格 | 装备/反应炉/强化现有cost与growth、Q单价规则不改 | 普通合计逐级单价，06按同价段求和；10^15是Amount精度界限，属于算法常量，不新增可调收费系数或隐藏账本 |

暴击玩家文案统一迁入06定义的`ui_content.xlsx`：现行`data/ui_text.json`中的`enhance.description.critical`、`enhance.description.critical.runtime`、`enhance.description.critical.runtime_regular`说明共享强化主效果的25%生效条件及正常暴伤；`enhance.branch.critical.3.B.description`、`enhance.overview.critical_guaranteed`说明保底只补足暴击效果触发率，原率R的额外爆伤机会仍保留；`enhance.overview.critical`按当前状态显示普通概率P，保底状态同时展示P与原率爆伤概率R。参数占位符取02同一计算结果，不能将无人机C计入保底爆伤概率。文案明确共享有效强化等级与顺位决定主效果/分支解锁，不把单件装备等级当作门槛；既有JSON文案只作迁移来源，不另作运行权威。

装备进化迁移仅覆盖当前data/equipment_evolution.json这些现存字段，不从历史恢复其他已删除成长配置。旧hightech等停用内容继续保留但不重新开放。所有目标字段由独立Excel编译器读入，不允许在游戏里硬编码一套与工作簿不同的目标值。

## 1. 覆盖总表

项目`config_excel`根目录共 **26个工作簿、46个工作表**。此外仓库根有1个旧总表、`published`有3个发布副本；合计已核查30个xlsx文件。

| 工作簿 | 工作表 | 有效记录数 | 类别 |
|---|---|---|---|
| ai_tech_tree.xlsx | ai_tech_tree | 8 | 正式内容 |
| battle_design.xlsx | battle_design | 40 | 候选设计元数据；不自动进入主线 |
| config.xlsx | config | 38 | 正式内容 |
| crew.xlsx | crew | 20 | 正式内容 |
| crew_assignment.xlsx | crew_assignment | 5 | 正式内容 |
| crew_config.xlsx | crew_config | 12 | 正式内容 |
| enemy_weapon_base.xlsx | enemy_weapon_base | 4 | 正式内容 |
| enhance_config.xlsx | enhance_config | 68 | 正式内容 |
| equipment.xlsx | equipment | 11 | 正式内容 |
| galaxy.xlsx | galaxy | 1 | 正式内容 |
| galaxy_build.xlsx | galaxy_build | 6 | 正式内容 |
| galaxy_config.xlsx | galaxy_config | 13 | 正式内容 |
| hightech.xlsx | hightech | 4 | 保留旧科研内容；不恢复旧功能 |
| hyperspace_config.xlsx | 基础参数 | 40 | 正式内容 |
| hyperspace_config.xlsx | 路线 | 4 | 正式内容 |
| hyperspace_config.xlsx | 品质 | 5 | 正式内容 |
| hyperspace_config.xlsx | 舰型容量 | 5 | 正式内容 |
| hyperspace_config.xlsx | 阶级权重 | 5 | 正式内容 |
| hyperspace_config.xlsx | 词缀定义 | 13 | 正式内容 |
| hyperspace_config.xlsx | 词缀区间 | 62 | 正式内容 |
| hyperspace_config.xlsx | 挂设成长 | 5 | 正式内容 |
| hyperspace_config.xlsx | 传说定义 | 12 | 正式内容 |
| hyperspace_config.xlsx | 传说随机参数 | 13 | 正式内容 |
| hyperspace_config.xlsx | 传说常量 | 22 | 正式内容 |
| hyperspace_config.xlsx | 改造费用 | 10 | 正式内容 |
| hyperspace_config.xlsx | 固定规则_兼容说明 | 16 | 正式内容 |
| hyperspace_config.xlsx | 无人机外观 | 16 | 正式内容 |
| hyperspace_enemies.xlsx | 敌人 | 180 | 正式内容 |
| hyperspace_enemies.xlsx | 武器安装 | 180 | 正式内容 |
| hyperspace_enemies.xlsx | 编队 | 40 | 正式内容 |
| hyperspace_enemies.xlsx | 编队槽位 | 180 | 正式内容 |
| hyperspace_enemies.xlsx | 路线编排 | 40 | 正式内容 |
| hyperspace_enemies.xlsx | 奖励参考 | 40 | 正式内容 |
| hyperspace_enemies.xlsx | 成员分配 | 242 | 正式内容 |
| hyperspace_enemies.xlsx | 早段回退预算 | 95 | 正式内容 |
| level.xlsx | level | 220 | 正式内容 |
| level_monGroup_generated.xlsx | level | 200 | 生成副本；不覆盖正式level |
| mon.xlsx | mon | 10461 | 正式内容 |
| monGroup.xlsx | monGroup | 2330 | 正式内容 |
| planet.xlsx | planet | 6 | 正式内容 |
| planet_buff.xlsx | planet_buff | 35 | 正式内容 |
| planet_build.xlsx | planet_build | 5 | 正式内容 |
| res.xlsx | res | 2 | 正式内容 |
| ship.xlsx | ship | 5 | 正式内容 |
| unlock.xlsx | unlock | 46 | 正式内容 |
| weapon_motion.xlsx | weapon_motion | 29 | 正式内容 |


`published/{level,mon,monGroup}.xlsx`为发布副本，分别与根同名表核对来源，不能作为第二权威；它们不计入上述根输入数量。

## 2. 全字段结构


### ai_tech_tree.xlsx


**ai_tech_tree**：8条。字段按原列顺序：

`id`, `name`, `description`, `tier`, `base_seconds`, `growth`, `effect`, `factor`, `unlock`, `requirements`, `legacy_unlock`。


### battle_design.xlsx


**battle_design**：40条。字段按原列顺序：

`id`, `group_id`, `tier`, `counter`, `base_level`, `min_upgrade`, `target_seconds`, `status`, `description`, `pair_id`, `attack_variant`, `attack_type`, `paired_group_id`。


### config.xlsx


**config**：38条。字段按原列顺序：

`name`, `des`, `para_1`。


### crew.xlsx


**crew**：20条。字段按原列顺序：

`id`, `name`, `description`, `icon`, `basePower`, `defaultAssignment`, `unlockId`, `equipmentSlotCount`, `defaultTargetId`。


### crew_assignment.xlsx


**crew_assignment**：5条。字段按原列顺序：

`id`, `targetType`, `effectType`, `baseValue`, `levelScale`, `powerScale`, `interval`, `maxCrew`, `description`, `titleTextId`, `descTextId`, `targetCategory`, `upgradeModes`。


### crew_config.xlsx


**crew_config**：12条。字段按原列顺序：

`id`, `value`, `des`, `targetType`。


### enemy_weapon_base.xlsx


**enemy_weapon_base**：4条。字段按原列顺序：

`id`, `dmg`, `cd`, `dmgtype`, `para1`, `para2`, `para3`。


### enhance_config.xlsx


**enhance_config**：68条。字段按原列顺序：

`id`, `value`, `unit`, `des`。


### equipment.xlsx


**equipment**：11条。字段按原列顺序：

`name`, `des`, `level`, `dmgtype`, `dmg`, `dmgMulti`, `cd`, （空保留列）, `res_1`, `cost_1`, `costMulti_1`, `res_2`, `cost_2`, `costMulti_2`, `para1`, `para2`, `para3`, `para4`。


### galaxy.xlsx


**galaxy**：1条。字段按原列顺序：

`id`, `key`, `name`, `order`, `unlock_type`, `unlock_value`, `next_galaxy`, `map_w`, `map_h`, `start_w`, `start_h`, `building_slot_count`, `slot_seed`, `explore_work_total`, `explore_power_base`, `explore_power_per_crew`, `ship_per_crew`, `build_interval`, `construction_time`, `upgrade_power_base`, `upgrade_power_per_crew`, `upgrade_cost_lv2`, `upgrade_cost_lv3`, `upgrade_cost_lv4`, `upgrade_cost_lv5`, `concurrent_upgrade_count`, `special_cycle`, `core_asset`, `des`。


### galaxy_build.xlsx


**galaxy_build**：6条。字段按原列顺序：

`id`, `key`, `galaxy_key`, `name`, `group`, `max_lv`, `effect_type`, `base_effect`, `asset_lv1`, `asset_lv2`, `asset_lv3`, `asset_lv4`, `asset_lv5`, `visual_category`, `des`。


### galaxy_config.xlsx


**galaxy_config**：13条。字段按原列顺序：

`key`, `value`, `type`, `des`。


### hightech.xlsx


**hightech**：4条。字段按原列顺序：

`name`, `des`, `description`, `tpCostBase`, `tpCostMutiple`, `tpCostMutiple2`, `para1`, `para2`。


### hyperspace_config.xlsx


**基础参数**：40条。字段按原列顺序：

`key`, `data_type`, `value`, `unit`, `description`, `constraint`, `editable`。


**路线**：4条。字段按原列顺序：

`order`, `route_id`, `weapon`, `material`。


**品质**：5条。字段按原列顺序：

`order`, `quality`, `weight`, `affix_limit`, `hanging_limit`, `weapon_level_bonus`, `dismantle_amount`。


**舰型容量**：5条。字段按原列顺序：

`order`, `hull_id`, `capacity`。


**阶级权重**：5条。字段按原列顺序：

`order`, `tier`, `draw_weight`, `modernization_weight`。


**词缀定义**：13条。字段按原列顺序：

`order`, `affix_id`, `weapon`, `amplified`。


**词缀区间**：62条。字段按原列顺序：

`affix_id`, `tier`, `minimum`, `maximum`。


**挂设成长**：5条。字段按原列顺序：

`order`, `module_id`, `base_exp`, `exp_growth`, `effect_growth`, `unlock_stage`, `effects_note`。


**传说定义**：12条。字段按原列顺序：

`order`, `effect_id`, `weapon`, `score_parameter_note`。


**传说随机参数**：13条。字段按原列顺序：

`effect_id`, `order`, `parameter`, `minimum`, `maximum`, `unit`, `description`。


**传说常量**：22条。字段按原列顺序：

`effect_id`, `constant_path`, `data_type`, `value`, `unit`, `description`, `constraint`, `editable`。


**改造费用**：10条。字段按原列顺序：

`operation_order`, `operation`, `resource`, `resource_order`, `amount`。


**固定规则_兼容说明**：16条。字段按原列顺序：

`key`, `data_type`, `value`, `unit`, `description`, `constraint`, `editable`。


**无人机外观**：16条。字段按原列顺序：

`key`, `data_type`, `value`, `unit`, `description`, `constraint`, `editable`。


### hyperspace_enemies.xlsx


**敌人**：180条。字段按原列顺序：

`order`, `enemy_id`, `description`, `size`, `health`, `armour_type`, `shield`, `shield_type`, `shield_recovery`, `shield_delay`, `damage_multiplier`。


**武器安装**：180条。字段按原列顺序：

`enemy_id`, `order`, `weapon_id`。


**编队**：40条。字段按原列顺序：

`order`, `group_id`, `description`, `tier`, `reward_reference_id`。


**编队槽位**：180条。字段按原列顺序：

`group_id`, `slot_index`, `enemy_id`, `x`, `y`。


**路线编排**：40条。字段按原列顺序：

`route_id`, `tier`, `order`, `group_id`。


**奖励参考**：40条。字段按原列顺序：

`reference_id`, `source_design_group_id`, `reference_member_count`, `late_reference_level_id`, `late_reference_group_id`, `boundary_note`。


**成员分配**：242条。字段按原列顺序：

`group_id`, `member_order`, `slot_index`, `order`, `reference_member_ordinal`。


**早段回退预算**：95条。字段按原列顺序：

`reference_id`, `reference_member_ordinal`, `drop_order`, `resource_id`, `amount`, `chance`。


### level.xlsx


**level**：220条。字段按原列顺序：

`id`, `length`, `monGroup`, `atkRatio`, `lifeRatio`, `resRatio`, `jewelRatio`, `planetExpRatio`, `entryAtkRatio`, `entryLifeRatio`, `rewardReferenceGroups`。


### level_monGroup_generated.xlsx


**level**：200条。字段按原列顺序：

`id`, `length`, `monGroup`, `atkRatio`, `lifeRatio`, `resRatio`, `jewelRatio`, `planetExpRatio`。


### mon.xlsx


**mon**：10461条。字段按原列顺序：

`id`, `des`, `equipment`, `dmgMultiple`, `health`, `armourType`, `res`, `size`, `shield`, `shieldType`, `shieldRecovery`, `shieldDelay`, `reactiveReduction`, `archetype_id`, `intelTrait`, `intelName`, `intelVisualRef`, `intelMechanics`。


### monGroup.xlsx


**monGroup**：2330条。字段按原列顺序：

`id`, `des`, `mon`, `combatTier`。


### planet.xlsx


**planet**：6条。字段按原列顺序：

`id`, `name`, `unlockId`, `baseTime`, `baseExp`, `tags`, `visual`, `reforgeStartLevel`, `minTime`。


### planet_buff.xlsx


**planet_buff**：35条。字段按原列顺序：

`id`, `planet_id`, `source`, `source_id`, `condition`, `buff_type`, `target`, `value`, `stack`, `order`, `des`。


### planet_build.xlsx


**planet_build**：5条。字段按原列顺序：

`id`, `name`, `des`, `min_planet`, `planet_rule`, `planet_value`, `order`, `unlock_explore`, `build_explore`, `extra_crew`, `type`, `config1`, `config2`, `previous_id`。


### res.xlsx


**res**：2条。字段按原列顺序：

`id`, `name`。


### ship.xlsx


**ship**：5条。字段按原列顺序：

`name`, `des`, `para_1`, `para_2`, `para_3`, （空保留列）, `para_5`, `para_6`。


### unlock.xlsx


**unlock**：46条。字段按原列顺序：

`name`, `type`, `target`, `level`, `mode`, `title`, `desc`。


### weapon_motion.xlsx


**weapon_motion**：29条。字段按原列顺序：

`id`, `value`, `unit`, `description`, `scope`。


## 3. 小型规则与数值表

以下逐项列出活跃或需保留的小型规则。未消费字段也保留，消费状态以主文和08为准；不因本附录出现就启用功能。资产JSON等纯表现长字段仅在字段结构保留，其内容继续由对应Excel承载。


### ai_tech_tree 数值


**ai_tech_tree**

| id | name | description | tier | base_seconds | growth | effect | factor | unlock | requirements | legacy_unlock |
|---|---|---|---|---|---|---|---|---|---|---|
| singularity | AI奇点 | 每级增加 1 个 AI，提高所有研究速度。 | independent | 60 | 1.8 | ai_count | 1 | — | — | 超时空炼铁炉 |
| weapon_accuracy | 武器精度 | 每级使所有武器伤害乘以 1.1。 | basic | 60 | 1.4 | weapon_damage | 1.1 | — | — | 正电子聚焦装置 |
| equipment_reinforcement | 装备强化 | 每级使装备耐久乘以 1.1。 | basic | 40 | 1.4 | equipment_durability | 1.1 | — | — | 简并态装甲 |
| resource_refining | 资源精炼 | 每级使铁获取量乘以 1.1。 | basic | 60 | 1.4 | iron_income | 1.1 | — | — | 超时空炼铁炉 |
| fragment_condensation | 强化碎片凝聚 | 每级使强化碎片获取量乘以 1.1。 | basic | 60 | 1.4 | fragment_income | 1.1 | enhancement | — | 宝石熔炼炉 |
| equipment_finishing | 装备精制 | 每级使武器伤害和装备耐久各乘以 1.25。 | core | 1800 | 30 | weapon_damage,equipment_durability | 1.25 | — | weapon_accuracy:10*k+1;equipment_reinforcement:10*k+1 | — |
| uranium_extraction | 铀提炼 | 每级使铀获取量乘以 1.1。 | core | 1800 | 30 | uranium_income | 1.1 | — | resource_refining:10*k+1 | — |
| unification | 联合一体化 | 装备伤害与耐久按等级和三种资源的历史最高平均每秒收入共同增长。 | ultimate | 1620000 | 900 | weapon_damage,equipment_durability | 1 | — | equipment_finishing:10;uranium_extraction:10 | — |


### config 数值


**config**

| name | des | para_1 |
|---|---|---|
| startEquip | 飞船初始具有的装备，格式为name,name，equipment表的名字。默认为1级。 | armour,laser |
| dmgReduce | 护甲类型对应时，减少的伤害 | 0.5 |
| movement | 飞船的移动速度，单位是秒 | 50 |
| autoCollectReduce | 自动拾取时的损耗 | 0.5 |
| backRange | 死亡时后退距离 | 200 |
| offlineMax | 离线时长(h） | 12 |
| autoGenRes | 画面上自动生成的资源,格式为生成间隔秒,种类,数量,移动速度. | 30,2,5,40 |
| scientistCost | 格式资源倍率,资源种类1\|资源消耗1,资源种类2\|资源消耗2....支持资源种类无限扩展 | 1.2,1\|100,2\|5 |
| hightechLimit | 高科技投入AI的科研点数衰减 | 1 |
| techPointGet | 高科技点数获取 | 1 |
| hightechCostGrowthLevel | 高科技耗时指数增长阈值，当前等级超过此值后生效 | 50 |
| jewelDrop | 宝石碎片掉率 | 0.2 |
| chronoParticlesPerSecond | 每离线秒获得的超时空微粒 | 1 |
| chronoDefaultSpeed | 进入游戏及微粒不足时恢复的倍率 | 1 |
| chronoSpeeds | 倍率\|每现实秒微粒消耗，逗号分隔 | 1\|0,2\|1,3\|2,4\|3,5\|4,6\|5,7\|6,8\|7,9\|8,10\|9 |
| reactorEnergyBase | 反应炉1级总能源 | 100 |
| reactorEnergyGrowth | 反应炉每级总能源倍率 | 1.5 |
| reactorUpgradeBase | 反应炉1级升级铀消耗 | 10 |
| reactorUpgradeGrowth | 反应炉每级升级费用倍率 | 1.35 |
| reactorBoostExponent | 模块能源提升指数；提升百分比为分配能源的该次幂 | 0.8 |
| reactorUraniumId | 反应炉升级消耗的资源ID | 2 |
| reactorModules | 反应炉可分配模块ID，逗号分隔 | weapons,defence,smelting,condensation |
| reactorInitialLevel | 新存档反应炉初始等级 | 1 |
| reactorPercentScale | 提升百分比换算分母 | 100 |
| reactorAllocationStep | 能源滑杆最小步长 | 1 |
| playerVisualScaleFrigate | 我方护卫舰显示倍率，仅影响舰体贴图 | 1.3 |
| playerVisualScaleDestroyer | 我方驱逐舰显示倍率，仅影响舰体贴图 | 1.1 |
| playerVisualScaleCruiser | 我方巡洋舰显示倍率，仅影响舰体贴图 | 1.2 |
| playerVisualScaleBattleship | 我方战列舰显示倍率，仅影响舰体贴图 | 1.3 |
| playerVisualScaleHeavy_Battleship | 我方重型战列舰显示倍率，仅影响舰体贴图 | 1.4 |
| enemyVisualScaleSize1 | 敌方 size 1 显示倍率，仅影响舰体贴图 | 1.2 |
| enemyVisualScaleSize2 | 敌方 size 2 显示倍率，仅影响舰体贴图 | 1.2 |
| enemyVisualScaleSize3 | 敌方 size 3 显示倍率，仅影响舰体贴图 | 1.4 |
| enemyVisualScaleSize4 | 敌方 size 4 显示倍率，仅影响舰体贴图 | 1.5 |
| enemyVisualScaleSize5 | 敌方 size 5 显示倍率，仅影响舰体贴图 | 1.5 |
| enemyVisualScaleSize6 | 敌方 size 6 显示倍率，仅影响舰体贴图 | 1.7 |
| explicitEnemyPlayerMinGap | 显式超空间阵型与玩家舰体包络的最小发射空白，按战场高度比例；不改变普通阵型、船体尺寸或战斗数值。 | 0.12 |
| equipmentSwitchCooldownSeconds | 同一武器或防御槽位换装后再次换装的游戏秒数 | 10 |


### crew 数值


**crew**

| id | name | basePower | defaultAssignment | unlockId | equipmentSlotCount | defaultTargetId |
|---|---|---|---|---|---|---|
| navigator | 高坚果 | 1 |  | crew/navigator | 2 |  |
| engineer | 无敌强 | 1 |  | crew/engineer | 2 |  |
| researcher | 朱姐 | 1 |  | crew/researcher | 2 |  |
| crew_04 | 若风 | 1 | — | crew/crew_04 | 2 | — |
| crew_05 | 静静 | 1 | — | crew/crew_05 | 2 | — |
| crew_06 | 无限大 | 1 | — | crew/crew_06 | 2 | — |
| crew_07 | 恐惧之言 | 1 | — | crew/crew_07 | 2 | — |
| crew_08 | 船员08 | 1 | — | crew/crew_08 | 2 | — |
| crew_09 | 船员09 | 1 | — | crew/crew_09 | 2 | — |
| crew_10 | 船员10 | 1 | — | crew/crew_10 | 2 | — |
| crew_11 | 船员11 | 1 | — | crew/crew_11 | 2 | — |
| crew_12 | 船员12 | 1 | — | crew/crew_12 | 2 | — |
| crew_13 | 船员13 | 1 | — | crew/crew_13 | 2 | — |
| crew_14 | 船员14 | 1 | — | crew/crew_14 | 2 | — |
| crew_15 | 船员15 | 1 | — | crew/crew_15 | 2 | — |
| crew_16 | 船员16 | 1 | — | crew/crew_16 | 2 | — |
| crew_17 | 船员17 | 1 | — | crew/crew_17 | 2 | — |
| crew_18 | 船员18 | 1 | — | crew/crew_18 | 2 | — |
| crew_19 | 船员19 | 1 | — | crew/crew_19 | 2 | — |
| crew_20 | 船员20 | 1 | — | crew/crew_20 | 2 | — |


### crew_assignment 数值


**crew_assignment**

| id | targetType | effectType | baseValue | levelScale | powerScale | interval | maxCrew | description | titleTextId | descTextId | targetCategory | upgradeModes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| equipment_upgrade | equipment | AUTO_UPGRADE | 1 | 0 | 0 | 1 | 1 | 每秒尝试升级全部启用的武器和防御模块，正常消耗资源。 | crew.job.equipment | crew.effect.all_equipment | — | 1,10,max |
| hightech_scientists | hightech | AUTO_RESEARCH | 1 | 0 | 0 | 0 | 1 | 研究完成后自动续研剩余时间最短的可用项目；等级提升科研速度。 | crew.job.hightech | crew.effect.research_auto | system | — |
| jewel_auto | jewel | AUTO_COMBINE | 1 | 0 | 0 | 1 | 1 | 每个配置周期尝试购买1级全局装备强化，正常消耗碎片。 | crew.job.jewel | crew.effect.jewel_auto | — | — |
| reactor_upgrade | reactor | AUTO_REACTOR | 1 | 0 | 0 | 1 | 1 | 每1秒尝试升级反应炉1级，并平均分配能源。 | crew.job.reactor | crew.effect.reactor_auto | — | — |
| galaxy_explore | galaxy | EXPLORE | 1 | 0 | 0 | 0 | 6 | 派遣船员探索星系并加速殖民地升级。 | galaxy.assignment | galaxy.assignment_desc | — | — |


### crew_config 数值


**crew_config**

| id | value | des | targetType |
|---|---|---|---|
| equip_bonus | 0.1 | 已装备装备属性 {effect} | equipment |
| tech_speed | 0.2 | 科研速度 {effect} | hightech |
| gem_bonus | 0.1 | 直接掉落强化碎片 {effect} | jewel |
| charge_bonus | 0.3 | 总能量 {effect} | reactor |
| base_exp | 100 | — | — |
| exp_multiplier | 1.2 | — | — |
| name_level | — | {name}  Lv{level} | — |
| exp_bar | — | 经验 {exp} / {needed} | — |
| badge_tip | — | {name}  Lv{level}<br>{effect} | — |
| planet_exp | — | 船员经验 +{exp} | — |
| hyperspace_duration_k | 20 | 船员等级越高，异空间挂机耗时越短。 | — |
| hyperspace_luck_per_level | 1 | 每级增加幸运；探索奖励的词缀品阶可额外重抽并保留最好结果。 | — |


### enemy_weapon_base 数值


**enemy_weapon_base**

| id | dmg | cd | dmgtype | para1 | para2 | para3 |
|---|---|---|---|---|---|---|
| laser | 100 | 0.5 | 1 | 30 | — | — |
| missile | 60 | 1 | 2 | 4 | 20 | — |
| cannon | 200 | 1 | 2 | 40 | — | — |
| longLaser | 35 | 0.2 | 1 | 2 | 3 | 1 |


### enhance_config 数值


**enhance_config**

| id | value | unit | des |
|---|---|---|---|
| cost_base | 100 | 碎片 | 首级费用；正整数碎片数 |
| cost_growth | 2 | 倍率 | 整数≥1；费用＝首级费用×倍率^(购买等级−1) |
| threshold_1 | 1 | 强化级 | 第1顺位效果的有效共享强化等级门槛；装备等级无关 |
| threshold_2 | 10 | 强化级 | 第2顺位效果的有效共享强化等级门槛；装备等级无关 |
| threshold_3 | 20 | 强化级 | 第3顺位效果的有效共享强化等级门槛；装备等级无关 |
| base_critical_rate | 0.25 | 概率 | 所有我方武器基础暴击率；0.25＝25% |
| base_critical_multiplier | 2 | 倍率 | 基础暴击伤害倍率 |
| critical_growth | 0.3 | 倍率/级 | 暴击效果每有效强化级增加的暴伤倍率 |
| proficiency_growth | 0.1 | 比例/级 | 武器熟练加成＝系数×有效等级×log(全局攻击数) |
| adaptation_growth | 0.1 | 比例/级 | 适应加成＝系数×有效等级×log(全局受击数) |
| counter_log_base | 10 | 底数 | 熟练与适应的历史计数对数底数 |
| bonus_round_scale | 100 | 精度 | 属性加成四舍五入；100＝保留两位小数 |
| repeat_probability | 0.5 | 概率 | 普通攻击触发一次额外攻击概率；额外攻击不递归 |
| repeat_growth | 0.2 | 比例/级 | 额外攻击伤害倍率＝1＋系数×有效等级 |
| repeat_delay | 0.5 | 秒 | 额外攻击的游戏时间延迟 |
| memory_interval | 0.2 | 秒 | 记忆材料按游戏时间回复的间隔 |
| memory_heal_fraction | 0.01 | 比例/级/次 | 每次回复自身最大防御×系数×有效等级 |
| memory_buffer_fraction | 0.1 | 比例/级 | 保护上限＝自身最大防御×系数×有效等级；无衰减 |
| deferred_duration | 2 | 秒 | 每次延迟伤害分期结算的游戏时间 |
| deferred_interval | 0.2 | 秒 | 全局延迟伤害扣除与清除判定间隔 |
| deferred_curve_coefficient | 1 | 系数 | 延迟比例＝1−1/(1＋系数×有效等级) |
| deferred_percent_scale | 100 | 精度 | 延迟比例向下取整；100＝整数百分比 |
| deferred_clear_probability | 0.25 | 概率/跳 | 每跳扣除当期后，一次判定清除全部剩余伤害 |
| branch_threshold_1 | 10 | 有效强化级 | 分支节点基础门槛；加上独立的效果位置偏移，不加主效果启用门槛 |
| branch_threshold_2 | 20 | 有效强化级 | 分支节点基础门槛；加上独立的效果位置偏移，不加主效果启用门槛 |
| branch_threshold_3 | 30 | 有效强化级 | 分支节点基础门槛；加上独立的效果位置偏移，不加主效果启用门槛 |
| proficiency_a_damage_bonus | 0.5 | 比例/节点 | 熟练A节点伤害加成；多个节点相加 |
| proficiency_b1_interval | 1 | 秒 | 同一主目标蓄力的完整游戏时间间隔 |
| proficiency_b1_growth | 0.2 | 比例/跳 | 同目标每跳独立乘以1＋此比例 |
| proficiency_b2_interval_multiplier | 0.7 | 倍率 | 快速发射的攻击间隔倍率 |
| proficiency_b3_resistance | 0.3 | 减伤比例 | 穿透后匹配敌人抗性的减伤比例 |
| repeat_a_probability | 0.1 | 百分点比例/节点 | 连发A节点增加的概率；0.1＝10个百分点 |
| repeat_b1_targets | 1 | 目标 | 单次连锁的额外目标数量 |
| repeat_b2_repeats | 1 | 次数 | 普通连发后允许额外再触发的连发次数 |
| repeat_b3_probability | 0.2 | 概率/攻击 | 正常攻击额外锁定另一目标的概率 |
| critical_a_probability | 0.15 | 百分点比例/节点 | 暴击A节点增加的概率 |
| critical_b1_attacks | 3 | 攻击事件 | 暴击余势影响的后续规范攻击次数 |
| critical_b1_damage_bonus | 0.5 | 比例 | 暴击余势伤害加成 |
| critical_b2_probability | 0.05 | 百分点比例/层 | 暴击连势每层增加暴击率 |
| critical_b2_damage_bonus | 0.1 | 比例/层 | 暴击连势每层增加伤害 |
| critical_b2_stacks | 3 | 层 | 暴击连势的最大层数 |
| critical_b2_duration | 2 | 秒 | 整组暴击连势持续时间；新暴击刷新 |
| critical_b3_guaranteed_rate | 1 | 概率 | 保底暴击的实际暴击概率；默认必定 |
| adaptation_a_capacity_bonus | 0.5 | 比例/节点 | 适应A节点防御最大值加成；多个节点相加 |
| adaptation_b1_reduction | 0.2 | 比例/层 | 同源攻击后续原始伤害每层减免 |
| adaptation_b1_stacks | 3 | 层 | 同源攻击减伤的最大层数 |
| adaptation_b2_interval | 2 | 秒 | 对应模块周期护罩生成间隔 |
| adaptation_b2_duration | 1 | 秒 | 无抗性周期护罩的持续时间 |
| adaptation_b2_capacity_multiplier | 1 | 倍率 | 周期护罩容量乘以真实防御最大值＋自身记忆上限 |
| adaptation_b3_resistance_bonus | 0.25 | 百分点比例 | 强化已存在抗性所增加的减伤比例 |
| memory_a_bonus | 0.2 | 比例/节点 | 记忆A节点恢复与保护上限加成；节点相加 |
| memory_b1_probability | 0.1 | 概率/恢复跳 | 实际全局恢复跳触发共享减伤的概率 |
| memory_b1_reduction | 0.5 | 比例 | 恢复触发的共享原始伤害减免 |
| memory_b1_duration | 1 | 秒 | 恢复触发的共享减伤持续时间 |
| memory_b2_resistance | 0.5 | 减伤比例 | 记忆保护授予匹配物理或能量抗性 |
| memory_b2_duration | 2 | 秒 | 记忆保护匹配抗性的持续时间 |
| memory_b2_lockout | 2 | 秒 | 异类来袭清除后禁止重获抗性的时间 |
| memory_b3_shield_charge_bonus | 0.4 | 比例/件 | 每件启用能量护盾增加记忆充能 |
| memory_b3_armour_capacity_bonus | 0.4 | 比例/件 | 每件启用复合装甲增加记忆上限 |
| deferred_a_clear_probability | 0.1 | 百分点比例/节点 | 延迟A节点增加全局清除概率；每节点只计一次 |
| deferred_b1_reduction | 0.2 | 比例 | 清除队列触发的共享原始伤害减免 |
| deferred_b1_duration | 1 | 秒 | 清除队列触发的共享减伤持续时间 |
| deferred_b2_probability_conversion | 0.5 | 倍率 | 未强制的清除概率转化为减伤的比例 |
| deferred_b3_forced_probability | 1 | 概率 | 必然消散的实际清除概率；默认必定 |
| deferred_b3_damage_scale | 1 | 倍率 | 未强制清除概率缺口转化为伤害增加的系数 |
| branch_position_offset_1 | 0 | 有效强化级 | 第1顺位分支门槛偏移；与主效果启用门槛独立 |
| branch_position_offset_2 | 10 | 有效强化级 | 第2顺位分支门槛偏移；与主效果启用门槛独立 |
| branch_position_offset_3 | 20 | 有效强化级 | 第3顺位分支门槛偏移；与主效果启用门槛独立 |


### equipment 数值


**equipment**

| name | level | dmgtype | dmg | dmgMulti | cd | res_1 | cost_1 | costMulti_1 | res_2 | cost_2 | costMulti_2 | para1 | para2 | para3 | para4 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| armour | 1 | 2 | 0 | — | 0 | 1 | 50 | 0.2 | — | — | — | 1000 | 0.2 | — | — |
| shield | 1 | 1 | 0 | — | 0 | 1 | 50 | 0.2 | — | — | — | 750 | 0.3 | 2 | 0.2 |
| laser | 1 | 1 | 350 | 0.2 | 1.5 | 1 | 50 | 0.2 | — | — | — | 30 | — | — | — |
| missile | 1 | 2 | 170 | 0.2 | 2.4 | 1 | 50 | 0.2 | — | — | — | 4 | 30 | — | — |
| cannon | 1 | 2 | 1200 | 0.2 | 3.5 | 1 | 50 | 0.2 | — | — | — | 40 | — | — | — |
| laser_mon | 1 | 1 | 20 | — | 0.5 | — | — | — | — | — | — | 20 | — | — | — |
| missile-mon | 1 | 2 | 5 | — | 1 | — | — | — | — | — | — | 3 | 20 | — | — |
| cannon-mon | 1 | 2 | 40 | — | 1 | — | — | — | — | — | — | 20 | — | — | — |
| longLaser | 1 | 1 | 35 | 0.2 | 0.25 | 1 | 50 | 0.2 | — | — | — | 2 | 3 | 1 | — |
| longLaser-mon | 1 | 1 | 5 | 0.2 | 0.2 | 1 | 50 | 0.2 | — | — | — | 2 | 1 | 1 | — |
| laser-mon | 1 | 1 | 80 | — | 3.6 | — | — | — | — | — | — | 20 | — | — | — |


### galaxy 数值


**galaxy**

| id | key | name | order | unlock_type | unlock_value | next_galaxy | map_w | map_h | start_w | start_h | building_slot_count | slot_seed | explore_work_total | explore_power_base | explore_power_per_crew | ship_per_crew | build_interval | construction_time | upgrade_power_base | upgrade_power_per_crew | upgrade_cost_lv2 | upgrade_cost_lv3 | upgrade_cost_lv4 | upgrade_cost_lv5 | concurrent_upgrade_count | special_cycle |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | galaxy_1 | 第一星系 | 1 | stage_cleared | 60 | — | 200 | 200 | 10 | 10 | 30 | 20260929 | 30000 | 1 | 1 | 1 | 10 | 30 | 1 | 0.5 | 360 | 540 | 720 | 900 | 2 | 5 |


### galaxy_build 数值


**galaxy_build**

| id | key | galaxy_key | name | group | max_lv | effect_type | base_effect |
|---|---|---|---|---|---|---|---|
| 1 | colony_ring | galaxy_1 | 殖民环 | normal | 5 | crew_exp | 0.1 |
| 2 | orbital_shipyard | galaxy_1 | 轨道船坞 | normal | 5 | equipment_value | 0.1 |
| 3 | stellar_energy_array | galaxy_1 | 恒星能源阵列 | normal | 5 | charge_max | 0.1 |
| 4 | interstellar_refinery | galaxy_1 | 星际炼铁厂 | normal | 5 | iron_auto_ratio | 0.05 |
| 5 | crystal_refinery | galaxy_1 | 晶体精炼厂 | normal | 5 | gem_fragment | 0.1 |
| 6 | heavy_element_refinery | galaxy_1 | 重元素精炼厂 | special | 5 | uranium_auto_ratio | 0.05 |


### galaxy_config 数值


**galaxy_config**

| key | value | type | des |
|---|---|---|---|
| visible_tick | 1 | float | 可见逻辑秒 |
| hidden_tick | 10 | float | 隐藏在线批次秒 |
| chunk_size | 32 | int | 探索纹理脏区边长 |
| disable_hidden_visual | 1 | bool | 隐藏停全部视觉 |
| income_interval | 10 | float | 在线资源结算秒 |
| iron_resource_id | 1 | int | 沿用铁资源ID |
| max_transport_ships | 6 | int | 交通艇池上限 |
| max_visual_pulses | 4 | int | 短时脉冲上限 |
| camera_zoom_min | 0.4 | float | 最小相机缩放 |
| camera_zoom_max | 0.6 | float | 最大相机缩放 |
| transport_buildings_per_ship | 5 | float | 每艇对应已建成功能建筑（座/艇） |
| transport_initial_delay | 1.4 | float | 展示艇首次启程延迟（秒） |
| transport_departure_interval | 0.8 | float | 展示艇错峰启程间隔（秒） |


### hightech 数值


**hightech**

| name | des | description | tpCostBase | tpCostMutiple | tpCostMutiple2 | para1 | para2 |
|---|---|---|---|---|---|---|---|
| 超时空炼铁炉 | 每para1秒在屏幕中生成一个铁块，总共含有根据过去一分钟的铁生成量*para2*等级的铁，向上取整，点击获取，10秒后消失 | 每para1秒在屏幕中生成一个含有{过去一分钟的铁生成量*para2*等级,向上取整,不含自身}的铁的铁块 | 60 | 2 | 0.1 | 30 | 0.1 |
| 正电子聚焦装置 | 提高所有武器的伤害，效果为原伤害*（1+para1)^等级向上取整. | 所有武器伤害提高{(1+para1)^等级,百分比显示,保留两位小数,即100.3%展示为100%} | 60 | 2 | 0.1 | 0.05 | — |
| 简并态装甲 | 生命和护盾最大值增加（1+para1）^等级，向上取整。 | 生命增加{（1+para1）^等级,百分比显示,保留两位小数,即100.3%展示为100%} | 60 | 2 | 0.1 | 0.05 | — |
| 宝石熔炼炉 | 每para1秒在屏幕中生成一个强化核心，总共含有根据过去一分钟的强化碎片生成量*para2*等级的碎片，向上取整，鼠标划过获取，10秒后消失 | 每para1秒在屏幕中生成一个含有{过去一分钟的宝石碎片生成量*para2*等级,向上取整,不含自身}的强化核心块 | 60 | 2 | 0.1 | 20 | 0.02 |


### hyperspace_config 数值


**基础参数**

| key | data_type | value | unit |
|---|---|---|---|
| unlock_stage | int | 8 | 主线最高到达关 |
| minimum_level | int | 5 | 所选主线等级/关 |
| energy_rate | float | 10 | 能量/游戏秒 |
| energy_cap | float | 216000 | 能量 |
| ticket | float | 108000 | 能量/次 |
| minimum_duration | float | 10 | 游戏秒 |
| warehouse_capacity | int | 200 | 架/格 |
| overflow_capacity | int | 10 | 架/格 |
| reforge_capacity_gain | int | 10 | 格/次重铸 |
| initial_retention_capacity | int | 0 | 架 |
| retention_capacity_gain | int | 10 | 架/次重铸 |
| maximum_equipped | int | 5 | 架 |
| maximum_legendary | int | 2 | 架 |
| maximum_ultimate | int | 1 | 架 |
| completion_budget | int | 8 | 次/一次advance |
| ultimate_weapon_bonus | int | 5 | 武器有效等级增量 |
| affix_initial_probability | float | 1 | 概率，0..1 |
| hanging_initial_probability | float | 0.2 | 概率，0..1 |
| additional_probability_factor | float | 0.25 | 概率递乘因子，0..1 |
| value_precision | float | 0.001 | 原始参数量化步长 |
| amplification_rate | float | 0.05 | 每无人机等级复合增长率 |
| amplification_start_level | int | 4 | 无人机等级 |
| material_base_reward | int | 1 | 专属材料份/成功探索 |
| material_reward_level_step | int | 3 | 无人机/探索等级增量每份 |
| material_reward_start_level | int | 5 | 探索等级起点 |
| maximum_filter_conditions | int | 5 | 条 |
| maximum_filter_string_length | int | 4096 | 字符 |
| maximum_forecast_attempts | int | 10000 | 次 |
| lock_cost_multiplier | int | 4 | 每个已锁词缀的费用倍率 |
| reroll_guarantee_multiplier | int | 3 | 期望成本乘数 |
| modernization_cost_base | int | 10 | 材料份；也是舍入粒度 |
| modernization_level_step | int | 3 | 探索/无人机等级增量 |
| modernization_legendary_multiplier | int | 2 | 费用倍率 |
| late_supply_unlock_stage | int | 60 | 已清主线关ID |
| late_energy_rate_multiplier | float | 30 | 基础速率的终值倍率 |
| late_material_reward_multiplier | int | 4 | 专属材料终值倍率 |
| late_supply_ramp_seconds | int | 600 | 在线游戏秒 |
| modernization_base_coefficient | float | 1 | 无量纲费用系数 |
| material_unit_scale | int | 10 | 常规材料单位倍率 |
| ultimate_core_probability | float | 0.002 | 成功探索实际概率 |


**路线**

| order | route_id | weapon | material |
|---|---|---|---|
| 0 | alpha | laser | degenerate_matter |
| 1 | beta | missile | glueball |
| 2 | gamma | cannon | antiproton |
| 3 | delta | longLaser | zero_point_energy |


**品质**

| order | quality | weight | affix_limit | hanging_limit | weapon_level_bonus | dismantle_amount |
|---|---|---|---|---|---|---|
| 0 | white | 0.5 | 0 | 4 | 0 | 1 |
| 1 | blue | 0.26 | 2 | 2 | 3 | 2 |
| 2 | gold | 0.15 | 3 | 1 | 1 | 5 |
| 3 | legendary | 0.08 | 3 | 0 | 1 | 10 |
| 4 | ultimate_core | 0.1 | — | — | — | — |


**舰型容量**

| order | hull_id | capacity |
|---|---|---|
| 0 | Frigate | 1 |
| 1 | Destroyer | 2 |
| 2 | Cruiser | 3 |
| 3 | Battleship | 4 |
| 4 | Heavy_Battleship | 5 |


**阶级权重**

| order | tier | draw_weight | modernization_weight |
|---|---|---|---|
| 0 | 1 | 1 | 10 |
| 1 | 2 | 5 | 5 |
| 2 | 3 | 15 | 3 |
| 3 | 4 | 45 | 1 |
| 4 | 5 | 135 | 0.5 |


**词缀定义**

| order | affix_id | weapon | amplified |
|---|---|---|---|
| 0 | damage_laser | laser | True |
| 1 | damage_missile | missile | True |
| 2 | damage_cannon | cannon | True |
| 3 | damage_longLaser | longLaser | True |
| 4 | global_damage | — | True |
| 5 | global_critical_damage | — | True |
| 6 | global_defence | — | True |
| 7 | critical_chance | — | False |
| 8 | repeat_chance | — | False |
| 9 | attack_speed | — | False |
| 10 | chain_count | — | False |
| 11 | armour_capacity | — | True |
| 12 | shield_capacity | — | True |


**词缀区间**

| affix_id | tier | minimum | maximum |
|---|---|---|---|
| damage_laser | 1 | 1.8 | 2 |
| damage_laser | 2 | 1.2 | 1.5 |
| damage_laser | 3 | 0.8 | 1 |
| damage_laser | 4 | 0.4 | 0.6 |
| damage_laser | 5 | 0.1 | 0.2 |
| damage_missile | 1 | 1.8 | 2 |
| damage_missile | 2 | 1.2 | 1.5 |
| damage_missile | 3 | 0.8 | 1 |
| damage_missile | 4 | 0.4 | 0.6 |
| damage_missile | 5 | 0.1 | 0.2 |
| damage_cannon | 1 | 1.8 | 2 |
| damage_cannon | 2 | 1.2 | 1.5 |
| damage_cannon | 3 | 0.8 | 1 |
| damage_cannon | 4 | 0.4 | 0.6 |
| damage_cannon | 5 | 0.1 | 0.2 |
| damage_longLaser | 1 | 1.8 | 2 |
| damage_longLaser | 2 | 1.2 | 1.5 |
| damage_longLaser | 3 | 0.8 | 1 |
| damage_longLaser | 4 | 0.4 | 0.6 |
| damage_longLaser | 5 | 0.1 | 0.2 |
| global_damage | 1 | 0.9 | 1 |
| global_damage | 2 | 0.6 | 0.75 |
| global_damage | 3 | 0.4 | 0.5 |
| global_damage | 4 | 0.2 | 0.3 |
| global_damage | 5 | 0.05 | 0.1 |
| global_critical_damage | 1 | 0.9 | 1 |
| global_critical_damage | 2 | 0.6 | 0.75 |
| global_critical_damage | 3 | 0.4 | 0.5 |
| global_critical_damage | 4 | 0.2 | 0.3 |
| global_critical_damage | 5 | 0.05 | 0.1 |
| global_defence | 1 | 0.9 | 1 |
| global_defence | 2 | 0.6 | 0.75 |
| global_defence | 3 | 0.4 | 0.5 |
| global_defence | 4 | 0.2 | 0.3 |
| global_defence | 5 | 0.05 | 0.1 |
| critical_chance | 1 | 0.13 | 0.15 |
| critical_chance | 2 | 0.1 | 0.12 |
| critical_chance | 3 | 0.06 | 0.08 |
| critical_chance | 4 | 0.03 | 0.04 |
| critical_chance | 5 | 0.01 | 0.02 |
| repeat_chance | 1 | 0.13 | 0.15 |
| repeat_chance | 2 | 0.1 | 0.12 |
| repeat_chance | 3 | 0.06 | 0.08 |
| repeat_chance | 4 | 0.03 | 0.04 |
| repeat_chance | 5 | 0.01 | 0.02 |
| attack_speed | 1 | 0.13 | 0.15 |
| attack_speed | 2 | 0.1 | 0.12 |
| attack_speed | 3 | 0.06 | 0.08 |
| attack_speed | 4 | 0.03 | 0.04 |
| attack_speed | 5 | 0.01 | 0.02 |
| chain_count | 1 | 2 | 2 |
| chain_count | 2 | 1 | 1 |
| armour_capacity | 1 | 1.8 | 2 |
| armour_capacity | 2 | 1.2 | 1.5 |
| armour_capacity | 3 | 0.8 | 1 |
| armour_capacity | 4 | 0.4 | 0.6 |
| armour_capacity | 5 | 0.1 | 0.2 |
| shield_capacity | 1 | 1.8 | 2 |
| shield_capacity | 2 | 1.2 | 1.5 |
| shield_capacity | 3 | 0.8 | 1 |
| shield_capacity | 4 | 0.4 | 0.6 |
| shield_capacity | 5 | 0.1 | 0.2 |


**挂设成长**

| order | module_id | base_exp | exp_growth | effect_growth | unlock_stage | effects_note |
|---|---|---|---|---|---|---|
| 0 | resource_collector | 100 | 0.2 | 0.1 | 0 | iron_income；uranium_income |
| 1 | distributed_algorithm | 100 | 0.2 | 0.1 | 0 | ai_speed |
| 2 | extra_storage | 100 | 0.2 | 0.1 | 0 | reactor_energy_cap |
| 3 | gem_refiner | 100 | 0.2 | 0.1 | 15 | gem_income |
| 4 | hyperspace_charge | 100 | 0.2 | 0.1 | 0 | hyperspace_material_income |


**传说定义**

| order | effect_id | weapon | score_parameter_note |
|---|---|---|---|
| 0 | higgs_cannon | cannon | damage_bonus |
| 1 | scatter_pulse | laser | single_target_bonus |
| 2 | precise_guidance | missile | — |
| 3 | prism_tower | longLaser | maximum_multiplier_bonus |
| 4 | strange_matter | cannon | damage_multiplier |
| 5 | laser_charge | laser | maximum_bonus |
| 6 | wild_missile | missile | damage_multiplier |
| 7 | endless_beam | longLaser | maximum_multiplier_bonus |
| 8 | dodge_counter | — | maximum_dodge |
| 9 | drone_master | — | maximum_reduction |
| 10 | black_hole | — | damage_multiplier |
| 11 | drone_rebuild | — | damage_and_defence_bonus |


**传说随机参数**

| effect_id | order | parameter | minimum | maximum | unit | description |
|---|---|---|---|---|---|---|
| higgs_cannon | 0 | damage_bonus | 2 | 3 | 伤害加成比例 | 炮伤乘1+本值；2表示×3。调大更强；只改变伤害，不改变宽度。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| higgs_cannon | 1 | area_bonus | 1 | 2 | 射线宽度加成比例 | 射线宽度乘1+本值；1表示宽度×2。调大命中区域更宽；不是面积平方倍率。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| scatter_pulse | 0 | single_target_bonus | 2 | 3 | 单目标伤害加成比例 | 场上仅一个有效目标时激光乘1+本值；2表示×3。调大单体更强，多目标时不生效。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| prism_tower | 0 | maximum_multiplier_bonus | 1.3 | 2 | 激光最大倍率加法增量 | 对该棱镜塔源既有激光最大倍率加本值，调大蓄满倍率更高，不是全部激光再乘本值。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| strange_matter | 0 | damage_multiplier | 1.3 | 2 | 直接伤害倍率 | 延迟奇异物质伤害=炮击原伤×本值，1.3表示×1.3。调大后续伤害更强，不改变概率。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| laser_charge | 0 | maximum_bonus | 2 | 3 | 激光额外伤害比例上限 | 额外比例取min(本值,每激光加成×激光来源数)，最终乘1+比例。调大只放宽上限，来源不足时不增伤。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| wild_missile | 0 | damage_multiplier | 7 | 10 | 直接伤害倍率 | 特殊主导弹伤害乘本值，7表示×7。调大单次更强；触发间隔由attack_period另管。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| endless_beam | 0 | maximum_multiplier_bonus | 1 | 2 | 激光最大倍率加法增量 | 仅选定最强持续长激光源的既有最大倍率加本值。调大持续源更强，不同时新增多个持续源。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| dodge_counter | 0 | maximum_dodge | 0.75 | 0.9 | 闪避概率上限，0..1 | 实际概率=min(当前武器最高暴击概率,本值)。0.75为75%上限，不能保证实际75%；调大只解除上限限制。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| dodge_counter | 1 | counter_damage_bonus | 0.7 | 1 | 反击伤害加成比例 | 反击随机现有武器伤害乘1+本值，0.7表示×1.7。调大反击更强，不提高闪避概率。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| drone_master | 0 | maximum_reduction | 0.5 | 0.6 | 减伤比例上限，0..1 | 实际减伤=本值×未失效已装备机最大品质系数/究极系数。0.5为最高品质50%；品质系数取最大不加总。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| black_hole | 0 | damage_multiplier | 1.3 | 2 | 释放伤害直接倍率 | 黑洞释放伤害=吸收的己方原伤累计×本值。1.3表示×1.3；敌方伤害吸收用于防护，不计入释放伤害。 本页区间用于新生成/重洗，不自动重抽已有存值。 |
| drone_rebuild | 0 | damage_and_defence_bonus | 0.7 | 1 | 每牺牲一次的伤害/防御加成比例 | 每次重建牺牲一架可用无人机，累计加本值。0.7、两层累计+140%；调大每层更强，层上限另管。 本页区间用于新生成/重洗，不自动重抽已有存值。 |


**传说常量**

| effect_id | constant_path | data_type | value | unit |
|---|---|---|---|---|
| higgs_cannon | maximum_cannon_sources | int | 1 | 炮类武器来源数 |
| precise_guidance | stack_multiplier | float | 1.5 | 每已有层数的复合倍率底数 |
| precise_guidance | stack_limit_enabled | bool | False | 开关 |
| precise_guidance | stack_limit | int | 0 | 层 |
| precise_guidance | counting_policy | string | first_hit_per_batch_per_target | 固定行为声明 |
| prism_tower | nearby_targets | int | 5 | 额外连锁目标/跳数 |
| prism_tower | maximum_towers | int | 1 | 固定塔来源数 |
| strange_matter | spawn_probability | float | 0.4 | 非击杀炮命中的生成概率，0..1 |
| strange_matter | delay | int | 1 | 游戏秒 |
| strange_matter | kill_spawns | int | 2 | 份/击杀炮击 |
| laser_charge | bonus_per_laser | float | 0.5 | 每个激光来源的加成比例 |
| wild_missile | attack_period | int | 3 | 特殊攻击前的普通主导弹批次数 |
| wild_missile | blast_fraction | float | 0.5 | 主击伤害比例，0..1 |
| dodge_counter | cooldown | int | 2 | 游戏秒 |
| drone_master | quality_ratios/white | float | 0.5 | 无量纲相对品质系数 |
| drone_master | quality_ratios/blue | float | 0.6 | 无量纲相对品质系数 |
| drone_master | quality_ratios/gold | float | 0.7 | 无量纲相对品质系数 |
| drone_master | quality_ratios/legendary | float | 0.8 | 无量纲相对品质系数 |
| drone_master | quality_ratios/ultimate | float | 0.9 | 无量纲相对品质系数 |
| black_hole | period | int | 20 | 游戏秒 |
| black_hole | absorption_duration | int | 5 | 游戏秒 |
| drone_rebuild | maximum_stacks | int | 4 | 层/一场战斗 |


**改造费用**

| operation_order | operation | resource | resource_order | amount |
|---|---|---|---|---|
| 0 | add_affix | degenerate_matter | 0 | 1 |
| 1 | replace_affix | degenerate_matter | 0 | 5 |
| 2 | add_hanging_slot | glueball | 0 | 10 |
| 3 | lock_affix | glueball | 0 | 100 |
| 4 | promote_affix | antiproton | 0 | 1 |
| 5 | reroll_values | antiproton | 0 | 5 |
| 6 | enable_omen | zero_point_energy | 0 | 5 |
| 7 | legendary | zero_point_energy | 0 | 100 |
| 8 | ultimate | ultimate_cores | 0 | 1 |
| 9 | restore_ultimate | ultimate_cores | 0 | 1 |


**固定规则_兼容说明**

| key | data_type | value | unit |
|---|---|---|---|
| /version | int | 2 | 版本号 |
| /maximum_command_id_length | int | 96 | 字符 |
| /policies/core_reward | string | exclusive | 固定奖励策略 |
| /policies/promotion_success | string | weighted_draw_stronger | 固定升阶策略 |
| /policies/omen_scope | string | drone | 固定预兆作用域 |
| /policies/legendary_selection | string | strongest_primary_stable_id | 未消费的旧声明 |
| /policies/sealed_unlock | string | reached_planet_stage | 固定封存领取声明 |
| /policies/legendary_repeat_action | null | — | 未接入预留项 |
| /hanging_modules/resource_collector/effects/0 | string | iron_income | 固定模块路由提示 |
| /hanging_modules/resource_collector/effects/1 | string | uranium_income | 固定模块路由提示 |
| /hanging_modules/distributed_algorithm/effects/0 | string | ai_speed | 固定模块路由提示 |
| /hanging_modules/extra_storage/effects/0 | string | reactor_energy_cap | 固定模块路由提示 |
| /hanging_modules/gem_refiner/effects/0 | string | gem_income | 固定模块路由提示 |
| /hanging_modules/hyperspace_charge/effects/0 | string | hyperspace_material_income | 固定模块路由提示 |
| /legendary_effects/drone_master/stored_parameter_ranges/maximum_reduction/0 | float | 0.8 | 已有存值校验下界 |
| /legendary_effects/drone_master/stored_parameter_ranges/maximum_reduction/1 | float | 0.9 | 已有存值校验上界 |


### planet 数值


**planet**

| id | name | unlockId | baseTime | baseExp | reforgeStartLevel | minTime |
|---|---|---|---|---|---|---|
| 1 | 始源星-E178b | planet/1 | 60 | 100 | 5 | 60 |
| 2 | 气态巨星-T587e | planet/2 | 60 | 150 | 10 | 5 |
| 3 | 主序星-UTE334 | planet/3 | 60 | 200 | 15 | 5 |
| 4 | 红巨星-RG214 | planet/4 | 60 | 250 | 20 | 5 |
| 5 | 白矮星-WS113 | planet/5 | 60 | 300 | 25 | 5 |
| 6 | 脉冲星-PSR T46+38 | planet/6 | 60 | 350 | 30 | 5 |


### planet_buff 数值


**planet_buff**

| id | planet_id | source | source_id | condition | buff_type | target | value | stack | order | des |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | conquer | 0 | conquered | level_bonus | equipment | 35 | add | 1 | 装备效果等级 +35 |
| 3 | 1 | conquer | 0 | conquered | free_charge | all | 0.1 | add | 3 | 所有充能模块免费充能 +10% |
| 4 | 1 | conquer | 0 | conquered | level_bonus | enhancement | 1 | add | 4 | 强化附加等级 +1 |
| 5 | 1 | conquer | 0 | conquered | crew_exp_share | all | 1 | max | 5 | 本星球探索经验同步至所有船员 |
| 6 | 2 | conquer | 0 | conquered | crew_exp_share | all | 1 | max | 5 | 本星球探索经验同步至所有船员 |
| 7 | 3 | conquer | 0 | conquered | crew_exp_share | all | 1 | max | 5 | 本星球探索经验同步至所有船员 |
| 8 | 4 | conquer | 0 | conquered | crew_exp_share | all | 1 | max | 5 | 本星球探索经验同步至所有船员 |
| 9 | 5 | conquer | 0 | conquered | crew_exp_share | all | 1 | max | 5 | 本星球探索经验同步至所有船员 |
| 10 | 6 | conquer | 0 | conquered | crew_exp_share | all | 1 | max | 5 | 本星球探索经验同步至所有船员 |
| 11 | 2 | conquer | 0 | conquered | level_bonus | equipment | 15 | add | 1 | 装备效果等级 +15 |
| 13 | 2 | conquer | 0 | conquered | free_charge | all | 0.1 | add | 3 | 所有充能模块免费充能 +10% |
| 14 | 2 | conquer | 0 | conquered | level_bonus | enhancement | 1 | add | 4 | 强化附加等级 +1 |
| 15 | 3 | conquer | 0 | conquered | level_bonus | equipment | 15 | add | 1 | 装备效果等级 +15 |
| 17 | 3 | conquer | 0 | conquered | free_charge | all | 0.1 | add | 3 | 所有充能模块免费充能 +10% |
| 18 | 3 | conquer | 0 | conquered | level_bonus | enhancement | 1 | add | 4 | 强化附加等级 +1 |
| 19 | 4 | conquer | 0 | conquered | level_bonus | equipment | 15 | add | 1 | 装备效果等级 +15 |
| 21 | 4 | conquer | 0 | conquered | free_charge | all | 0.1 | add | 3 | 所有充能模块免费充能 +10% |
| 22 | 4 | conquer | 0 | conquered | level_bonus | enhancement | 1 | add | 4 | 强化附加等级 +1 |
| 23 | 5 | conquer | 0 | conquered | level_bonus | equipment | 15 | add | 1 | 装备效果等级 +15 |
| 25 | 5 | conquer | 0 | conquered | free_charge | all | 0.1 | add | 3 | 所有充能模块免费充能 +10% |
| 26 | 5 | conquer | 0 | conquered | level_bonus | enhancement | 1 | add | 4 | 强化附加等级 +1 |
| 27 | 6 | conquer | 0 | conquered | level_bonus | equipment | 15 | add | 1 | 装备效果等级 +15 |
| 29 | 6 | conquer | 0 | conquered | free_charge | all | 0.1 | add | 3 | 所有充能模块免费充能 +10% |
| 30 | 6 | conquer | 0 | conquered | level_bonus | enhancement | 1 | add | 4 | 强化附加等级 +1 |
| 31 | 1 | conquer | 0 | conquered | planet_unlock | planet | 2 | max | 6 | 能够探索新星球：气态巨星-T587e |
| 32 | 2 | conquer | 0 | conquered | planet_unlock | planet | 3 | max | 6 | 能够探索新星球：主序星-UTE334 |
| 33 | 3 | conquer | 0 | conquered | planet_unlock | planet | 4 | max | 6 | 能够探索新星球：红巨星-RG214 |
| 34 | 4 | conquer | 0 | conquered | planet_unlock | planet | 5 | max | 6 | 能够探索新星球：白矮星-WS113 |
| 35 | 5 | conquer | 0 | conquered | planet_unlock | planet | 6 | max | 6 | 能够探索新星球：脉冲星-PSR T46+38 |
| 36 | 1 | conquer | 0 | conquered | luck | all | 100 | add | 7 | 永久幸运 +{value} |
| 37 | 2 | conquer | 0 | conquered | luck | all | 100 | add | 7 | 永久幸运 +{value} |
| 38 | 3 | conquer | 0 | conquered | luck | all | 100 | add | 7 | 永久幸运 +{value} |
| 39 | 4 | conquer | 0 | conquered | luck | all | 100 | add | 7 | 永久幸运 +{value} |
| 40 | 5 | conquer | 0 | conquered | luck | all | 100 | add | 7 | 永久幸运 +{value} |
| 41 | 6 | conquer | 0 | conquered | luck | all | 100 | add | 7 | 永久幸运 +{value} |


### planet_build 数值


**planet_build**

| id | name | des | min_planet | planet_rule | planet_value | order | unlock_explore | build_explore | extra_crew | type | config1 | config2 | previous_id |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| station | 空间站 | 建成后可开启自动探索。 | 1 | all | — | 1 | 1 | 1 | 0 | auto_explore | 0 | 0 | — |
| refinery | 资源精炼厂 | 提升铁与铀直接掉落，多个星球效果相乘。 | 1 | all | — | 2 | 20 | 5 | 0 | refinery | 0.01 | 0.35 | — |
| workshop | 装备工坊 | 提升装备系统普通数值，多个星球效果相乘。 | 1 | all | — | 3 | 50 | 10 | 0 | equipment | 0.01 | 0.4 | — |
| shipyard | 新式船坞 | 点「分配施工船员」开工；建好后领取船坞，再决定是否重铸。重铸前会显示保留内容和本轮重置范围。 | 1 | only | 1 | 4 | 30 | 180 | 1 | shipyard | 0 | 0 | — |
| shipyard_later | 新式船坞 | 点「分配施工船员」开工；建好后领取船坞，再决定是否重铸。重铸前会显示保留内容和本轮重置范围。 | 1 | exclude | 1 | 4 | 150 | 10 | 1 | shipyard | 0 | 0 | shipyard |


### res 数值


**res**

| id | name |
|---|---|
| 1 | 铁 |
| 2 | 铀 |


### ship 数值


**ship**

| name | des | para_1 | para_2 | para_3 | — | para_5 | para_6 |
|---|---|---|---|---|---|---|---|
| Frigate | 游隼侦察艇 | 1 | 1 | 50 | — | 1 | 999 |
| Destroyer | 飞燕护卫舰 | 2 | 1 | 50 | — | 1 | 999 |
| Cruiser | 云鳐巡洋舰 | 3 | 2 | 50 | — | 2 | 999 |
| Battleship | 玄甲战列舰 | 4 | 2 | 50 | — | 2 | 999 |
| Heavy_Battleship | 白鲸无畏舰 | 5 | 3 | 50 | — | 4 | 999 |


### unlock 数值


**unlock**

| name | type | target | level | mode | title | desc |
|---|---|---|---|---|---|---|
| armour | equipment | armour | 0 | cleared | 复合装甲 | 复合装甲已解锁。 |
| shield | equipment | shield | 2 | cleared | 偏转护盾 | 偏转护盾已解锁。 |
| laser | equipment | laser | 0 | cleared | 脉冲激光 | 脉冲激光已解锁。 |
| missile | equipment | missile | 1 | cleared | 追踪导弹 | 追踪导弹已解锁。 |
| cannon | equipment | cannon | 2 | cleared | 磁轨火炮 | 磁轨火炮已解锁。 |
| longLaser | equipment | longLaser | 5 | cleared | 持续锁定光束 | 持续锁定光束已解锁。 |
| ship/Frigate | ship | Frigate | 0 | cleared | 游隼侦察艇 | 游隼侦察艇已解锁。 |
| ship/Destroyer | ship | Destroyer | 10 | cleared | 飞燕护卫舰 | 飞燕护卫舰已解锁。 |
| ship/Cruiser | ship | Cruiser | 20 | cleared | 云鳐巡洋舰 | 云鳐巡洋舰已解锁。 |
| ship/Battleship | ship | Battleship | 30 | cleared | 玄甲战列舰 | 玄甲战列舰已解锁。 |
| ship/Heavy_Battleship | ship | Heavy_Battleship | 50 | cleared | 白鲸无畏舰 | 白鲸无畏舰已解锁。 |
| reactor | feature | reactor | 1 | cleared | 反应炉 | 反应炉已解锁。 |
| hightech/超时空炼铁炉 | hightech | 超时空炼铁炉 | 3 | cleared | 超时空炼铁炉 | 超时空炼铁炉已解锁。 |
| hightech/正电子聚焦装置 | hightech | 正电子聚焦装置 | 4 | cleared | 正电子聚焦装置 | 正电子聚焦装置已解锁。 |
| hightech/简并态装甲 | hightech | 简并态装甲 | 4 | cleared | 简并态装甲 | 简并态装甲已解锁。 |
| hightech/宝石熔炼炉 | hightech | 宝石熔炼炉 | 12 | cleared | 强化碎片熔炼炉 | 强化碎片熔炼炉已解锁。 |
| feature/jewels | feature | jewels | 7 | reached | 装备强化 | 装备强化已解锁。 |
| crew/navigator | crew | navigator | 10 | cleared | 船员01 | 船员01已解锁。 |
| crew/engineer | crew | engineer | 20 | cleared | 船员02 | 船员02已解锁。 |
| crew/researcher | crew | researcher | 25 | cleared | 船员03 | 船员03已解锁。 |
| crew/crew_04 | crew | crew_04 | 30 | cleared | 船员04 | 船员04已解锁。 |
| crew/crew_05 | crew | crew_05 | 35 | cleared | 船员05 | 船员05已解锁。 |
| crew/crew_06 | crew | crew_06 | 40 | cleared | 船员06 | 船员06已解锁。 |
| planet/1 | planet | 1 | 30 | cleared | 星球探索 | 星球探索已解锁。 |
| feature/crew_level | feature | crew_level | 30 | cleared | 船员等级 | 船员等级已解锁。 |
| reactor_module/condensation | reactor_module | condensation | 15 | cleared | 强化凝聚 | 强化凝聚已解锁。 |
| planet/2 | planet | 2 | 35 | cleared | 星球探索 | 新行星已发现。 |
| planet/3 | planet | 3 | 40 | cleared | 星球探索 | 新行星已发现。 |
| planet/4 | planet | 4 | 45 | cleared | 星球探索 | 新行星已发现。 |
| planet/5 | planet | 5 | 50 | cleared | 星球探索 | 新行星已发现。 |
| planet/6 | planet | 6 | 55 | cleared | 星球探索 | 新行星已发现。 |
| feature/galaxy | feature | galaxy | 60 | cleared | 星系殖民 | 星系殖民已解锁。 |
| crew/crew_07 | crew | crew_07 | 45 | cleared | 船员07 | 船员07已解锁。 |
| crew/crew_08 | crew | crew_08 | 50 | cleared | 船员08 | 船员08已解锁。 |
| crew/crew_09 | crew | crew_09 | 55 | cleared | 船员09 | 船员09已解锁。 |
| crew/crew_10 | crew | crew_10 | 60 | cleared | 船员10 | 船员10已解锁。 |
| crew/crew_11 | crew | crew_11 | 70 | cleared | 船员11 | 船员11已解锁。 |
| crew/crew_12 | crew | crew_12 | 80 | cleared | 船员12 | 船员12已解锁。 |
| crew/crew_13 | crew | crew_13 | 90 | cleared | 船员13 | 船员13已解锁。 |
| crew/crew_14 | crew | crew_14 | 100 | cleared | 船员14 | 船员14已解锁。 |
| crew/crew_15 | crew | crew_15 | 110 | cleared | 船员15 | 船员15已解锁。 |
| crew/crew_16 | crew | crew_16 | 120 | cleared | 船员16 | 船员16已解锁。 |
| crew/crew_17 | crew | crew_17 | 130 | cleared | 船员17 | 船员17已解锁。 |
| crew/crew_18 | crew | crew_18 | 140 | cleared | 船员18 | 船员18已解锁。 |
| crew/crew_19 | crew | crew_19 | 150 | cleared | 船员19 | 船员19已解锁。 |
| crew/crew_20 | crew | crew_20 | 160 | cleared | 船员20 | 船员20已解锁。 |


### weapon_motion 数值


**weapon_motion**

| id | value | unit | description | scope |
|---|---|---|---|---|
| player_projectile_pixels_per_unit | 28 | 像素/单位 | 玩家普通弹体与导弹巡航速度的单位换算 | 玩家 |
| enemy_projectile_pixels_per_unit | 28 | 像素/单位 | 敌方普通弹体速度单位换算；与玩家参数独立 | 敌方 |
| player_cannon_speed_multiplier | 1 | 倍 | 玩家火炮表para1速度再乘此倍率；敌方不乘 | 玩家火炮 |
| chain_carrier_speed | 720 | 像素/秒 | 到达后结算的玩家连锁载体速度 | 玩家连锁 |
| missile_ejection_gap | 0.12 | 秒 | 同批逐枚离管间隔 | 玩家导弹 |
| missile_launch_speed | 240 | 像素/秒 | 离管初速；巡航速度来自equipment.missile.para2 | 玩家导弹 |
| missile_turn_rate | 4 | 弧度/秒 | 制导最大转角速度 | 玩家导弹 |
| missile_orphan_lifetime | 30 | 秒 | 失锁直飞安全上限；通常先正常离屏 | 玩家导弹 |
| missile_reacquire_interval | 0.12 | 秒 | 尚未离管的无效目标重选缓存间隔；飞行弹体不重锁 | 玩家导弹 |
| missile_departure_angle | 12 | 度 | 逐枚左右离管偏转角 | 玩家导弹 |
| missile_ignition_at | 0.22 | 秒 | 开始由初速平滑加速的时刻 | 玩家导弹 |
| missile_seek_start | 0.4 | 秒 | 开始转向制导的时刻 | 玩家导弹 |
| missile_cruise_at | 0.65 | 秒 | 到达表设巡航速度的时刻 | 玩家导弹 |
| missile_lifetime | 4.5 | 秒 | 仍锁定目标的飞行寿命上限 | 玩家导弹 |
| missile_brake_range | 120 | 像素 | 接近目标且角差过大时的减速距离 | 玩家导弹 |
| missile_brake_angle | 0.3 | 弧度 | 触发接近减速的角差门槛 | 玩家导弹 |
| missile_min_guided_speed | 60 | 像素/秒 | 近目标制导最低速度 | 玩家导弹 |
| missile_brake_factor | 0.7 | 倍 | 距离×转向速率对应的制导减速系数 | 玩家导弹 |
| missile_hit_radius | 5 | 像素 | 目标到移动线段的命中半径 | 玩家导弹 |
| missile_launch_edge_margin | 55 | 像素 | 边缘发射管向外偏转的保护区 | 玩家导弹 |
| missile_launch_forward_y | -0.12 | 方向向量Y | 偏转方向的朝前门槛；上方为负，范围[-1,0] | 玩家导弹 |
| rail_charge_seconds | 0.9 | 游戏秒 | 玩家磁轨炮周期末段蓄力表现；包含在equipment.cannon.cd内，随合法冷却倍率同比缩放 | 玩家磁轨炮表现 |
| rail_charge_radius | 28 | 显示像素 | 局部炮口蓄力环半径 | 玩家磁轨炮表现 |
| rail_trail_length | 138 | 显示像素 | 磁轨弹头后方短弹道最大长度；不连接整条炮口到目标 | 玩家磁轨炮表现 |
| rail_trail_width | 28 | 显示像素 | 磁轨主炮弹道宽度 | 玩家磁轨炮表现 |
| rail_flash_seconds | 0.09 | 显示秒 | 主炮局部炮口闪光时长 | 玩家磁轨炮表现 |
| rail_impact_seconds | 0.16 | 显示秒 | 主炮局部命中冲击时长 | 玩家磁轨炮表现 |
| rail_impact_radius | 32 | 显示像素 | 主炮命中冲击半径 | 玩家磁轨炮表现 |
| rail_penetration_length | 80 | 显示像素 | 命中处向前的短促视觉冲击长度；不改变命中与连锁 | 玩家磁轨炮表现 |


## 4. 大型内容语义与保留要求

正式主线有220个关卡、10461条敌舰定义、2330条编组定义。level按ID定义长度、战点位置、四种战斗/资源倍率及探索经验；mon保存武器、伤害乘数、HP、盾/抗性/恢复、掉落、尺寸与敌情；monGroup保存稀疏槽位及combatTier。导出保留所有ID与空位，不按当前是否可到达就删数据。

超空间敌人工作表有180条实体及武器安装记录，编队40条、槽位180条、路线编排40条、奖励参考40条；成员分配242行含零预算占位，早段回退预算95行。字段描述内出现旧“223个ID”等文字与实际记录不符，应登记内容说明修订，不以注释数字新增敌人。

`battle_design`40条是候选/验证元数据，base_level、min_upgrade、target_seconds不是运行时给敌人直接加成的参数。生成关卡副本200条不替代正式220关。


## 5. 基线输入指纹

用于审阅确认此次读取对象，不是新的配置权威。

| 工作簿 | SHA-256 |
|---|---|
| ai_tech_tree.xlsx | b70ef7f68e1f1ea241b0b28aa9256382b359fff99ed82968cd9c6436c5ed93df |
| battle_design.xlsx | 78421091f12082cf5ef4a12b7c9f971a2e273d84dddafa5571453b608de1bf1b |
| config.xlsx | b7ef041db8912c64f9c52a7fb0698dd63ac0e5dbc89ab31f0d552fafd6e9b192 |
| crew.xlsx | a3b391374038cb1fb44b72d93ce2461316ee756d41307085865a771b16bcbb1d |
| crew_assignment.xlsx | 1c972db0ddacd785f683cb4bd98bc79d6f4e650035f0f1b6400a02059420d50d |
| crew_config.xlsx | 3f962042b041e8ccf85c2e841fde6fa9fe78c21d7a6536687168c1dc2fe34cef |
| enemy_weapon_base.xlsx | 27bc9c35185e5b5980371f9a05720e825ab3ffe97507a46e5b9e8c0a59f9c259 |
| enhance_config.xlsx | 4b91a1a0cd6311c0eeedf2f61fd37dc113181c4615434f5a03f66a73152f7da5 |
| equipment.xlsx | eaff9aa523a003bc32183d10d9eaf2f131e1feef75307473424144c3c08b697d |
| galaxy.xlsx | 2aa196af0a6f3ef5bb22103d48ea98db31fd880892bd83a30bb50fa3646d7d11 |
| galaxy_build.xlsx | 664c9d1f66e8753dba189c12712df925fb1a50bfc1c06f969b25ed6a0a62d1b6 |
| galaxy_config.xlsx | 199116ae33fda8a8216b0ef3fb02747b107139671cea688c22f1ce65036c5b38 |
| hightech.xlsx | b53e10c4c34cbbb73b0967aedb0e79fdfe83d3fb3357e5e2e4bcf123ba3329b9 |
| hyperspace_config.xlsx | 8c3c04ce59d35991f9261ac57039d003d2e1ac2da121210cc1521c79492104cd |
| hyperspace_enemies.xlsx | 5db22fee0de977835b4101b8689dfbf11f76b2185cde2b359a710f2371a15085 |
| level.xlsx | 202eae560214354c5a78cc2f2d042a7b292fc88b944b9580acb7d560e546f18f |
| level_monGroup_generated.xlsx | b1ed60b126b21999163f7417cb1929dd3b740480aca8bbe2d507e5c7ccf13500 |
| mon.xlsx | 204acd2961cec56282763513415d4bcf14cee40de4ea59e4a852ac3e1cf2040e |
| monGroup.xlsx | 321f2d87798e6a8374f16a47f6f24956fe5d07e58e97cc5078d5e451b0219b6b |
| planet.xlsx | 6a9758c3a6e6173b859811b3a0f46493c8bda4108cfbf30eef590c3745ad5eb8 |
| planet_buff.xlsx | bd0500698de296e0cad32dfc856401e018eada2de95ae9c6ec7bb8e6951d390b |
| planet_build.xlsx | 8e60ba32075c25955a272784f91606795abade6a632a59460ca9dae030d332ce |
| res.xlsx | 6859620d9c46434c2d580567a4bb2a3a5d50daf94a351a51cf446c0430917a61 |
| ship.xlsx | 4ac745dd23c737d110907a44f44755e1f705ede445664cc78771b1df161f7020 |
| unlock.xlsx | ee216e7524e918279a967220c1a205cfd433fe2c9c389c2a7f2a2a35525b2ed7 |
| weapon_motion.xlsx | 7a686c2f8c34e4c584f1e208525be87dc7828f37291e03432d93ffc50fb2fa5c |


## 6. 仓库根旧总表与发布副本核对

`../../../太空战舰.xlsx`是工具`tools/config_workbooks.py`的split动作默认外部总表输入，而正式incremental_import仅接受项目`config_excel`目录。总表SHA-256为`c6d04c796b203a40cc72b5b35ad818d17877f92312dedfcb74a53ccff871e026`。读取其8个sheet并按去除尾部空列/空行的单元格值比较，7个同名表全部与当前正式拆分表不同；不能无条件重新split覆盖main内容。

| 总表sheet | 有效数据行（第4行起） | 与正式根表关系 |
|---|---:|---|
| 总览 | 58（说明条目，非业务行） | split明确排除；历史玩法说明 |
| level | 70 | 不同；正式220关 |
| equipment | 503 | 不同；旧逐级行与unlock字段，正式11条基础定义 |
| mon | 6 | 不同；正式10461条 |
| monGroup | 8 | 不同；正式2330条 |
| res | 2 | 单元格值不同，不能只看行数判等 |
| config | 7 | 不同；正式有效配置38条（空行不计） |
| hightech | 3 | 不同；旧timeCost字段，正式保留4条tpCost字段 |

总览仍写导弹最多3枚且目标不足少发、按关卡距离插值倍率、终点必Boss等旧规则；当前正式Excel与代码已经是4枚发满、按战点序号插值、combatTier与终点分离。本方案从main现行运行输入建立新规则，不把历史总览恢复为新增需求。保留旧总表文件作为原始来源历史，不让它与正式拆分表同时成为权威。现行split还明确排除`crew_level`sheet；本方案不会因schema齐全性重建已删除成长表。

发布副本已经逐字节比较，均与当前正式根表完全相同：

| 发布文件 | 有效行数 | SHA-256 | 与根表 |
|---|---:|---|---|
| published/level.xlsx | 220 | 202eae560214354c5a78cc2f2d042a7b292fc88b944b9580acb7d560e546f18f | 字节一致 |
| published/mon.xlsx | 10461 | 204acd2961cec56282763513415d4bcf14cee40de4ea59e4a852ac3e1cf2040e | 字节一致 |
| published/monGroup.xlsx | 2330 | 321f2d87798e6a8374f16a47f6f24956fe5d07e58e97cc5078d5e451b0219b6b | 字节一致 |
