# 配置来源快照：crew_assignment.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

### crew_assignment.xlsx


**crew_assignment**：5条。字段按原列顺序：

`id`, `targetType`, `effectType`, `baseValue`, `levelScale`, `powerScale`, `interval`, `maxCrew`, `description`, `titleTextId`, `descTextId`, `targetCategory`, `upgradeModes`。


### crew_assignment 数值


**crew_assignment**

| id | targetType | effectType | baseValue | levelScale | powerScale | interval | maxCrew | description | titleTextId | descTextId | targetCategory | upgradeModes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| equipment_upgrade | equipment | AUTO_UPGRADE | 1 | 0 | 0 | 1 | 1 | 每秒尝试升级全部启用的武器和防御模块，正常消耗资源。 | crew.job.equipment | crew.effect.all_equipment | — | 1,10,max |
| hightech_scientists | hightech | AUTO_RESEARCH | 1 | 0 | 0 | 0 | 1 | 研究完成后自动续研剩余时间最短的可用项目；等级提升科研速度。 | crew.job.hightech | crew.effect.research_auto | system | — |
| jewel_auto | jewel | AUTO_COMBINE | 1 | 0 | 0 | 1 | 1 | 每个配置周期尝试购买1级全局装备强化，正常消耗碎片。 | crew.job.jewel | crew.effect.jewel_auto | — | — |
| reactor_upgrade | reactor | AUTO_REACTOR | 1 | 0 | 0 | 1 | 1 | 每1秒尝试升级反应炉1级，并平均分配能源。 | crew.job.reactor | crew.effect.reactor_auto | — | — |
| galaxy_explore | galaxy | EXPLORE | 1 | 0 | 0 | 0 | 6 | 派遣船员探索星系并加速殖民地升级。 | galaxy.assignment | galaxy.assignment_desc | — | — |
