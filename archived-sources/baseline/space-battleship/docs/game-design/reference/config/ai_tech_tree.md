# 配置来源快照：ai_tech_tree.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

### ai_tech_tree.xlsx


**ai_tech_tree**：8条。字段按原列顺序：

`id`, `name`, `description`, `tier`, `base_seconds`, `growth`, `effect`, `factor`, `unlock`, `requirements`, `legacy_unlock`。


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
