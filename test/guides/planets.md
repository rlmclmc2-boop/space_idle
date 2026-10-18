# 星球探索、建筑与重铸

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 星球加成弹窗 / 自动探索默认 | `test_planet_dialog_layout.gd` 检查分组、数值对齐、详情、四设施操作、六星球隔离、长文案、大数及隐藏/暂停；`test_planet_bonus_dialog.gd` 检查本星球已生效加成、倍率实时更新、真实点击、默认开启和手动关闭存读档 |
| 星球探索 / 建筑 / 重铸 | `test_planet_conquest_progress.gd`（征服共享经验、配置起始关、历史倍率、解锁提示记忆及旧档迁移）/ `test_planet.gd` / `test_planet_buildings.gd`（迁移、适用规则、自动探索、重铸、大数）/ `test_planet_ui.gd`；新增天体配置、独立存档、真实点击与五种动态外观用 `test_planet_celestials.gd`；球面自转与隐藏暂停用 `test_planet_rotation.gd`（20 秒图形检查）；永久奖励用 `test_planet_buffs.gd` / `test_planet_buff_ui.gd`；配置导入用 `test_planet_build_config.py` ；Blender 模型合并、材质/面数预算、动画节点与透明图标用 `test_orbital_blender_assets.gd`；探索日志、共享三维绘制与自转用 `test_planet_orbit_acceptance.gd` |

星球表面可读性：`test_celestial_rotation_readability.gd` 在实际主界面逐颗检查球体内部纹理位移、完整一周接缝、暂停与隐藏恢复；需图形环境。`PLANET_ROTATION_RECORD=1` 输出每颗 12 游戏秒、10 fps 的原尺寸帧，供逐个回放；不作为实时性能基准。
