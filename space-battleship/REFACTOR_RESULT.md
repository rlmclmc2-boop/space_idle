# CHECKPOINT 9 / REFACTOR_RESULT

**REFACTOR COMPLETE**

HISTORY ONLY / NOT AUTHORITATIVE / DO NOT READ BY DEFAULT

本文件是本轮重构最终验收记录，不是日常任务前置上下文。现行规则与问题仍由五份权威文档维护。日期：2026-09-16。

## FREEZE / 验收范围

- 最初重构基线：7f4d704。
- Phase 13开始 HEAD：7d3a197b95c2a3fe6ba989483722d85d475338ac；工作树干净。
- 冻结9份运行GDScript、4份Python工具、12份正式输入、5份权威文档，共30份 SHA-256；[冻结证据](../test/work/refactor-phase13/freeze.json)。
- 最终12份正式输入与 Phase 1全部一致：UNCHANGED，无需列 AUTHORIZED_CHANGE。源码和工具亦与阶段开始一致；权威文档仅 STATUS 获准收尾变化。[最终哈希](../test/work/refactor-phase13/final-hashes.json)。
- 正式玩家目录未读取、未修改、未复制为夹具。所有游戏/配置/存档验证使用复制项目与新建隔离 userdata。之前各阶段记录也明确使用隔离档，本次未打开正式档去“验证未改”。
- 本阶段只验证、汇总、STATUS收尾及历史标记；未改生产代码、正式配置、现有测试或引擎位置。

## BEFORE

- 装备槽位等级与名称 levels 持续同步；首同名武器还读取名称冷却，存在两套运行来源。
- 属性、装备列表、充能、科技排序、收入峰值读取混有隐式写入。
- 存在重复装备集合、空槽构造、恒定UI文本刷新、无实际必要的转发与 Window 生命周期依赖。
- 科学家 MAX 按钮的布尔刷新重复枚举购买量，LARGE_VALUE 有已测热点。
- 历史综合测试混合旧假设；AI文档重复、状态流水账长，规则定位依赖大量背景。

## AFTER

- 保持 Godot/GDScript 主干、现有 main/game/database 与已有职责模块；没有机械拆分或大规模目录搬迁。
- 等级与玩家冷却按槽位读取；旧档在加载边界迁移，保存边界派生兼容字段。
- 读取保持纯度，归一化与状态提交收敛到创建、加载和明确写入边界。
- 关卡编辑器直接调用 config_panel 的静态 find_python；不创建临时 Window。
- 配置工具保持原实现和不同入口语义；性能只保留已测的科学家 MAX 布尔判定简化。
- 五份权威文档及专项测试路由成立；重构计划仅保留历史审计身份。

## REMOVED

- 运行时 profile.levels、名称冷却同步读写及 sync_legacy_level。
- 无消费者的 select_research 转发、恒定 hightech_button_text 与重复赋值、旧 research 事件处理分支。
- level_editor 为定位 Python 创建/释放 config_panel Window 的过程。
- 三份失去现行职责的旧科技测试：test_hightech、test_hightech_continuous、test_hightech_progress。
- 历史综合测试中已迁移且重复的现行断言，以及经确认过时的固定数值/炮口假设；其余历史职责留存 U-017。
- 12份旧AI说明：DATA、GAME_DESIGN、INVENTORY、TODO、VALIDATION及7份modules说明。人类操作、美术、资产与测试导航文档保留。
- 没有删除生产模块或运行入口；文件数量不是本轮强制缩减目标。

## MERGED

- BULK_EQUIPMENT 与 EQUIPMENT 合并为既有唯一集合。
- default_loadout 复用 empty_loadout 的空槽构造。
- 装备等级/冷却消费者收敛到槽位来源，UI按钮保留槽位定位元数据。
- 独有有效文档事实按职责归入五份权威文件；历史和重复内容不进入默认上下文。
- incremental / Store / full 的转换、校验或事务没有被强制合并；A12保持现状。

## STATE

| 状态 | 最终所有者 / 边界 |
|---|---|
| 装备等级 | profile.loadout[category][slot].level |
| 玩家冷却 | BattleGame.cooldowns 的 weapons_<index> 槽位键；不持久化 |
| 旧 levels | raw 输入迁移和 saved 兼容派生；不装回运行 profile |
| 资源余额 | profile.resources |
| 充能 | profile.charge；credit为预付未耗量，不是余额副本 |
| 科技/科学家 | profile 的对应等级、人数、分配、点数及排序字段 |
| 当前生命/护盾 | game.player；容量从装备及效果派生 |
| 草稿 | main.ship_candidate_loadout；确认经 switch_ship 提交 |
| 实体/统计 | game的敌人、弹体、掉落与收入样本；run_resources是累计，furnaceIncomePeak是历史峰值 |

13项静态结构检查通过，并以1,114项状态专项复核动态边界。没有新 Manager/Service/Repository/Framework/EventBus/CacheManager、通用Schema/DSL、额外状态同步层或性能跨帧缓存。

普通读取不调用 ensure_loadout，不创建charge job，不提交科技排序或收入峰值。ensure_loadout调用仅留加载与重建解锁边界。[结构核对](../test/work/refactor-phase13/architecture-check.json)。

相对最初基线，U-016首槽卸下后剩余冷却错误属于此前单独获准的修复；读取纯化是已批准的API行为收敛。不能将其描述为所有接口行为绝对零变化。本阶段未发现新的未授权行为差异。

## PERFORMANCE

原 Phase 9 探针逐字节一致；同一Godot 4.7.2、OpenGL Compatibility、RTX 2060及610.88驱动。配置/源码与 Phase 9 after 哈希一致。仍为30帧预热、120帧采样、1X/2X/5X；三轮raw及三轮instrumented均退出0。未与其他游戏测试并行。

下表单位ms，每格为 median / P95；分别取三次独立运行对应统计的中位数，不是挑最快一次或把三次样本合并计算P95。

| LARGE_VALUE | 指标 | Phase9 before | Phase9 after | 最终 after |
|---|---|---:|---:|---:|
| 1X | raw frame | 12.058 / 14.309 | 7.878 / 9.319 | 7.675 / 9.844 |
| 1X | raw main CPU | 7.550 / 9.129 | 3.311 / 3.905 | 3.262 / 4.130 |
| 1X | scientist refresh（插桩） | 5.711 / 6.141 | 0.173 / 0.217 | 0.188 / 0.275 |
| 2X | raw frame | 12.098 / 13.916 | 7.896 / 9.961 | 7.605 / 8.657 |
| 2X | raw main CPU | 7.587 / 8.686 | 3.290 / 3.885 | 3.265 / 3.633 |
| 2X | scientist refresh（插桩） | 5.687 / 6.679 | 0.173 / 0.209 | 0.187 / 0.287 |
| 5X | raw frame | 12.188 / 14.163 | 7.616 / 8.765 | 7.950 / 10.228 |
| 5X | raw main CPU | 7.754 / 8.926 | 3.305 / 3.548 | 3.462 / 4.469 |
| 5X | scientist refresh（插桩） | 5.685 / 7.720 | 0.175 / 0.215 | 0.180 / 0.237 |

每120帧的 scientist_MAX 枚举调用：原120次 → Phase9 after 0次 → 最终0次；scientist_purchase总调用仍为360次，避免将“MAX枚举消失”误报为“所有费用查询消失”。实际购买算法未改，1,009项等价/纯度/UI即时状态检查通过。

三次原始数值与波动范围见[性能比较](../test/work/refactor-phase13/performance-comparison.json)，全部场景结果见[本次测量](../test/work/phase9-phase13-final-e4p5hexz/results.json)。后台/桌面负载未完全受控，最终P95有波动，不报告新的提升百分比。已有优化仍有效；装备MAX刷新与build_ui/U-021保持未解决。

## TEST

**40个当前有效专项文件全部退出0，无新核心回归。** 包含35个核心/装备UI专项，加配置矩阵、编辑器Python/GDScript、QA与完整重启。没有修改现有测试或正确断言，没有要求历史test_game全绿。

- 覆盖取整、状态/读取纯度、装备退款与限制、槽位冷却、换舰、战斗/弹体、时间步进、收入/资源/炉、充能、科学家、大数、存档/离线、页签/拖拽与视觉坐标。
- 关键结果：取整18、状态1,114、时间63、存档16、科学家MAX1,009、装备页282、原生拖拽32、玩家视觉167、敌舰24、敌武器位置192项通过。
- 40文件逐项退出码及副本位置：[test-results.json](../test/work/refactor-phase13/test-results.json)。日志均在同一验收目录。
- 已知根证书读取提示、QA子窗口提示不属于新规则断言失败；日志保留。
- 临时GUI探针首轮失败因事件没有进入菜单处理路径。只调整临时探针为 Input.parse_input_event 分发后，原有10项检查全部通过。首次及诊断日志保留；没有修复或修改生产实现，不隐藏这一过程。

## COMPAT

version仍为1；以下均由隔离夹具实测：

- 缺loadout、旧levels、同名多槽、矛盾首槽优先、缺/非法字段、显式空槽。
- 保存派生首槽兼容level，其他同名槽等级保留；运行profile不重新建立levels。
- 重复加载、保存再重开、离线收益不重复；加载顺序保持资源→充能→研究→保存→玩家。
- 冷却不持久化；首槽卸下不覆盖剩余同名槽冷却。
- 临时文件替换和故障事件；QA删除后旧场景不复活存档。
- 不将open/rename故障覆盖描述为所有断电/磁盘损坏场景安全；U-008仍在。

## CONFIG

当前分表复制后可读取；矩阵实测172项输入结果、18项故障结果、212项断言通过。Store单元8项、编辑器18项、QA14项通过。

无变化不写JSON、单表只改对应投影、Store读/校验/保存/重载、ROUND与Decimal/float边界、公式/XML缓存、ZIP内容、manifest/fingerprint、源/目标hash、备份与现有回滚行为均按专项验证。

- U-018：旧总表缺当前字段，拒绝是现状，不猜默认值。
- U-019：回滚自身失败可能半提交且备份可能被清理，仍非完全安全事务。
- U-020：增量未最终复核target/manifest，仍有并发覆盖风险；Store边界不同。
- 源码Python工具相对7f4d704零diff；不同入口的接受范围、错误时机、路径和事务模型未统一。
- [本轮输入/故障矩阵](../test/work/test_config_input_matrix-_uscekks/phase8-matrix/INPUT_MATRIX.md)。故障观察通过不代表问题已解决。

## UI

实际运行图形渲染，逐张查看本轮截图，并区分GUI输入与直接调用。没有以专项通过代替没有看过的截图。

| 区域 | 本轮证据与状态 |
|---|---|
| 普通启动/主界面 | 复制项目按默认入口启动退出0；主界面截图 VISUAL VERIFIED |
| 武器/防御页 | 满装备两页截图与282项布局/操作检查；VISUAL VERIFIED |
| 换舰 | GUI选择→重建→Escape取消菜单→重新选当前舰→选择目标→确认，共10项通过；草稿与确认后截图 VISUAL VERIFIED |
| 科学家/科技/充能 | 暂停、研究、按钮与充能状态截图 VISUAL VERIFIED；即时按钮状态另有专项 |
| 页签解锁 | 首科技解锁/隐藏页画面 VISUAL VERIFIED；重锁/回退由专项保护 |
| 拖拽/滚动 | SubViewport注入真实Godot GUI鼠标事件，拖拽预览、换位、取消、边缘滚动与留空截图 VISUAL VERIFIED |
| 确认弹窗 | 卸下弹窗截图 VISUAL VERIFIED；取消/确认状态由专项保护 |
| 伤害文字 | 多次独立命中文字截图 VISUAL VERIFIED，边界不重叠断言通过 |
| 舰船/炮口 | 玩家两种舰与槽位画面 VISUAL VERIFIED；炮口/发射位置由坐标专项保护 |
| 编辑器/QA | 编队、关卡编辑及QA窗口截图 VISUAL VERIFIED |

换舰没有另造“取消按钮”：取消菜单和重新选择当前舰均不得提交草稿；确认后才切换正式槽位。空槽确认继续保留空槽。

本次GUI输入属于引擎输入分发与图形检查，未用人工物理鼠标逐个控件点验；全设备/多显示器/跨平台交互为 NOT FULLY VERIFIED，不宣称完成这些额外范围。

[GUI输入日志](../test/work/refactor-phase13/ui-input.log)、[截图索引](../test/work/refactor-phase13/visual-review.json)。

## QA / 启动链

普通启动、Godot导入、关卡编辑器、QA配置读取、同进程场景重启、独立进程完整重启均通过。完整重启实测新PID、更新源码生效、同一隔离保存目录及进度/QA设置保留。

find_python静态调用覆盖有效环境路径、无效/空环境回退及PATH命令回退。没有移动引擎或用户目录；U-010跨平台发布仍未解决。

## AI_PROTOCOL

五份权威文档仍为 AGENTS、PROJECT、ARCHITECTURE、STATUS、DECISIONS。L0只有AGENTS+STATUS；按任务读L1，再搜索并最小读取源码/专项。Handoff仅DONE/CHANGED/VERIFY/NEXT，存在时才加BLOCKERS/DECISION。

STATUS仅更新完成状态、当前能力和后续任务，16个有效U-ID保留。23个权威/测试导航本地链接检查通过；资源、换舰、配置三条路由仍成立，未重做完整Phase12模拟。

REFACTOR_PLAN原地保留，顶部已明确 HISTORY ONLY / NOT AUTHORITATIVE / DO NOT READ BY DEFAULT；不移动旧链接、不丢历史证据、不进入默认上下文。CHECKPOINT_8同样仅作验收证据。

## TOKEN

| 文档 | 最终 lines | 最终 bytes |
|---|---:|---:|
| AGENTS.md | 30 | 2,790 |
| docs/PROJECT.md | 65 | 9,299 |
| docs/ARCHITECTURE.md | 70 | 7,181 |
| docs/STATUS.md | 39 | 3,281 |
| docs/DECISIONS.md | 15 | 2,809 |

- 最初7f4d704的L0：207 lines / 37,171 bytes（Git blob原始UTF-8，含其换行）。
- Phase11压缩前的L0：228 lines / 41,604 bytes（当时工作树口径）。
- 最终L0：69 lines / 6,071 bytes；比Phase12的6,076 bytes未膨胀。历史Git和工作树可能有LF/CRLF差异，未伪造精确Token。
- Phase12实际任务正文：A 8 files / 267 lines / 19,975 bytes；B 9 / 461 / 29,555；C含补核8 / 753 / 45,940。源码+测试分别3/4/4文件。
- 任务成本不等于默认成本；搜索摘要另计，不能把字节变化直接称为Token降幅。C首次遗漏跨入口复核的记录保留。
- [最终文档检查](../test/work/refactor-phase13/document-final.json)、[Phase12完整证据](../test/work/refactor-phase12/CHECKPOINT_8.md)。

## FILES

相对7f4d704；行数含空行/注释，不是覆盖率或复杂度的替代指标。测试含runner/临时性能探针的跟踪源码；排除test/work。AI文档含根转向入口，排除人类文档和本次历史审计报告。

| 分类 | files before→after | lines before→after | ADDED | REMOVED | NET |
|---|---:|---:|---:|---:|---:|
| GDScript | 9→9 | 3684→3653 | +58 | −89 | -31 |
| Python tools | 4→4 | 954→954 | +0 | −0 | 0 |
| Entrypoints/scenes | 6→6 | 94→94 | +0 | −0 | 0 |
| Tests | 51→57 | 3914→4834 | +1421 | −501 | +920 |
| AI docs | 18→6 | 1084→222 | +201 | −1063 | -862 |

PRODUCTION_FILES_BEFORE / AFTER：19 / 19。PRODUCTION_LINES_BEFORE / AFTER：4,732 / 4,701；ADDED 58、REMOVED 89、NET −31。生产口径为GDScript+Python工具+入口/场景，不把测试增长解释为生产复杂度增长。

测试新增9文件、删除3文件，净+6；增长用于独立规则边界和验证工具。AI文档减少12文件，最终6包含五份权威文档及根转向入口。本阶段现有运行/工具/测试源码零变更，仅STATUS、历史计划标记和本结果文件收尾；临时验收产物在test/work。

完整[分类统计](../test/work/refactor-phase13/diff-metrics.json)和[生产diff](../test/work/refactor-phase13/production.diff)。

## KNOWN_ISSUES

保持有效：U-001、U-004、U-005、U-006、U-007、U-008、U-009、U-010、U-011、U-012、U-013、U-017、U-018、U-019、U-020、U-021。

当前问题描述以[STATUS](docs/STATUS.md)为权威。U-017继续明确历史test_game不是整套规则基线；U-018/019/020的失败现状不被测试绿色掩盖；U-021仍是未处理的重建热点。

## RISKS

- 完整存档故障恢复、坏档/并发实例及配置回滚/并发安全仍有限制。
- 部分规则/来源歧义等待策划裁决；没有用代码事实代替授权。
- 本机图形与有限夹具不证明跨平台、所有输入设备、真实成长平衡或长期压力都已验收。
- 性能有桌面负载波动；保留优化不等于消除所有热点。
- 原始日志/截图保存在忽略的test/work；清理前应保留需要的审计证据。此报告与历史计划不成为默认AI上下文。

## NEXT / CLOSE

后续真正值得独立立项：配置事务/并发安全（U-019/U-020）、旧总表来源及缺字段裁决（U-018）、存档故障边界（U-008）、跨平台发布（U-010），以及有实际需求后再评估既有性能热点（U-021等）。

本轮 VERIFY → REPORT → CLOSE 完成。没有开始Phase14、第二轮重构、新功能、性能优化或未决问题修复。

## 最终专项索引

每项退出0；实际副本路径及日志见test-results.json。本表不包含历史综合测试。

| 测试文件 | 结果 |
|---|---|
| test_rule_rounding.gd | PASS |
| test_state_ownership.gd | PASS |
| test_bulk_upgrades.gd | PASS |
| test_equipment_limits.gd | PASS |
| test_ship_equipment_limit.gd | PASS |
| test_unequip.gd | PASS |
| test_ships.gd | PASS |
| test_ship_tab.gd | PASS |
| test_target_resistance.gd | PASS |
| test_boss_projectile_clear.gd | PASS |
| test_final_encounter.gd | PASS |
| test_travel_cooldowns.gd | PASS |
| test_guard.gd | PASS |
| test_loop_retreat.gd | PASS |
| test_skip_clear.gd | PASS |
| test_auto_gen_resources.gd | PASS |
| test_furnace_income.gd | PASS |
| test_resource_display.gd | PASS |
| test_offline_resources.gd | PASS |
| test_charge.gd | PASS |
| test_charge_growth.gd | PASS |
| test_scientists.gd | PASS |
| test_scientist_affordability.gd | PASS |
| test_large_numbers.gd | PASS |
| test_delete_save.gd | PASS |
| test_tab_unlocks.gd | PASS |
| test_hightech_slots.gd | PASS |
| test_damage_text.gd | PASS |
| test_ship_visuals.gd | PASS |
| test_enemy_ship_visuals.gd | PASS |
| test_enemy_weapon_positions.gd | PASS |
| test_projectile_lifecycle.gd | PASS |
| test_time_steps.gd | PASS |
| test_save_boundaries.gd | PASS |
| test_config_input_matrix.py | PASS |
| test_level_editor.py | PASS |
| test_level_editor.gd | PASS |
| test_config_panel.gd | PASS |
| test_full_restart.py | PASS |
| test_equipment_tabs.gd | PASS |
