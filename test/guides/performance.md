# 性能测量

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 船员升级测量 | Historical fixture (see current-entry note below): `test_crew_performance.gd`；定位单级热点才用 `test_crew_single_probe.gd` |
| UI/科研渲染测量 | 经 `run.py` 选择 `test_upgrade_ui_probe.gd`、`test_hightech_render_audit.gd` 或 `test_render_budget.gd` |
| 当前整体性能 | `python test/whole_game_perf.py --label <证据名> --rich`；真实 `main.tscn`，隔离工程/用户目录，六页短测。`--ref <commit>` 固定基线，`--headless` 仅 CPU，`--instrument` 仅热点归因，`--max` 检查高余额 MAX 报价，`--realtime --pages 0,8` 检查真实主循环；`--pages 8 --galaxy-steady` 仅让星系表现交通的错峰出发进入稳态，不推进业务逻辑；无图形帧时间不可当实机 FPS。 |
| 当前存档帧耗时 | `python test/saved_game_perf.py --label <证据名>` 复制开发存档及工程，测量已解锁页面；`--snapshot <先前的input-save.json>` 保持前后同一输入，`--fps 60` 验证限帧表现，`--speed 2` 测倍速。`--instrument` 只定位热点，不用于最终帧率比较；`--reuse <该脚本生成的隔离目录>` 复用素材导入。 |
| 第二轮历史保存阶段与尾帧 | 旧异步尾帧候选安装器、专用测量片段和回归已退役，不再保留可误装进当前版本的脚本。当前保存规则用 `test_save_policy.gd`、`test_save_boundaries.gd`；历史实现可从 Git 历史恢复，分析见 [报告](../../space-battleship/PERFORMANCE_OPTIMIZATION_2.md)。 |
| Balance Lab 长模拟/压力 | 按 [性能协议](../../space-battleship/docs/BALANCE_PERFORMANCE.md) 选择场景、夹具与超时；FAST 是玩法模式名，不等于日常 `fast` 层 |

以下不是日常回归清单；仅在相应性能任务、重大重构、明确要求或打包前选用。

## Current architecture comparison entries

- Pages and native residency: `python test/whole_game_perf.py --label <name> --godot <verified-engine> --headless --frames 300`; add `--rich`, and `--pages 0 --enemies 15` for the existing dense case. `--ref <commit>` selects historical production bytes. Reuse is permitted only for identical source/config fingerprints. Compare work_before/work_after, measured steps, native_frames and RNG before CPU time. Report UI setup separately; headless timing is not rendered FPS.
- Growth batch: `BALANCE_PERF_SECONDS=30` (environment variable), then `python test/run.py test_balance_performance.gd --godot <verified-engine> --headless`. Uses the actual Runner; prints setup and run/report cost separately with completed work. No substituted game or old scientist fields.
- Small F9 batch: `FLEET_PERF_TOTAL=6` and `FLEET_PERF_CANDIDATES=8`, then `python test/run.py test_fleet_battle_speed.gd --godot <verified-engine> --headless`. Both frame budgets must complete identical six-result work; wall time includes frame yields, CPU time does not.
- Historical `test_crew_performance.gd`, `test_crew_single_probe.gd` and `test_balance_research_performance.gd` still contain pre-domain positive fixtures and are not current acceptance commands. For scheduling correctness use the current progression guide's dirty/commit-boundary checks. Do not restore retired fields to make diagnostic fixtures pass.

Timing comparisons require the same engine, native binary, business configuration, seeds, accepted logical work and final outputs. A historical model change that produces different work is explicitly non-comparable; it does not authorize changing production behavior or claiming a speedup. These diagnostic runs are selected for the task, not added to every regression run.
