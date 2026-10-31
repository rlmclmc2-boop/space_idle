# 09 配置参考索引

[唯一入口](README.md)。规则权威在01–06，已定索引在08；运行参数以 Excel 为准。只查任务涉及的工作簿，不默认通读字段或数值快照。本次未改工作簿、未重新发布配置。

- [覆盖统计与大表内容边界](reference/config-inventory.md)：原09覆盖快照；不是当前全表重新审计。
- [历史目标映射](history/config-migration-targets.md)、[历史指纹/旧总表比较](history/config-fingerprints.md)：仅追溯；表名/数据歧义见[待裁定清单](review/conflicts.md)。
- [当前舰船尺寸统计](reference/ship-scale.md)：有单独提交基线与实际消费链，不能与旧表快照混算。

| 工作簿快照（字段＋小表值） | 主要使用模块 |
|---|---|
| [ai_tech_tree.xlsx](reference/config/ai_tech_tree.md) | 科研 |
| [battle_design.xlsx](reference/config/battle_design.md) | 候选设计元数据 |
| [config.xlsx](reference/config/config.md) | 跨域通用参数 |
| [crew.xlsx](reference/config/crew.md) | 船员 |
| [crew_assignment.xlsx](reference/config/crew_assignment.md) | 船员 |
| [crew_config.xlsx](reference/config/crew_config.md) | 船员 |
| [enemy_weapon_base.xlsx](reference/config/enemy_weapon_base.md) | 战斗 |
| [enhance_config.xlsx](reference/config/enhance_config.md) | 强化 |
| [equipment.xlsx](reference/config/equipment.md) | 装备 |
| [galaxy.xlsx](reference/config/galaxy.md) | 星系 |
| [galaxy_build.xlsx](reference/config/galaxy_build.md) | 星系 |
| [galaxy_config.xlsx](reference/config/galaxy_config.md) | 星系 |
| [hightech.xlsx](reference/config/hightech.md) | 停用旧科研来源 |
| [hyperspace_config.xlsx](reference/config/hyperspace_config.md) | 超空间 |
| [hyperspace_enemies.xlsx](reference/config/hyperspace_enemies.md) | 超空间 |
| [level.xlsx](reference/config/level.md) | 航程 |
| [level_monGroup_generated.xlsx](reference/config/level_monGroup_generated.md) | 生成副本 |
| [mon.xlsx](reference/config/mon.md) | 敌舰 |
| [monGroup.xlsx](reference/config/monGroup.md) | 编组 |
| [planet.xlsx](reference/config/planet.md) | 星球 |
| [planet_buff.xlsx](reference/config/planet_buff.md) | 星球/重铸 |
| [planet_build.xlsx](reference/config/planet_build.md) | 星球 |
| [res.xlsx](reference/config/res.md) | 经济 |
| [ship.xlsx](reference/config/ship.md) | 舰体 |
| [unlock.xlsx](reference/config/unlock.md) | 开放 |
| [weapon_motion.xlsx](reference/config/weapon_motion.md) | 战斗 |

原覆盖总表列有 `battle_geometry.xlsx`、`equipment_evolution.xlsx`、`game_rules.xlsx`，但原字段/小表章节未列其完整内容，本次不伪造补齐；需要这些表时读取当前原表和对应玩法/接口，缺口见裁定清单。
