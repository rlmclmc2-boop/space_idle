# 配置来源快照：galaxy_config.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

### galaxy_config.xlsx


**galaxy_config**：13条。字段按原列顺序：

`key`, `value`, `type`, `des`。


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
