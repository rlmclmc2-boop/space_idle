# Balance Lab 与独立模拟工具

| 修改范围 / 目的 | 按需入口 |
|---|---|
| Balance Lab | 按变化选 `test_balance_metrics.gd`、`test_balance_v2.gd`、`test_balance_database.gd`、`test_balance_lab_ui.gd`；模拟及 FAST 专项先查 [实验说明](../../space-battleship/docs/BALANCE_LAB.md) 与 [性能协议](../../space-battleship/docs/BALANCE_PERFORMANCE.md) |
| 独立战斗模拟工具 | 用 `tools/build_result_analyzer.py --output ../test/work/battle-lab-standalone` 构建隔离包；APPDATA/LOCALAPPDATA 指向包内 `.build-user/roaming`、`.build-user/local`。用包内 `runtime/analyzer.exe --path 包目录 --script 测试绝对路径` 运行 `test_fleet_battle_runner.gd --headless` 验证原规则，`test_fleet_level_generator.gd --headless` 验证初筛、私有成长补测和原关卡结构，再运行 `test_battle_lab_standalone.gd` 验证五页生成→战斗→分析→自动关卡。 |
| 战斗模拟速度 | 在独立包中运行 `test_fleet_battle_speed.gd`（需窗口），用相同 100 场分别测 8 ms 和独立工具的帧预算；打印墙钟时间/帧数并核对逐场结果。`test_fleet_battle_runner.gd` 检查无科研批次与原路径的结果/RNG 一致。 |
