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

## 有限剩余清单

### 阻断第 6 阶段彻底完成及合入 main

1. **剩余玩家设置：** 自动保存间隔与引导自动跳过已独立持久化；01 §5 的音乐/音效、伤害数字模式、页面偏好和清空新档时是否清设置的明确选项尚未接入实际消费者与页面。
2. **页面实际操作验收：** Godot headless 控件信号探针已通过；仍需在真实窗口逐项查看教学/解锁提示、返回、暂停与重铸弹窗的遮挡、焦点和键鼠操作，以及失败保存的可见状态。
3. **配置深层内容审计：** 07 §3 负例矩阵已进入自动化；跨工作簿玩法平衡语义仍需独立审计。尺寸包络目前是保守静态阈值，不等同实际模型多边形碰撞验证。
4. **前阶段完整验收：** 07 §2/§4 的 C01–C12、CR01–CR09 人工 oracle、native/GPU 同源路径及性能记录未全量复核。现有局部 Amount、session 与 headless 探针不能替代这些验收。

### 非阻断仓库整理

1. `data/ui_text.json` 中旧 `level_editor.gd` 是静态文案标签；`src`、`foundation`、`run_game.ps1` 不调用旧游戏内编辑器、`fleet_battle_runner` 或 `balance_sim`。可后续删除文案残留。
2. Godot 在本地系统目录产生的日志/证书警告和 `bin/` native 构建物不入库；无需将它们视作玩法缺项。

## 交接规则

实现从 [唯一入口](README.md) 阅读。状态所有权：业务模型持有长期成长，native 持有战斗暂态与 DropId 水位，`GameSession` 负责候选构建、原子切换和时间补偿，`SaveFiles` 负责文件写入与指针。修复后复用上述 probe，并对新增引导/页面流程与完整 07 验收给出可回读结果；父线程审阅分支后再合 main。
