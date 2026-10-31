# 配置来源快照：hyperspace_config.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

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
