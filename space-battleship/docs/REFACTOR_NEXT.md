# 第六段唯一续接入口（仅交接，尚未开始实施）

远端 main 基线：`d71bd1d26d9d3a5005a891b684de531966fdab1c`，第五段已正常推送并回读确认。

第五段候选 `c524376b40b63b433be6364d76d4fc25003e9874` 已获 dot 与现有 high 一致 PASS。main 过滤交付仅包含 6 个运行文件及 1 个必要既有探针，与已审候选逐文件一致：

- `space-battleship/scripts/battlefield.gd`
- `space-battleship/scripts/fleet_static_descriptors.gd`
- `space-battleship/scripts/hyperspace_drone_visual.gd`
- `space-battleship/scripts/logical_fleet_pose.gd`
- `space-battleship/scripts/presented_ship_view.gd`
- `space-battleship/scripts/simulation_geometry_authority.gd`
- `test/probe_native_admission_stale_pose.gd`

docs/evidence 未进入 main；导入入口及第三段修正仍在。第五段复用已验候选证据：动态炮位 5717/0，生命周期 42/0，挂点 90 样本零失败；非 headless 的正式 `main.tscn` 入口首启 26/0、重开 18/0、领取后重开 7/0，两次恢复 `mismatches=[]`，四张截图已检查。未重复新建验收项目，不声称 `play_main.py` 发布启动器已验证。

## 第六段目标与边界

整组退役历史实验、清理过期测试、收紧现有 `test/run.py` 验收入口和完成标记；不新造测试体系。本入口仅记录下一段工作，不表示已经开始实施。

以下路径均相对仓库根目录。预定删除集合：

- `test/evidence/five-environment-20261015/`，但保留其中 `baseline/`。
- `test/evidence/battle-dps-20261016/`
- `test/evidence/single-slot-20261016/`
- `test/evidence/player-entry-native-20261016/`
- `test/evidence/enemy-intel-hitch-20261016/`
- `test/evidence/enemy-intel-final-perf-20261016/`
- `test/evidence/enemy-intel-time-text-20261016/`
- `test/evidence/stage4-7-evolution-final-20261017/`
- `test/artifacts/`
- `test/capture_approved_first_three.gd`
- `test/test_performance.py`
- `test/phase9_probe.gd`
- `test/test_crew.gd`

预估 980 个文件、27.67 MiB；仅为交接估算，执行时核对实际集合与保留项。一次核对这些集合的外部引用，同步相关 guides 与历史摘要链接。保留当前 DLL/hash、共享 fixtures、当前专项、未解失败证据及其他未确认集合。不得据此扩删其他目录、测试或证据。

## 未解失败与验证

`test_save_boundaries.gd` 的科研恢复复合断言 `Real reopen restores selected research, paid progress and input to its owner` 在既有候选与原基线 `27681c38` 均失败，已知四阶段 write 31/0、reopen 30/1、latest 17/0、recovery 19/0。第五段未重跑或扩修此问题。第六段须定位具体失败项并核对 GrowthNumber 表示，不删除断言；尚未解决时如实保留失败结论和证据，不猜测为测试或游戏缺陷。

执行前先读 AGENTS.md 及对应路由，确认远端 main，保护脏工作区与个人存档，不使用 Library。使用隔离项目及隔离存档，按现有入口复用正式入口与保留专项验证；保留有效断言，不为通过而扩修无关问题。

实际执行沿用 Astra medium，架构与审计沿用 high。提交可读 Git 候选供 dot 与现有 high 双审，须范围一致通过后再按合入闸门交付；main 不纳入无必要的测试、docs 或证据。上下文开始压缩即保存交接并停止。本文件仅在候选分支更新，不进入 main。本轮到此停止，不实施第六段。
