# 性能测量

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 船员升级测量 | `python test/run.py test_crew_performance.gd --timeout 300`；定位单级热点才用 `test_crew_single_probe.gd` |
| UI/科研渲染测量 | 经 `run.py` 选择 `test_upgrade_ui_probe.gd`、`test_hightech_render_audit.gd` 或 `test_render_budget.gd` |
| 当前整体性能 | `python test/whole_game_perf.py --label <证据名> --rich`；真实 `main.tscn`，隔离工程/用户目录，六页短测。`--ref <commit>` 固定基线，`--headless` 仅 CPU，`--instrument` 仅热点归因，`--max` 检查高余额 MAX 报价，`--realtime --pages 0,8` 检查真实主循环；`--pages 8 --galaxy-steady` 仅让星系表现交通的错峰出发进入稳态，不推进业务逻辑；无图形帧时间不可当实机 FPS。 |
| 当前存档帧耗时 | `python test/saved_game_perf.py --label <证据名>` 复制开发存档及工程，测量已解锁页面；`--snapshot <先前的input-save.json>` 保持前后同一输入，`--fps 60` 验证限帧表现，`--speed 2` 测倍速。`--instrument` 只定位热点，不用于最终帧率比较；`--reuse <该脚本生成的隔离目录>` 复用素材导入。 |
| 第二轮历史保存阶段与尾帧 | 旧异步尾帧候选安装器、专用测量片段和回归已退役，不再保留可误装进当前版本的脚本。当前保存规则用 `test_save_policy.gd`、`test_save_boundaries.gd`；历史实现可从 Git 历史恢复，分析见 [报告](../../space-battleship/PERFORMANCE_OPTIMIZATION_2.md)。 |
| Balance Lab 长模拟/压力 | 按 [性能协议](../../space-battleship/docs/BALANCE_PERFORMANCE.md) 选择场景、夹具与超时；FAST 是玩法模式名，不等于日常 `fast` 层 |

以下不是日常回归清单；仅在相应性能任务、重大重构、明确要求或打包前选用。
