# 配置来源快照：planet_build.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

### planet_build.xlsx


**planet_build**：5条。字段按原列顺序：

`id`, `name`, `des`, `min_planet`, `planet_rule`, `planet_value`, `order`, `unlock_explore`, `build_explore`, `extra_crew`, `type`, `config1`, `config2`, `previous_id`。


### planet_build 数值


**planet_build**

| id | name | des | min_planet | planet_rule | planet_value | order | unlock_explore | build_explore | extra_crew | type | config1 | config2 | previous_id |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| station | 空间站 | 建成后可开启自动探索。 | 1 | all | — | 1 | 1 | 1 | 0 | auto_explore | 0 | 0 | — |
| refinery | 资源精炼厂 | 提升铁与铀直接掉落，多个星球效果相乘。 | 1 | all | — | 2 | 20 | 5 | 0 | refinery | 0.01 | 0.35 | — |
| workshop | 装备工坊 | 提升装备系统普通数值，多个星球效果相乘。 | 1 | all | — | 3 | 50 | 10 | 0 | equipment | 0.01 | 0.4 | — |
| shipyard | 新式船坞 | 点「分配施工船员」开工；建好后领取船坞，再决定是否重铸。重铸前会显示保留内容和本轮重置范围。 | 1 | only | 1 | 4 | 30 | 180 | 1 | shipyard | 0 | 0 | — |
| shipyard_later | 新式船坞 | 点「分配施工船员」开工；建好后领取船坞，再决定是否重铸。重铸前会显示保留内容和本轮重置范围。 | 1 | exclude | 1 | 4 | 150 | 10 | 1 | shipyard | 0 | 0 | shipyard |
