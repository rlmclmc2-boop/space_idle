# 配置来源快照：hyperspace_enemies.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

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
