# stage4-crew-bindings — 候选交接

基准：27681c3807d3569fbdb41435952c1a9fc0822db8；分支 codex/refactor-stage4。
范围：第四段岗位绑定同源、初始化调度分离；不合 main；候选已推送，无配置/个人存档改动。

## 实现与设计决策
- crew_system.binding_targets/binding_valid 为默认岗位、运行指令、严格快照提供同一目标、支持效果、类别和容量规则。加载仅用 db，不查询当前 Game 活跃状态；锁定/暂停目标仍可合法恢复。
- 保留成员完整性、重复/未知成员、数值、槽位、模式、未知岗位等严格拒绝；没有自动补全。
- reset 清调度但不启动；Game 的所有增长域初始化后调用现有 progress_runtime.rebuild_schedule；加载仍走原有全域安装后的调度点。
- 同目标类型+目标 ID 的多个岗位共同占容量；所有占用岗位上限同时约束总人数，运行与加载均无数组顺序依赖。这是本次同源收敛的明确决策。
- 定向核对 data/game_data.json crew_assignment：equipment_upgrade/equipment=1、hightech_scientists/hightech=1、jewel_auto/jewel=1、reactor_upgrade/reactor=1、galaxy_explore/galaxy=6。每个类型只有一个岗位，不存在共占但上限不同实例，现有合法行为不变。差异配置仅存在回归测试内。
- 新船员、星球、同类建筑定义的初始化/严格快照回归使用内存夹具；Game 无新增逐 ID 分支。

## 验证证据
命令（仓库根）：`python test/run.py <test_crew_dirty.gd|test_planet.gd|test_save_boundaries.gd> --headless --godot ../godot/Godot_v4.7.2-stable_win64.exe`。
存档对照命令：`python test/work/stage4-save-compare.py`；原探针四阶段命令为 `Godot --headless --path <isolated-project> --script <isolated-test>/test_save_boundaries.gd -- <write|reopen|latest|recovery>`。对照仅替换两个修改的运行脚本为 `git show 27681c3:space-battleship/scripts/<name>`，另置隔离 userdata/baseline；断言保持原样。
引擎：Godot 4.7.2；通过 test/run.py，独立项目、APPDATA/LOCALAPPDATA/XDG 目录；未使用玩家存档。
- test_crew_dirty.gd：59 checks，0 failures（原断言保留，追加13项）。
- test_planet.gd：688 checks，0 failures（原断言保留，追加4项）。
- test_save_boundaries.gd 未修改：write 31/0、reopen 30/1、latest 17/0、recovery 19/0。
- 基准27681c3在另一独立 userdata 上重跑四阶段，结果完全相同；唯一失败均为 `Real reopen restores selected research, paid progress and input to its owner`。该失败已在原基线复现，证实非本段新增；根因尚未定位，不能据此判定属于测试缺陷还是游戏缺陷，本段不扩修。
- 首次新增 galaxy provider 错用 RefCounted.get 默认参数已修复为复用 galaxy.targets(g)，最终 crew 零失败；未修改断言规避。
- 日志：test/work/stage4-evidence/；存档复现项目：test/work/test_save_boundaries-2g4vuov2/（含 candidate 与 baseline 各阶段日志及隔离存档）。对照脚本：test/work/stage4-save-compare.py。
- Godot 输出根证书读取提示及 crew/planet 退出资源占用提示；无最终 SCRIPT ERROR。存档四阶段结果按实际失败报告，不宣称全绿。

交接：实现完成，等待父线程 dot 与既有 Astra high 双审；科研恢复断言失败根因未定位，为剩余验证限制。

## 审计日志补交
最终现存日志原样提交于 [stage4-evidence](stage4-evidence/)：crew.log、planet.log，以及候选 test-* 和基线 baseline-* 的 write/reopen/latest/recovery 四阶段日志，共10份。本次仅复制现存最终日志，未重跑测试；未提交导入日志、隔离存档或缓存。候选与基线 reopen 均命中同一科研恢复失败，原因仍待定位。
