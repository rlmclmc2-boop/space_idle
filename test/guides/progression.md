# 推进、解锁、时间与入门指引

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 推进、驻守与跃迁 | `test_guard.gd`、`test_loop_retreat.gd`、`test_skip_clear.gd`；末敌清弹用 `test_boss_projectile_clear.gd`，冷却用 `test_travel_cooldowns.gd`，跃迁界面用 `test_warp_ui.gd` |
| 入门指引 | `test_beginner_guide.gd` 检查首次引导、自动完成、关闭不复弹、帮助入口回看及正常存读档；图形运行核对入口和交互 |
| 解锁 | `test_unlock_table.gd` / `test_unlock_ui.gd`；解锁 ID 查找、门槛实时变更、源表替换和有界留存用 `test_unlock_lookup.gd --headless`；页签显隐用 `test_tab_unlocks.gd` |
| 时间、超时空与离线 | `test_time_steps.gd`、`test_offline_resources.gd`；页面用 `test_chrono_ui.gd`，启动结算弹窗用 `test_chrono_login.gd` |

Known limitation: `test_time_steps.gd` currently fails on both the S1 baseline and delivered implementation: departure geometry assertion, removed `Runtime.detach_requested`, and a nil `screen_mount_for_slot` receiver. It is not passing acceptance evidence. Use `test_commit_boundary.gd --headless` for commit/external-time reentry and `test_ordinary_entry.gd` for the isolated original main-scene workflow; neither claims S2 retained-time correctness.
