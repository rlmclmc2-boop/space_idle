# 原09目标Excel迁移映射（历史记录）

[唯一入口](../README.md)。以下为拆分基线原文，不能自动作为当前待执行迁移命令；规则权威在01–06/08，字段目标与现行表名差异见[待裁定清单](../review/conflicts.md)。

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
