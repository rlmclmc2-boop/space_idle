# 配置来源快照：enhance_config.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

### enhance_config.xlsx


**enhance_config**：68条。字段按原列顺序：

`id`, `value`, `unit`, `des`。


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
