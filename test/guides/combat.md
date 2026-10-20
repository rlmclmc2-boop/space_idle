# 伤害、弹体与战斗坐标

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 伤害、取整与弹体 | 失锁加速用 `test_missile_orphan_acceleration.gd --headless`（同批五枚加速曲线与离屏），失锁/换波语义用 `test_missile_retarget.gd --headless`；`test_rule_rounding.gd`、`test_target_resistance.gd`、`test_projectile_lifecycle.gd`；命中回调中的删除/重排/清场新增用 `test_projectile_iteration.gd --headless`；持续光束用 `test_long_laser.gd`，溢出/坚韧用 `test_shield_overflow.gd` / `test_tenacity_survival.gd` |
| 武器 Excel / 运动参数 | `test_weapon_config.py` 在隔离源表中逐项调参，经正式增量导出验证玩家/敌方隔离及实际运动；只跑1倍。`SPACE_BATTLESHIP_GODOT` 可指定引擎。 |
| 战场坐标反算 | `test_battle_coordinate_inverse.gd --headless` 对照原20轮反算的精确输出，覆盖线性区边界、非线性区和回退范围。 |

敌方攻击配对模板：`test_enemy_attack_pairs.py` 核对当前配对结构、非法配置拒绝及四源表一致性；`test_enemy_attack_pairs.gd --headless` 验证实际武器类型及真实弹体命中后的能盾/复合装甲响应。小样本战斗不代表新增20组数值验收。
