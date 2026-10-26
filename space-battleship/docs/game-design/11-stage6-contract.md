# 第 6 阶段现状与收尾契约

本页是当前实现与验收状态。玩法规范仍以 [唯一入口](README.md) 所链的 01–09 为准。本页不把探针通过等同于完整玩法验收。`bin/`、生成的 `config.json`、Godot 导入缓存和本机扩展均为本地测试产物。

## 已实现及可复用验证

| 项目 | 当前实现 | 已有验证 |
|---|---|---|
| 保存 S01/S02 | `SaveFiles` 异步写入、generation/dirty、读回 hash、写入/flush/替换/关闭错误；`GameSession` 和成长页面显示持久化失败。 | `_save_files_probe.gd`、`_stage6_session_probe.gd`、`_stage6_page_probe.gd`。flush、关闭超时和替换失败均有故障注入路径。 |
| 候选 S03/S04 | 文件 checksum 与 Envelope/schema、各模块状态、Amount、native DropId 水位校验；恢复/导入候选先建立新会话，拒绝后仍用旧会话。 | `_stage6_session_probe.gd`、`_stage6_page_probe.gd`。对坏候选、导入及替换失败进行拒绝/保留检查。 |
| S05/S06 | native 战斗 checkpoint、历史/actor/DropId 水位和未领取结果恢复；加载与导入使用同一离线补偿，时钟回拨取 0，最长 12 小时，只结算一次。 | `_stage6_checkpoint_probe.gd`、`_stage6_session_probe.gd`；已覆盖同一 savedUtc 的加载/导入、回拨及上限。 |
| 页面 | 保存目录/文件选择、导入预览与确认、重铸预览与取消、暂停/继续、成长面板返回战斗、通知具体条目已读及自动保存间隔设置。 | `_stage6_page_probe.gd` 验证已有控件信号；新增返回按钮需在本提交后复跑。真实视觉与键鼠操作仍待验收。 |
| 配置发布 | `config_tools/production_manifest.json` 固定 29 本根工作簿、49 张表的 schema，`compile.py` 对字段、主键、缓存、引用、概率、编队、路线和预算等做发布前校验；成功才原子替换 runtime JSON。`foundation/import_excel.py` 与 `run_game.ps1` 走同一编译器并生成完整校验报告。 | 对真实消费表全量编译通过；`config_tools/test_publish.py` 用真实表副本注入重复主键、外键缺失、公式缓存缺失、编队越界、路线顺序缺口和未知规则键，均验证旧 active JSON 字节不变及报告定位。 |

## 有限剩余清单

### 阻断第 6 阶段彻底完成及合入 main

1. **引导与返回流程：** 01 §5 要求首次装备、升级、拾取、撤退按实际命令/事件记录进展，奖励入账后才显示通关提示。目前无持久化教学状态，也未完成返回主游戏各页面的人工操作验收。新增的成长面板返回按钮仅关闭面板，不能代替完整引导。
2. **配置发布负例全集：** 当前编译器覆盖了关键结构和六类真实表故障，但 07 §3 列出的跨表/公式平衡、所有概率与预算缺失/压缩、编队碰撞、传说现值与历史值区间、独立测试清单与正式清单错用等负例尚无完整运行证据。生产发布前须补足并确认不会误接纳错误数据。
3. **前阶段完整验收：** 07 §2/§4 的 C01–C12、CR01–CR09 人工 oracle、native/GPU 同源路径及性能记录未全量复核。现有局部 Amount、session 与 headless 探针不能替代这些验收。

### 非阻断仓库整理

1. `data/ui_text.json` 中旧 `level_editor.gd` 是静态文案标签；`src`、`foundation`、`run_game.ps1` 不调用旧游戏内编辑器、`fleet_battle_runner` 或 `balance_sim`。可后续删除文案残留。
2. Godot 在本地系统目录产生的日志/证书警告和 `bin/` native 构建物不入库；无需将它们视作玩法缺项。

## 交接规则

实现从 [唯一入口](README.md) 阅读。状态所有权：业务模型持有长期成长，native 持有战斗暂态与 DropId 水位，`GameSession` 负责候选构建、原子切换和时间补偿，`SaveFiles` 负责文件写入与指针。修复后复用上述 probe，并对新增引导/页面流程与完整 07 验收给出可回读结果；父线程审阅分支后再合 main。
