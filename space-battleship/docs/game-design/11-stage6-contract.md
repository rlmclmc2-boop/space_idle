# 第 6 阶段现状与收尾契约

本页是当前实现与验收状态。玩法规范仍以 [唯一入口](README.md) 所链的 01–09 为准。本页不把探针通过等同于完整玩法验收。`bin/`、生成的 `config.json`、Godot 导入缓存和本机扩展均为本地测试产物。

## 已实现及可复用验证

| 项目 | 当前实现 | 已有验证 |
|---|---|---|
| 保存 S01/S02 | `SaveFiles` 异步写入、generation/dirty、读回 hash、写入/flush/替换/关闭错误；`GameSession` 和成长页面显示持久化失败。 | `_save_files_probe.gd`、`_stage6_session_probe.gd`、`_stage6_page_probe.gd`。flush、关闭超时和替换失败均有故障注入路径。 |
| 候选 S03/S04 | 文件 checksum 与 Envelope/schema、各模块状态、Amount、native DropId 水位校验；传说无人机参数须落在当前或历史兼容区间。恢复/导入候选先建立新会话，拒绝后仍用旧会话。 | `_stage6_session_probe.gd`、`_stage6_page_probe.gd`。对坏候选、传说参数越界、导入及替换失败进行拒绝/保留检查。 |
| S05/S06 | native 战斗 checkpoint、历史/actor/DropId 水位和未领取结果恢复；加载与导入使用同一离线补偿，时钟回拨取 0，最长 12 小时，只结算一次。 | `_stage6_checkpoint_probe.gd`、`_stage6_session_probe.gd`；已覆盖同一 savedUtc 的加载/导入、回拨及上限。 |
| 引导、通知与页面 | 成功换装、付费升级、真实拾取、撤退转换和奖励结算后的通关才推进持久化引导。教学和解锁提示分别持有暂停原因；关闭只释放自身原因。自动跳过设置与玩法存档分离，跳过弹窗仍保留通知未读。页面有保存/导入/重铸、暂停/继续、成长面板返回战斗和自动保存间隔控件。 | `_stage6_page_probe.gd` 验证失败动作不推进引导、成功动作/设置/提示按钮/用户暂停保留/存档恢复；`_stage6_session_probe.gd` 验证撤退、通关结算顺序与坏引导候选拒绝。真实视觉与键鼠操作仍待验收。 |
| 配置发布 | `config_tools/production_manifest.json` 固定 29 本根工作簿、49 张表的 schema；正式/测试清单双向隔离。`compile.py` 验证字段、主键、缓存、引用、公式结果、显式及敌舰掉落表达式概率、尺寸包络、路线和预算；成功才原子替换 runtime JSON。`foundation/import_excel.py` 与 `run_game.ps1` 走同一编译器并生成完整报告。 | 正式消费表全量编译通过；`config_tools/test_publish.py` 的独立测试清单和真实表副本覆盖 07 §3 的结构、范围、依赖、预算及清单错用负例，核验旧 active JSON 字节不变、稳定错误码与报告定位；内容计数为 29 本、49 表、220 关、40 条路线编排。 |

## Stage 6 current acceptance and finite remaining work

The save/candidate/rollback behaviors in the table above remain verified by the existing Stage 6 probes. Player settings now persist separately from gameplay: tutorial skip, music, effects, damage numbers (all/critical/off), autosave interval, and preferred battle/growth page. New game has preview and explicit keep/reset settings choice. Failed settings publication is visible. Native hit receipts carry actual Amount damage and are capped to 64 presentation records per advance; drawing and sound do not affect combat settlement.

New verification: the pinned native build succeeded. `_stage6_settings_probe.gd` covered invalid settings, live controls, page preference, preview retaining the old session, keep settings, and explicit reset. `_stage6_page_probe.gd` still passed against the rebuilt native DLL. `_stage6_gpu_window_probe.gd` exercised 600 real OpenGL frames on NVIDIA RTX 2060, pause/continue and growth/return buttons, native GPU presentation, receipt-backed damage numbers and off mode; measured 10.89 s wall time, 136.57 ms peak process monitor, 35 peak draw calls, three peak visible damage labels, three peak flights, 0.0167 s peak pending game time. A screenshot was inspected locally. `_stage6_dense_perf_probe.gd` used the existing 15-slot group 33011 at 10x for 600 headless frames: 84 game seconds, 1.154 ms average frame work, 11.047 ms peak, 22 peak flights, 0.0167 s peak pending time. These are short-run measurements, not full acceptance budgets.

### Blocking before main review/merge

1. Run the complete 07 section 2 and 4 C01-C12 / CR01-CR09 manual oracle, including same-kernel headless versus GPU settlement comparison. Current targeted probes do not establish that entire matrix.
2. Run and record the full 07 section 4 performance matrix: 15-slot group plus maximum equipped slots/drones, sustained burst/chain/beam, 10x long run, full warehouse, and very large MAX. Record native queue peaks, allocations, GPU drawing time and pending game time. The short probes above cover only part of this matrix.
3. Complete operator-driven visual acceptance of the live window's tutorial, notification, file picker, failure status, and reforge flows. Automated headless controls and a real-renderer scripted window probe passed; the desktop automation interface did not expose the launched Godot window for manual clicking.

### Nonblocking follow-up

1. Deep balance and playfeel tuning for the 0-10000 growth curve is separate from implementation correctness and needs its own measured proposal and gameplay decision; current config publication validity is already verified.
2. The `data/ui_text.json` reference to `level_editor.gd` is a static help label. There is no active editor entry in `src`, `foundation`, or `run_game.ps1`.
3. Godot's local log/certificate/cache warnings and `bin/` extension are environment or local build outputs; they are not authored gameplay behavior.
## 交接规则

实现从 [唯一入口](README.md) 阅读。状态所有权：业务模型持有长期成长，native 持有战斗暂态与 DropId 水位，`GameSession` 负责候选构建、原子切换和时间补偿，`SaveFiles` 负责文件写入与指针。修复后复用上述 probe，并对新增引导/页面流程与完整 07 验收给出可回读结果；父线程审阅分支后再合 main。
