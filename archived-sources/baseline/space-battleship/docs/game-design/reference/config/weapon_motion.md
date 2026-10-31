# 配置来源快照：weapon_motion.xlsx

[唯一入口](../../README.md) → [配置索引](../../09-config-catalog.md)。来自拆分基线 `7a85481` 的原09（混合历史快照，非本轮工作簿重采样）；表值/字段不是当前玩法权威，现行值仍从对应 Excel 消费，规则见入口所指正文。

### weapon_motion.xlsx


**weapon_motion**：29条。字段按原列顺序：

`id`, `value`, `unit`, `description`, `scope`。


### weapon_motion 数值


**weapon_motion**

| id | value | unit | description | scope |
|---|---|---|---|---|
| player_projectile_pixels_per_unit | 28 | 像素/单位 | 玩家普通弹体与导弹巡航速度的单位换算 | 玩家 |
| enemy_projectile_pixels_per_unit | 28 | 像素/单位 | 敌方普通弹体速度单位换算；与玩家参数独立 | 敌方 |
| player_cannon_speed_multiplier | 1 | 倍 | 玩家火炮表para1速度再乘此倍率；敌方不乘 | 玩家火炮 |
| chain_carrier_speed | 720 | 像素/秒 | 到达后结算的玩家连锁载体速度 | 玩家连锁 |
| missile_ejection_gap | 0.12 | 秒 | 同批逐枚离管间隔 | 玩家导弹 |
| missile_launch_speed | 240 | 像素/秒 | 离管初速；巡航速度来自equipment.missile.para2 | 玩家导弹 |
| missile_turn_rate | 4 | 弧度/秒 | 制导最大转角速度 | 玩家导弹 |
| missile_orphan_lifetime | 30 | 秒 | 失锁直飞安全上限；通常先正常离屏 | 玩家导弹 |
| missile_reacquire_interval | 0.12 | 秒 | 尚未离管的无效目标重选缓存间隔；飞行弹体不重锁 | 玩家导弹 |
| missile_departure_angle | 12 | 度 | 逐枚左右离管偏转角 | 玩家导弹 |
| missile_ignition_at | 0.22 | 秒 | 开始由初速平滑加速的时刻 | 玩家导弹 |
| missile_seek_start | 0.4 | 秒 | 开始转向制导的时刻 | 玩家导弹 |
| missile_cruise_at | 0.65 | 秒 | 到达表设巡航速度的时刻 | 玩家导弹 |
| missile_lifetime | 4.5 | 秒 | 仍锁定目标的飞行寿命上限 | 玩家导弹 |
| missile_brake_range | 120 | 像素 | 接近目标且角差过大时的减速距离 | 玩家导弹 |
| missile_brake_angle | 0.3 | 弧度 | 触发接近减速的角差门槛 | 玩家导弹 |
| missile_min_guided_speed | 60 | 像素/秒 | 近目标制导最低速度 | 玩家导弹 |
| missile_brake_factor | 0.7 | 倍 | 距离×转向速率对应的制导减速系数 | 玩家导弹 |
| missile_hit_radius | 5 | 像素 | 目标到移动线段的命中半径 | 玩家导弹 |
| missile_launch_edge_margin | 55 | 像素 | 边缘发射管向外偏转的保护区 | 玩家导弹 |
| missile_launch_forward_y | -0.12 | 方向向量Y | 偏转方向的朝前门槛；上方为负，范围[-1,0] | 玩家导弹 |
| rail_charge_seconds | 0.9 | 游戏秒 | 玩家磁轨炮周期末段蓄力表现；包含在equipment.cannon.cd内，随合法冷却倍率同比缩放 | 玩家磁轨炮表现 |
| rail_charge_radius | 28 | 显示像素 | 局部炮口蓄力环半径 | 玩家磁轨炮表现 |
| rail_trail_length | 138 | 显示像素 | 磁轨弹头后方短弹道最大长度；不连接整条炮口到目标 | 玩家磁轨炮表现 |
| rail_trail_width | 28 | 显示像素 | 磁轨主炮弹道宽度 | 玩家磁轨炮表现 |
| rail_flash_seconds | 0.09 | 显示秒 | 主炮局部炮口闪光时长 | 玩家磁轨炮表现 |
| rail_impact_seconds | 0.16 | 显示秒 | 主炮局部命中冲击时长 | 玩家磁轨炮表现 |
| rail_impact_radius | 32 | 显示像素 | 主炮命中冲击半径 | 玩家磁轨炮表现 |
| rail_penetration_length | 80 | 显示像素 | 命中处向前的短促视觉冲击长度；不改变命中与连锁 | 玩家磁轨炮表现 |
