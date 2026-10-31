# 配置覆盖与内容边界快照

[唯一入口](../README.md) → [配置索引](../09-config-catalog.md)。保留原09的覆盖统计；它不等于本轮重新盘点当前 Excel。

## 1. 覆盖总表

项目`config_excel`根目录现有 **29个工作簿、49个工作表**，其中`level_monGroup_generated.xlsx`为1个生成副本；其余28个为源工作簿、48个工作表。`published`另有3个发布副本；合计32个xlsx文件。记录数按各表第4行起的非空数据行统计。

| 工作簿 | 工作表 | 有效记录数 | 类别 |
|---|---|---|---|
| ai_tech_tree.xlsx | ai_tech_tree | 8 | 正式内容 |
| battle_design.xlsx | battle_design | 40 | 候选设计元数据；不自动进入主线 |
| battle_geometry.xlsx | battle_geometry | 32 | 正式内容 |
| config.xlsx | config | 38 | 正式内容 |
| crew.xlsx | crew | 20 | 正式内容 |
| crew_assignment.xlsx | crew_assignment | 5 | 正式内容 |
| crew_config.xlsx | crew_config | 12 | 正式内容 |
| enemy_weapon_base.xlsx | enemy_weapon_base | 4 | 正式内容 |
| enhance_config.xlsx | enhance_config | 68 | 正式内容 |
| equipment.xlsx | equipment | 11 | 正式内容 |
| equipment_evolution.xlsx | equipment_evolution | 8 | 正式内容 |
| galaxy.xlsx | galaxy | 1 | 正式内容 |
| galaxy_build.xlsx | galaxy_build | 6 | 正式内容 |
| galaxy_config.xlsx | galaxy_config | 13 | 正式内容 |
| game_rules.xlsx | game_rules | 19 | 正式内容 |
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

## 4. 大型内容语义与保留要求

正式主线有220个关卡、10461条敌舰定义、2330条编组定义。level按ID定义长度、战点位置、四种战斗/资源倍率及探索经验；mon保存武器、伤害乘数、HP、盾/抗性/恢复、掉落、尺寸与敌情；monGroup保存稀疏槽位及combatTier。导出保留所有ID与空位，不按当前是否可到达就删数据。

超空间敌人工作表有180条实体及武器安装记录，编队40条、槽位180条、路线编排40条、奖励参考40条；成员分配242行含零预算占位，早段回退预算95行。字段描述内出现旧“223个ID”等文字与实际记录不符，应登记内容说明修订，不以注释数字新增敌人。

`battle_design`40条是候选/验证元数据，base_level、min_upgrade、target_seconds不是运行时给敌人直接加成的参数。生成关卡副本200条不替代正式220关。
