# 换装、成长与属性缓存

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 换装、换舰与成长 | `test_module_refit.gd`、`test_equipment_growth.gd`、`test_bulk_upgrades.gd`；状态归属用 `test_state_ownership.gd`，界面用 `test_module_ui.gd` |
| 属性缓存与失效 | `test_stat_cache.gd --headless` 对照缓存/直接计算的战斗、RNG、换装、升级、星球激活/探索/重铸；仅在隔离用户目录存在存档时读取其副本，否则使用内存夹具。 |
