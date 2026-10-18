# 批量战斗与抽样

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 批量战斗 | `test_fleet_battle_runner.gd --headless` 检查交叉配对、seed/JSON 复现、错误续跑、超时/停止、伤害与 HP、四类武器 FAST/EXACT、汇总输出与隔离；`test_enemy_fleet_ui.gd` 覆盖范围选择、执行和局部更新。千场性能属于 full：在已有隔离目录运行该 Godot 脚本并传入 `-- --stress`，保留该目录的 APPDATA/LOCALAPPDATA 隔离设置。 |
| 分层抽样与动态加测 | `test_fleet_battle_sampling.gd --headless` 检查 5000×5000 抽样池的有界候选、去相似、标签覆盖、优先级、各加测理由、稳定停测、手动重点与预算/复现/落盘。三页交互共用 `test_enemy_fleet_ui.gd`，包括重点标记和抽样统计。 |
