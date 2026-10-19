# 舰船预览与战场表现

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 安装座与炮台轴心贴合 | `test_player_mount_seating.gd --headless` 独立按原图安装座核对五档全部15点；静止、左右60度、开火反馈及解除共90次。图形运行设 `MOUNT_SEATING_ONLY` 为舰名、`MOUNT_SEATING_DIR` 为隔离证据目录，输出静止/转向局部对比与安装座、固定底座、旋转轴标记。 |
| 战舰静态预览 | `test_ship_preview.gd --headless` 检查五舰实际模型来源、真实槽位映射、候选/当前/锁定、空槽/无人机/停用、显式启用与局部复用；图形运行捕获五舰和特殊状态。运行隔离工程须包含 `dev`/`addons`，步骤见 [预览资产说明](../../space-battleship/assets/ui/ships/README.md)。 |
| 战场X10舰船画质 | `test_accelerated_ship_quality.gd --headless` 检查高倍画质切换与X1恢复、全部槽位/发射管的规范坐标、持续渲染及暂停/隐藏策略；实际画质与性能须另做可见场景配对。 |
| 战场表现 | `test_weapon_fx.gd`、`test_turret_rotation.gd`、`test_player_visual_scale.gd`、`test_muzzle_visibility.gd`、`test_damage_numbers.gd`、`test_battle_transition_ui.gd`；入场边界复用与位置等价用 `test_enemy_entry_batch.gd`；含长模拟的 `test_portrait_presentation.gd` 仅按 `full` 选择 |

磁轨主炮表现：`test_railgun_presentation.gd` 使用合成配装检查实际基础/强化发射节奏、主命中、激光共存、炮口、暂停与表参数读取；需图形环境。`RAILGUN_RECORD=1` 留存原尺寸 PNG 帧，按每帧 0.1 游戏秒回放；不是实时性能测量。`test_weapon_config_validation.py` 检查八项表现参数的正式 Excel 导出路径。

Static carrier pagination: `python test/run.py test_drone_preview_pages.gd --headless` for logic; graphical run with `DRONE_PREVIEW_EVIDENCE` captures default, last-page and empty states.
