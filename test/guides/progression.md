# 推进、解锁、时间与入门指引

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 推进、驻守与跃迁 | `test_guard.gd`、`test_loop_retreat.gd`、`test_skip_clear.gd`；末敌清弹用 `test_boss_projectile_clear.gd`，冷却用 `test_travel_cooldowns.gd`，跃迁界面用 `test_warp_ui.gd` |
| 入门指引 | `test_beginner_guide.gd` 检查首次引导、自动完成、关闭不复弹、帮助入口回看及正常存读档；图形运行核对入口和交互 |
| 解锁 | `test_unlock_table.gd` / `test_unlock_ui.gd`；解锁 ID 查找、门槛实时变更、源表替换和有界留存用 `test_unlock_lookup.gd --headless`；页签显隐用 `test_tab_unlocks.gd` |
| 时间、超时空与离线 | `test_time_steps.gd`、`test_offline_resources.gd`；页面用 `test_chrono_ui.gd`，启动结算弹窗用 `test_chrono_login.gd` |

S2 checks: `test_time_steps.gd --headless` covers the current battlefield fixture and retained time. `test_commit_boundary.gd --headless` covers blocked domain/item/substep resumes, snapshot gates, UI-read versus economic invalidation and native pickup qualification. `test_crew_dirty.gd --headless` preserves affordability/long-frame rules and exercises blocked purchase/allocation positions. `test_hyperspace_material_economy.gd --headless` includes zero-time completion/claim retry. Native ownership checks remain in `test_native_blocked_transfer.gd`, `test_native_execution_handoff.gd`, `test_native_galaxy_boundary.gd` and `test_native_galaxy_refit.gd`. Use `test_ordinary_entry.gd` with rendering enabled for the isolated original main-scene save/reopen workflow. Frozen work is retained, not proof of arbitrary interruption recovery; these checks imply no performance guarantee.

Historical diagnostics: `test/test_progression_scene_equivalence.gd`, `test/progression/time_equivalence.gd` and `test/progression/formal_scene_clock.gd` retain pre-domain profile and/or old clock references (`resource_minute_total`, `game_time_remainder`) plus historical QA adapters. They are not current acceptance entries and are not evidence of whole-model equivalence. Their assertions remain as historical investigation material; do not restore retired APIs to run them. Use the current S2 checks above and `test_ordinary_entry.gd` for supported continuation and actual Presented entry behavior. S5's removal claim covers supported runtime consumers and the migrated selected checks, not every historical file in the repository.

Known historical formation expectations remain unsupported: reuse of unchanged combat slots under the old formation policy, and execution of legacy formation snapshots. These failures do not authorize restoring old formation/save compatibility; the current selected checks do not imply that all repository tests pass.
