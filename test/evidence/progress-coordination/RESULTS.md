# 第二段：进度协调闭环

基线 `719e925ac5d65ed7325c09ed7146936288aed22d`；候选 `refactor/progress-coordination`。未合 main。

| 既有用例 | 结果 | 直接覆盖 |
|---|---|---|
| test_crew_dirty.gd | 39 / 0 failures | 接管拒绝、回调后 stale 计划、真实银河旧岗位结算回调、完整加载清旧调度、既有材料唤醒与截止时间 |
| test_ai_tech_tree.gd | 134 / 0 failures | 钱包/科研原子提交、接管回调改变钱包后的拒绝、完成通知见完整状态、值守续研与加载保留手动暂停 |
| test_planet.gd | 684 / 0 failures | 经验接管拒绝无半提交、来源载荷、通知见完整经验与行星状态、重铸保留语义与清旧运行时 |
| test_save_startup_rejection.gd（38387d9e 前版，本次未重跑） | 11 / 0 failures | 正式 main.tscn 启动、坏档拒绝和现行快照恢复；该用例未修改 |

Godot 4.7.2。先用现有 `python test/run.py test_crew_dirty.gd --headless --godot <engine>` 建立并导入隔离副本；后续复用该副本，更新本轮脚本/既有用例，每个用例独立 APPDATA/LOCALAPPDATA，执行 `Godot --headless --path <isolated-project> --script <existing-test>`。四个最终日志随本记录保存；运行进程结束后清理本轮临时副本。可逐项通过相同 run.py 命令复现。

代码证据：Game 中 prepare_crew_commit / notify_crew_changes / commit_planet_command / refresh_crew_level_effects 四个旧函数已删除；其他公开进度命令保留兼容入口，旧提交体已搬入唯一 progress_runtime；crew.continue_research / crew.auto_research 及 planet_crew_payout_active 全部消失。加载和重铸共用 runtime 清理、贡献与调度重建。consume_external_time / _tick_logical_step / advance_shared_clock_and_economy 三个函数体与基线逐字一致。

测试处置：保留三套有独有领域覆盖的既有用例，只补实际边界缺口；不新增测试工程、不重跑所有历史探针。新银河夹具使用既有 refresh_unlocks；经验拒绝夹具使用真实 stage30 收益使升级确需接管，未修改规则迁就断言。

环境仍报告根证书读取警告；科研/行星用例退出有既存对象资源残留（exit 0，无 SCRIPT ERROR）。不将该无关退出清理问题扩展为本段阻断。第三至第六阶段未实施。

## 双审两点修订（基于 38387d9e）

- prepare_crew_commit 只接管与复核；生命只在最后复核通过、提交之前捕获。船员/行星相关提交统一进入 finish_progress_change：所有权威域先提交，再协调容量、一次 configuration_committed、生命应用，最后只读通知。来源载荷和加载/重铸边界保留。
- ai_tech_tree.advance_inputs 提供计划实际使用的有效速度、所需时间与资格；准备使用同一快照计算，原生回调后重取比较。保留科研和钱包 revision 校验，不添加全局戳、重试或事务框架。
- 本次直接重跑原三套用例：39/134/684 全通过。新断言覆盖拒绝无捕获、成功单次捕获、联合经验变更单次配置更新/最终通知状态/生命比例，以及真实 crew.install_snapshot 和 hyperspace.install_snapshot 改变科研速度后拒绝旧工作和旧扣费。启动日志为前版保留，不声称本轮重新执行。
