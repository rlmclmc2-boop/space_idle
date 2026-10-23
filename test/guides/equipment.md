# 换装、成长与属性缓存

S1 commit pilot: `python test/run.py test_commit_boundary.gd --headless` checks joint wallet/equipment installation, immutable results/notices, scheduler-before-UI order, stale proposals and nested commands. Pair with `test_native_numeric_upgrade.gd --headless` for the actual native fast path; the boundary fixture's fake session alone is not native-kernel evidence.

The boundary fixture also checks external-time reentry before fees/save/presentation and ordinary paid-progress notification cadence.

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 换装、换舰与成长 | `test_module_refit.gd`、`test_equipment_growth.gd`、`test_bulk_upgrades.gd`；状态归属用 `test_state_ownership.gd`，界面用 `test_module_ui.gd` |
| 属性缓存与失效 | `test_stat_cache.gd --headless` 对照缓存/直接计算的战斗、RNG、换装、升级、星球激活/探索/重铸；仅在隔离用户目录存在存档时读取其副本，否则使用内存夹具。 |

`test_state_ownership.gd --headless` 使用当前领域快照/API 验证读取纯度、稳定只读视图、重复槽位/冷却、换舰、护盾、当前快照往返与空槽；不承担旧档连续性验收。旧 `profile.resources/loadout` 不是夹具写入口。该测试通过不代表同表其他历史专项已迁移或通过。
