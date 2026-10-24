# Balance Lab 与独立模拟工具

| 修改范围 / 目的 | 按需入口 |
|---|---|
| Balance Lab | 按变化选 `test_balance_v2.gd`、`test_balance_database.gd`、`test_balance_lab_ui.gd`；模拟及 FAST 专项先查 [实验说明](../../space-battleship/docs/BALANCE_LAB.md) 与 [性能协议](../../space-battleship/docs/BALANCE_PERFORMANCE.md) |
| 独立战斗模拟工具 | 仓库根执行 `python space-battleship/tools/build_result_analyzer.py --output test/work/battle-lab-standalone --engine <Godot路径>`，输出必须为新的空目录；脚本闭包从 [入口映射](../../space-battleship/tools/supported_entrypoints.json) 推导，动态资源仍显式校验。`python test/run.py test_analyzer_dependencies.py` 检查静态依赖拒绝边界。构建已隔离导入；运行时 APPDATA/LOCALAPPDATA 指向包内 `.build-user/roaming`、`.build-user/local`。包内 `runtime/analyzer.exe --headless --path 包目录 --script 测试绝对路径` 可运行 `test_battle_lab_standalone.gd` 验证当前敌舰群、自动关卡、周期关卡入口。当前窗口没有批量战斗/分析页；相关组件专项不作为这些页面仍可用的证明。 |
| 战斗模拟速度 | 在独立包中运行 `test_fleet_battle_speed.gd`（需窗口），用相同 100 场分别测 8 ms 和独立工具的帧预算；打印墙钟时间/帧数并核对逐场结果。`test_fleet_battle_runner.gd` 检查无科研批次与原路径的结果/RNG 一致。 |

Current acceptance boundary: `test_balance_database.gd` covers current captured inputs, numeric/report admission and batch identity; select the progression guide's owner/commit checks for shared growth behavior. `test_balance_metrics.gd` still has pre-domain gem/reactor/profile mutations in its earlier combat fixture despite a newer Research section, so its full historical file is not a current pass claim. Do not restore removed gem/scientist APIs to run it. Other historical probes must be checked against the changed consumer before selection; this guide does not declare the whole directory green.

For a bounded speed observation, use `FLEET_PERF_TOTAL=6` and `FLEET_PERF_CANDIDATES=2` with `test_fleet_battle_speed.gd`; this selects the existing runner regression's first-enemy, one/two-ship, level-10 input family. Full default generation remains a separate larger workload. Setup, execution CPU and frame-yield wall time are separate measurements.
