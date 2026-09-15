# 太空战舰：项目审计与分阶段重构方案

日期：2026-09-15。审计基线：工作区 Git HEAD `7f4d704`；审计开始时工作树干净。

## 0. 本轮范围与结论

- **GOAL**：依据用户提供的《太空战舰项目：AI 重构总指令》，建立架构地图、风险清单和可逐步验收的方案。
- **SCOPE**：只读检查入口、目录、关键源码、直接依赖、测试源码及现有文档；仅新增本文件。
- **DO_NOT_TOUCH**：游戏及工具代码、测试代码、Excel、运行 JSON、存档、缓存、引擎、其他文档。本轮不执行重构、不迁移数据、不运行游戏或配置导入。
- **DONE_WHEN**：本方案完成并检查，停止，等待用户确认。
- 用户本轮“完成方案后停止”的限制优先于总指令中“然后再开始修改”；总指令的目标文档结构属于后续实施，不在本轮提前调整 AGENTS/STATUS/TODO。

**结论：保留 Godot + GDScript + Excel → JSON 主干。优先清理已核实的历史负担，消除装备状态双向同步及读取副作用，再简化依赖，最后按测量结果优化。没有全项目重写、ECS、服务层或通用配置框架的必要。**

证据性质：下文的代码行为是 CURRENT，不自动等于策划批准。性能均为静态热点候选，没有本轮基准测试结果；没有声称全部测试通过或全部死代码已确认。原表未展开读取，未做数值平衡或投影一致性审计；已编辑分表不能被旧总表覆盖。已有规则争议沿用 [TODO](docs/TODO.md) 的 U-001、U-004～U-013，不能借重构自行裁决。

## 1. 当前架构地图

路径均相对 `space-battleship/`，`../test/` 是工作区测试目录。物理行数含空行，只用于衡量阅读规模。

```text
../启动.cmd → Godot 资源导入 → project.godot → main.tscn
                                                    ↓
                                             scripts/main.gd
                                             ├─ ShipDatabase
                                             │    └─ data/game_data.json
                                             ├─ BattleGame(db)
                                             │    ├─ profile / 战斗运行状态
                                             │    └─ user://progress.json
                                             ├─ 绘制 / 输入 / 音效 / 游戏 UI
                                             └─ QATools（根级独立 Window）
                                                  └─ config_panel.gd
                                                       ├─ Python 配置 CLI
                                                       ├─ 同进程场景重载
                                                       └─ restart_host.gd → 新进程

原始总表 --显式拆分同步--> config_excel/*.xlsx
                                ├─ config_workbooks.py → 增量投影
                                └─ level_editor_store.py → 编辑事务
                                        ↑                       ↓
关卡编辑器.cmd → level_editor.tscn → level_editor.gd       game_data.json

import_workbook.py：共用行转换/校验 + 显式全表 CLI
inspect_knowledge.py：只读来源审计/公式缓存检查
test/run.py：复制项目到 test/work，隔离存档后运行单项测试
```

### 1.1 核心职责、入口与依赖

| 区域 | 当前入口 / 规模 | 职责与边界 |
|---|---|---|
| 主循环 | `scripts/main.gd`，1159 行；`_process` | `delta` 上限 0.1，乘倍速，以不大于 1/60 秒的步长调用 `game.tick`；同时更新 UI/动画/绘制 |
| 模拟与进度 | `scripts/game.gd`，1561 行 | 战斗、经济、充能、科学家、舰船、关卡、存档集中在 BattleGame；长但不是多层框架 |
| 数据访问 | `scripts/database.gd`，55 行 | JSON 字典引用；装备按等级查行、上限扫描、敌武器字段回退、关卡倍率插值 |
| 舰船 | `game.gd` 的 loadout/equip/upgrade/switch 系列 | 武器和防御按槽位实例维护；换舰退款/重置；防御键实际拼作 `defence`，不可顺手改存档键 |
| 战斗与 NPC | `tick / targets / fire / hit_* / tick_projectiles` | 敌群字典、冷却与弹体；NPC 为自动开火/目标逻辑，无独立 AI 服务或行为树 |
| 资源与成长 | `collect / advance_auto_gen / advance_furnace / advance_charge / advance_hightech` | 多种生产和入账路径，顺序及取整具有规则意义 |
| 绘制与交互 | `main.gd` 的 build/draw/refresh；`hightech_slot.gd` 46 行 | UI 节点、页签、拖拽、确认弹窗、伤害数字；槽位脚本承担真实 Godot 拖放回调 |
| 公共小模块 | `number_format.gd` 42 行；`ship_visuals.gd` 29 行 | 数量格式化；共享舰船坐标及炮口几何，分别被模拟/UI复用 |
| QA | `config_panel.gd` 357 行；`restart_host.gd` 32 行 | 异步导入、暂停/倍速、删除存档、两种重启；辅助进程不是可去掉的转发层 |
| 关卡编辑器 | `level_editor.gd` 403 行；`level_editor_store.py` 220 行 | 草稿 UI、引用检查、源表/JSON/指纹提交与回滚 |
| 配置工具 | `config_workbooks.py` 279 行；`import_workbook.py` 287 行 | OOXML 拆分、指纹、原子批量写入；转换和大部分校验已经复用 |
| 审计工具 | `inspect_knowledge.py` 168 行 | 局部查表或完整审计；不能用旧总表差异强制修复新分表 |
| 构建与依赖 | `.cmd / project.godot / *.tscn` | Godot；Python/openpyxl/lxml；Windows 相对布局；未见导出预设和 CI 配置 |
| 协作入口 | 根 `../AGENTS.md` → 项目 `AGENTS.md` | 现有规则由项目入口拥有；本轮没有改写协议 |

源码范围为 9 个 GDScript 文件、4 个 Python 工具文件。未扫描 `.godot/`、`.runtime/`、`.userdata/`、`test/work/` 的内容，也未读取引擎二进制。

### 1.2 状态所有权和时间流

| 信息 | 当前所有者 / 派生关系 | 重构约束 |
|---|---|---|
| 配置数值 | 可编辑分表 → JSON 投影 → db 引用 | 总表是显式同步输入；不要求两处编辑自动一致；JSON不是另一套手工平衡表 |
| 装备等级 | `profile.loadout` + `profile.levels` | **存在可写双源**：`sync_legacy_level` 将旧 levels 写回第一个同名槽位；升级/安装/卸下又回写 levels |
| 玩家冷却 | `cooldowns[slot_id]` + `cooldowns[key]` | 第一个同名武器兼容旧名称键；tick 优先读旧名称键，测试也直接写它 |
| 资源 | `profile.resources` | `run_resources` 是本局收入，不是余额副本；不能合并掉 |
| 收入窗口 | `game.resource_samples` | `main.resource_samples` 是 getter 引用，不是第二份数组；存档样本、offlineRates 是持久化快照 |
| 炼铁炉基数 | `profile.furnaceIncomePeak` | 非自身收入历史峰值，不能换成当前滚动值 |
| 充能 | `profile.charge` | level/count/elapsed/active/started/credit；credit 是已付未用量，不是重复余额 |
| 科学家 | scientists/assignments/techPoints/hightechLevels | 总人数、分配、点数、等级含义不同；空闲人数由分配推导 |
| 解锁 | cleared → highestLevel/unlocked | 后两项可重建，但存档/旧调用依赖必须先核实 |
| 战斗实体 | player/enemies/projectiles/drops | 弹体 target 持有实体字典引用；不能随意改成复制值或重建实体 |
| 驻守 | 运行时 guard_* + profile.guard* | 运行进度与保存恢复位置不同；不要按同名判断重复 |
| UI 草稿 | ship_candidate_loadout | 未确认换舰的用户选择，必须独立于正式装备 |
| UI 控件缓存 | 按钮/卡片字典 | 节点引用，非游戏数值源；重建需释放并清理引用 |

当前时间顺序：在线 `main._process → tick`，暂停直接阻断 tick；tick 先自动资源，再充能及扣费保存，再高科技/炼铁炉，再战斗与状态推进。收入窗口和存档时间使用系统现实时间，成长/战斗多使用模拟时间。加载先恢复字段并结算离线资源，再推进离线充能，再推进高科技，最后保存。不得改成一个统一计时器或调整顺序来“整理代码”。

### 1.3 事件与依赖审计

- `BattleGame.event(kind,payload)` 同步通知 `main.on_event`；UI部分使用 deferred 重建，部分操作立即重建。未发现需要另建事件总线的理由。
- `main._ready` 连接当前 game 的事件一次；按钮信号跟随新节点建立，旧 UI 被移除。没有确认重复监听缺陷；同轮多次安排 `build_ui` 是另一类重复工作候选。
- 脚本静态依赖未见导入循环。运行时存在 `main → QA → current_scene.game` 回调关系，有实际控制用途，不等于需要 service 层。
- `level_editor.run_action` 为取得 Python 路径临时实例化 `config_panel.gd` Window，随后 free；这是可明确缩短的无必要实例中间层。
- `game → ship_visuals` 同时影响炮口和命中时间，属于实际共享几何。不要为“逻辑纯净”复制坐标到战斗代码。

## 2. 问题与处置清单

DELETE 均指后续候选；删除前必须复核符号、字符串调用、信号、场景、CLI、测试和用户当前用途。没有引用不等于已证明无用。优先级遵循第 5 节阶段顺序。

| 编号 | 类型、证据与定位 | 建议 | 行为风险 / 决策依据 |
|---|---|---|---|
| A01 | `game.gd:7–8` EQUIPMENT 与 BULK_EQUIPMENT 内容完全相同 | MERGE | 共用现有清单；保留五类装备全部支持批量升级，不机械合并UI排序 |
| A02 | `default_loadout` 与 `empty_loadout` 重复创建槽位数组 | MERGE | 默认安装在 empty_loadout 结果上执行；每次新建独立字典，禁止共享可变数组 |
| A03 | `game.gd:279–308` 读取 loadout 时反复 normalize，stat/weapon_entries 还触发旧等级写回 | SIMPLIFY + OPTIMIZE | 读取隐式写入和替换数组，已存在高理解成本；改动前先锁定旧接口语义和字典引用行为 |
| A04 | 名称升级 API 转槽位 API；`profile.levels` / loadout、cooldowns 双键 | MERGE + SIMPLIFY | 测试直接写旧字段，存档迁移实际使用 levels；不能一次删除整个兼容层 |
| A05 | `main._process` 用带下划线的字符串判断新旧按钮键、嵌套条件分派 | SIMPLIFY | 建钮时保存明确的槽位标识；先验证旧键是否只剩测试使用，不新增控制器 |
| A06 | `main.hightech_button_text` 恒为 +1，`select_research` 实际分配科学家；`on_event` 仍有 research 分支 | SIMPLIFY / 条件 DELETE | 前两项仍有调用，不能标死代码；旧 research 发射在当前源码未找到，复核后删除旧分支 |
| A07 | `State.LEVEL_SELECT` 未找到当前调用；MAIN_MENU有初始化/测试，UPGRADE/DEFEAT及leave有测试引用 | 条件 DELETE；其余 KEEP至完成迁移 | 删除枚举会改变后续枚举整数，必须保持活动值或确认全部消费者；沿用 U-011 |
| A08 | `import_workbook.DEFAULTS.deathRetreatDistance` 与 JSON同字段；实际后退用 config.backRange | 条件 DELETE | [map](docs/modules/map.md) 已说明停用；先证明无消费者，再停止生成，最后处理投影保留字段。不得顺手改有效 backRange |
| A09 | 三份旧高科技测试仍调用不存在的 research/hightechResearch；test/README 明确它们不再验收新版 | 条件 DELETE | `test_hightech.gd / test_hightech_continuous.gd / test_hightech_progress.gd` 的现行有效断言先迁到科学家专项；依赖更新后删除，历史归Git |
| A10 | `test/legacy` 探针、`--capture` 分支、截图脚本 | 逐项核实；默认 KEEP | 截图/人工验收仍有用途；不能因 debug、legacy 命名批量删除 |
| A11 | 两处 AST/Decimal/ROUND 公式求值：Store.workbook_bytes 与 inspect_knowledge.audit | MERGE候选，低优先级 | 支持范围不一致：一处支持正负号/大小写ROUND及float中转，另一处保留Decimal递归；不能直接替换成同一算法造成审计/写表变化 |
| A12 | 增量导入与 Store.__init__ 分表发现/路径规则重复且不一致 | SIMPLIFY + MERGE | 增量对charge/ship均有可选发现，Store只特殊处理charge；先建输入行为矩阵，共用发现逻辑不等于自动扩大/收紧合法输入 |
| A13 | Store.prepare 额外做敌机武器/资源/ID校验，通用导入覆盖不同 | KEEP边界，评估MERGE | U-007。可共享相同检查，但新增拒绝行为属于校验规则变化，应独立确认 |
| A14 | level_editor实例化QA窗口仅调用find_python | SIMPLIFY | 首选现有函数改静态并直接调用；不新增PythonService/Helper文件；查找优先级保持不变 |
| A15 | database.data 与 equipment/config 等属性指向同一数据 | KEEP | 主要是引用别名，非重复手工配置；已有测试直接更改db，缓存必须适配 |
| A16 | 源表原字段 res/monGroup 和派生 drops/groups 同存投影 | KEEP，后续只查消费者 | 是原字段/运行解析结果；删除可能破坏审计、编辑器、兼容，不视为已确认冗余 |
| A17 | number_format、ship_visuals、hightech_slot、restart_host | KEEP | 已解决真实复用或生命周期问题，合并会增加耦合；未发现多余manager/service层 |
| A18 | `main.draw_ship` 程序几何fallback；敌方武器回退；旧高科技/旧装备存档迁移 | KEEP | 当前代码仍有入口或兼容责任；未建立旧档淘汰协议前禁止删除 |
| A19 | `main.build_ui` 清空整棵UI，多个事件可能重复安排重建；每帧检查全部按钮/描述 | OPTIMIZE | 测量后先合并同帧重建，再减少稳定结果计算；必须保留拖拽延迟、页签、弹窗、滚动和即时可点击状态 |
| A20 | game/database重复扫描、分配数组；MAX科学家逐个累计，UI每帧调用 | OPTIMIZE | 见热点表。先局部复用，后考虑受控缓存；不能改取整换公式以求快 |
| A21 | `STATUS.md` 34375字节、`VALIDATION.md` 56582字节；运行JSON 369513字节 | SIMPLIFY | 默认读长状态和整份投影消耗大；字节不是精确Token。历史归Git、数据按键读取 |
| A22 | ARCHITECTURE称不结算离线收益；INVENTORY仍有旧盘符/资产描述；TODO含未发现Git/固定20级等旧事实 | MERGE + SIMPLIFY | 与源码及本轮Git事实不符，可能误导AI重写已完成功能；先追溯，再压缩到目标五份AI文档 |
| A23 | 太长文件内混合职责；短行里包含多次变更/复合条件；字符串事件/字典字段跨函数隐式约定 | SIMPLIFY | 优先明确函数名、同文件局部整理、写清少量WHY约束；不能按行数拆成十几个文件 |

目前没有证据支持删除整份运行模块、资源目录或存档格式，也未确认事件监听泄漏。敌方导弹未在当前编队引用的历史记录（U-011）不构成删除配置依据：需查当前分表/编辑器选项后决定。

## 3. 性能热点：先测量，后选择

| 候选 | 静态证据 / 工作量来源 | 首选低复杂度措施 | 不允许牺牲的行为 |
|---|---|---|---|
| 高频loadout归一化 | tick/绘制/升级按钮多次进入 ensure_loadout，新数组替换；first_weapon_index反复调用weapon_entries | 先唯一状态源；归一化移到加载与写入边界，单次操作读取一次 | 旧档规范化、空槽、同名装备独立等级与冷却 |
| 装备查询 | database.equip线性查行，max_equipment_level反复全表扫描 | 先复用同调用结果；测量仍显著才建数据库内索引 | 缺行/重复行选择、敌方null字段补全、测试修改db后的可见性 |
| 科学家MAX | scientist_purchase按可买人数循环；refresh_scientists每帧调can_generate_scientist(MAX) | 缓存最后输入对应的购买结果，资源/人数/解锁/配置变化时失效 | 每位费用round、多资源、×10全有或全无、MAX边界；不套未经证明等价的几何求和 |
| 描述/卡片 | 每帧hightech_description、charge描述、费用和节点赋值；format_description解析表达式 | 缓存稳定描述，动态点数/CD仍按帧刷新；状态改变同帧更新 | 显示精度、悬停全文、所有解锁页签隐藏规则 |
| 重建UI | event和按钮同时可能build_ui；clear/recreate所有卡片 | 单一待重建标志合并相同帧的请求 | 拖拽不销毁节点、滚动/选页/换舰草稿不丢失、解锁确认 |
| 收入统计与保存 | 每帧filter样本、多次60秒求和；拾取每次序列化；充能扣费即保存 | 优先避免同一调用重复求和；测量序列化耗时与次数 | 不延迟已授权的扣费即时保存；峰值、来源、60秒开区间、现实时间倒退 |
| 索敌/弹体 | targets排序；missile_target扫描候选×全部弹体；duplicate/filter/erase | 只有大弹量实测显著时才局部复用同状态候选 | 抗性/距离/槽位排序、逐发占用变化、失锁重选、BOSS清弹时立即停止旧快照 |
| 离线成长 | charge按等级边界循环；普通高科技按升级边界分段 | 先确认离线样本耗时；保留已有大数分支 | ≥1e20既有近似范围和事件合并，不扩展近似到普通数值 |
| 编辑器校验 | Store.prepare重读所有分表，快照多次hash | 低频操作默认KEEP；仅实测慢再复用本次输入 | 全表一致性、冲突检测、公式缓存、备份与批量回滚 |

测量方案（后续阶段执行）：相同引擎、配置、隔离副本、固定随机种子/相同输入脚本，预热后多次采样。覆盖空闲、满槽战斗、十敌齐射、1/2/5倍速、大余额科学家、离线结算。记录主线程帧耗时中位数/P95、tick/UI耗时、查询/归一化/重建次数、存档次数与耗时、对象数量和离线耗时。只有瓶颈实际下降、其他关键场景无明显回退且复杂度净降低才保留优化；不承诺未经测量的提升百分比。

## 4. 行为保护矩阵

下面列的是**当前必须冻结的行为**，不是新增或重新批准的玩法。已知规则争议见TODO，改变争议行为必须作为独立任务。

| 范围 | 不可随重构改变的边界 | 现有相关测试（相对 ../test/；新增边界仅在实施阶段） |
|---|---|---|
| 游戏规则/解锁 | 最后一场全灭为通关；立即过关与倒计时共用受保护入口；驻守/跃迁/死亡三选项 | test_final_encounter.gd、test_guard.gd、test_skip_clear.gd、test_loop_retreat.gd |
| 数值计算 | 关卡线性插值；伤害ceil/最小1；护盾溢出换算；资源分阶段ceil；充能round；科学家费用逐人round | test_game.gd、test_charge_growth.gd、test_scientists.gd、test_large_numbers.gd |
| 资源生产 | 自动生成/击杀/炼铁炉来源不同；自动拾取独立取整；熔炼器只乘击杀铁；峰值不回落；离线不加入在线收入 | test_auto_gen_resources.gd、test_furnace_income.gd、test_resource_display.gd、test_offline_resources.gd、test_charge.gd |
| 战斗 | 导弹足量发射/目标循环/抗性优先；普通弹失锁飞行；末敌死亡清全部弹并中止旧快照；前进重置全CD且不倒计时 | test_target_resistance.gd、test_boss_projectile_clear.gd、test_travel_cooldowns.gd、test_enemy_weapon_positions.gd、test_game.gd |
| 舰船 | 重复装备按槽独立；空槽不自动填；同种数量限制；旧档超限不自动拆；卸下全额退升级资源；换舰保留长期进度 | test_ships.gd、test_unequip.gd、test_ship_equipment_limit.gd、test_equipment_limits.gd、test_bulk_upgrades.gd |
| 时间系统 | delta截断/子步/倍速/暂停；现实60秒收入窗；离线上限；加载结算顺序；升级边界变费率；5秒保存周期与扣费即时保存并存 | test_charge.gd、test_charge_growth.gd、test_scientists.gd、test_offline_resources.gd、test_travel_cooldowns.gd |
| 存档兼容 | version=1；高科技version=2迁移；旧levels迁到槽位；缺字段默认；重复加载不二次发离线收益；tmp→rename；QA删档禁止旧场景回写 | test_ships.gd、test_scientists.gd、test_offline_resources.gd、test_delete_save.gd、test_full_restart.py；损坏/写失败覆盖见U-008 |
| UI行为 | 所有页签解锁前隐藏；重锁切首个可见页；滚动/拖拽/换舰草稿/卸下确认；独立伤害字；船体/炮口位置；资源总量与每秒速率切换 | test_tab_unlocks.gd、test_ship_tab.gd、test_hightech_slots.gd、test_equipment_tabs.gd、test_damage_text.gd、test_ship_visuals.gd、test_enemy_ship_visuals.gd |
| 配置与QA | 显式总表同步；未变不重写JSON；失败不标记已读；公式/格式保存；引用/并发冲突/回滚；小重启和大重启区别 | test_config_workbooks.py、test_level_editor.py、test_level_editor.gd、test_config_panel.gd、test_full_restart.py、test_import.py及专项配置测试 |

注意：此表是范围映射，不是“这些测试当前全绿”的报告。旧测试混入过时规则、内存覆盖配置和旧状态接口，必须先审查再建立基线。规则断言不能为了通过重构而改成新实现的输出。

## 5. 后续实施阶段

执行顺序与总指令一致：审计 → 基线 → 死代码 → 重复实现 → 重复数据 → 唯一状态 → 依赖 → 目录 → 数据驱动整理 → 性能 → 核心规则复核 → AI文档 → 交接 → 最终验收。

**所有阶段共用闸门**：一次只做一个可回退的小项；改动前记录基线/文件范围，改动后跑相关测试，确认行为不变并检查diff，再进入下一项/阶段。有新失败立即停在该项，定位或回退，禁止堆叠后续修改。每项独立提交；代码回退不依赖删除玩家档。存档/配置改动只用隔离夹具验证，本轮没有授权执行其中任何阶段。

EXPECTED_GAIN 顺序统一为：代码复杂度 / 文件数量 / 依赖复杂度 / 性能 / 后续AI Token。以下是定性预期，不是实测结果；文件增减为条件成立时的估计。

### 阶段 1：建立可重复行为基线

- **GOAL**：区分现行规则、历史测试和已知缺陷，提供可比较的重构前结果。
- **CHANGE**：审查第4节测试；按受影响领域运行当前有效测试。补最少的双状态写入、同名槽位、时间边界、存档迁移夹具；固定随机输入，记录状态/资源/事件顺序/截图。性能记录只在隔离副本加入必要测量。
- **FILES**：`../test/README.md`、对应 `../test/test_*.gd/.py`；产物仅 `../test/work/`。
- **RISK**：高——旧测试通过不代表当前行为正确；整份test_game含旧接口，不能直接当唯一基线。
- **VERIFY**：从根用 `python test/run.py <测试名>`（Python需openpyxl/lxml，引擎路径可用 `--godot`）。记录实际版本、配置哈希、退出码、已知失败。不能借机修复玩法或写正式JSON。
- **EXPECTED_GAIN**：复杂度暂持平 / 优先不增文件 / 依赖持平 / 建立测量无运行提速 / 减少反复猜测和重复定位。

### 阶段 2：删除确认无用的历史内容

- **GOAL**：消除无现行职责的代码与验收入口。
- **CHANGE**：逐项验证A06～A10；先迁出旧高科技测试中仍有效的断言，再删除三份旧测试及相应UID（如有）。旧research事件分支、停用默认字段、无调用枚举分别处理。leave及仍被使用的状态暂留。
- **FILES**：`scripts/main.gd`、`scripts/game.gd`、`tools/import_workbook.py`、三份旧高科技测试及 `../test/README.md`；`data/game_data.json` 仅在确认字段无消费者后通过既有投影流程处理，不手工改数值。
- **RISK**：中高——枚举整数移位、测试保障丢失、导入器继续保留旧字段。
- **VERIFY**：符号/字符串/资源/测试引用复核，Godot导入，科学家/拖拽/对应状态专项；投影差异只允许被确认删除的字段。任何用途未明的候选跳过并记录。
- **EXPECTED_GAIN**：复杂度小幅下降 / 最多减少3份旧测试及伴随UID，其余按证据 / 少量分支依赖减少 / 运行提速很小 / 减少加载失效规则的Token。

### 阶段 3：合并重复实现

- **GOAL**：在同一现有模块中消除重复逻辑。
- **CHANGE**：先A02空槽创建；再简化恒定按钮文案和同义升级转发。公式求值A11单独评估，先做两份实现的输入/输出差异表；若统一会改变语义则保留，不建通用表达式框架。
- **FILES**：`scripts/game.gd`、`scripts/main.gd`；条件涉及 `tools/level_editor_store.py`、`tools/inspect_knowledge.py`、现有公式相关测试。
- **RISK**：中；公式合并高风险——Decimal/float、大小写和错误处理不等价。
- **VERIFY**：默认装备与空槽无共享引用；装卸/升级行为相同；公式有效值、ROUND边界、循环/非法引用/不支持语法的结果与错误行为逐项比较。
- **EXPECTED_GAIN**：复杂度下降 / 默认0增减 / 调用链缩短，公式若需新增逆向依赖则不做 / 小幅减少分配 / 同一规则读取位置减少。

### 阶段 4：合并重复配置与数据定义

- **GOAL**：建立配置定义的一处维护，保留必要投影和快照。
- **CHANGE**：A01清单复用；梳理分类、上限、解锁来源，删除被证明重复且无独立语义的定义。区分UI排序、中文显示名、几何常量与数值规则，不强制统一；A16暂留原字段。
- **FILES**：`scripts/game.gd`、`scripts/main.gd`、`tools/import_workbook.py`；相关测试。
- **RISK**：中——同内容数组可能有不同排序用途，不能因现在相同就改变后续行为。
- **VERIFY**：五类装备的单级/10级/MAX、满级与超20级、解锁/页签排序；Excel及运行有效数值差异为零。
- **EXPECTED_GAIN**：复杂度小幅下降 / 0 / 少一处同步依赖 / 基本持平 / 减少多处确认同一常量。

### 阶段 5：确立唯一运行状态源

- **GOAL**：槽位实例成为装备等级和冷却的唯一运行来源，读取不修改状态。
- **CHANGE**：先枚举所有profile.levels/cooldowns旧键读写者；逐个将运行消费者转到槽位入口，再将测试夹具转到同一写入入口。旧档levels只在加载迁移，必要导出字段由槽位推导。把ensure_loadout收敛到加载、安装、卸下、换舰等写边界。最后删除没有消费者的旧名运行API；不要同时改存档版本。
- **FILES**：`scripts/game.gd`、`scripts/main.gd`、装备/战斗/旧档相关测试。
- **RISK**：**最高**——旧字段当前具有写回优先级；同名首槽、数组引用替换、护盾容量/保损、冷却都会受影响。有效旧档兼容必须保留，坏档或矛盾字段处理若变化须独立确认。
- **VERIFY**：新旧档/缺loadout/重复装备/首槽卸下/换舰/容量保损/独立冷却/前进CD/暂停逐项回归；相同操作序列的资源、生命、等级、事件顺序一致。读取函数执行前后状态深比较不得改变。
- **EXPECTED_GAIN**：复杂度显著下降 / 默认0 / 消除双向同步依赖 / 有望减少热路径归一化，待测 / 最大幅度降低理解写入来源和调用副作用的Token。

### 阶段 6：简化不合理依赖

- **GOAL**：减少没有业务必要的对象创建和跨层访问。
- **CHANGE**：A14先改成直接静态调用现有Python解析入口，保持查找顺序；再审查QA操作是否已有足够明确入口，仅缩短实际多余转发。保留共享几何、小格式化模块、拖拽脚本和独立重启进程。
- **FILES**：`scripts/config_panel.gd`、`scripts/level_editor.gd`；相关QA测试。
- **RISK**：低中——GDScript静态调用解析、环境变量回退和独立编辑器启动。
- **VERIFY**：环境指定Python/内置路径/PATH回退；关卡读取校验保存、QA读配置、重启；确认没有为解析路径创建Window。
- **EXPECTED_GAIN**：复杂度下降 / 0 / 去掉对象生命周期依赖，暂保留脚本引用 / 低频小收益 / 少读一个窗口生命周期。

### 阶段 7：简化目录与入口

- **GOAL**：保留现有相对布局，去掉已确认重复的入口。
- **CHANGE**：核实启动脚本/测试工具是否存在真重复；无证据则不动。保留 `scripts/tools/data/config_excel/assets` 和外置 `test`；不机械拆game/main，不迁src。文档合并留到阶段11。
- **FILES**：`../启动.cmd`、项目 `.cmd`、`../test/README.md`、实际确认重复的入口；允许此阶段无代码变更。
- **RISK**：中——当前引擎位置文档存在冲突，按启动代码与实际路径验证，不能顺手移动引擎/玩家目录。
- **VERIFY**：隔离无缓存启动、独立编辑器启动、测试相对路径、QA大重启；不改变用户存档目录。
- **EXPECTED_GAIN**：复杂度持平或小降 / 0，确认重复才减 / 不增加跳转 / 启动性能基本持平 / 入口更明确，避免无意义目录阅读。

### 阶段 8：整理现有数据驱动链路

- **GOAL**：同类配置沿用一条转换链，消除入口间漂移。
- **CHANGE**：A12将共用分表发现逻辑放在已有config_workbooks中，由Store复用；保留入口明确不同的行为。A13仅合并语义相同的校验。不新增资源系统、DSL、schema框架；不把“加强校验”混入等价重构。
- **FILES**：`tools/config_workbooks.py`、`tools/level_editor_store.py`、`tools/import_workbook.py`；配置/编辑器专项。
- **RISK**：高——charge/ship可选发现、路径、旧manifest、JSON保留字段、公式缓存和事务边界。
- **VERIFY**：现有/旧清单、可选表缺失/存在、无变化、单表变化、坏引用、同步途中改文件、写入失败回滚。相同输入接受/拒绝结果一致，投影有效数值一致；需要改变结果的差异单独提交决策。
- **EXPECTED_GAIN**：复杂度下降 / 0 / 少一份发现规则，复用已有单向依赖 / 导入收益待测 / 配置任务少读一套并行规则。

### 阶段 9：按测量结果优化热点

- **GOAL**：以最少代码降低实际高频开销。
- **CHANGE**：按第3节实测排名，一次优化一个热点。先复用一次调用内的查询结果、同帧重建合并，再考虑同模块缓存。缓存必须列出失效条件；不新增全局缓存管理器。保留既有大数近似范围，不改变保存承诺。
- **FILES**：仅实际命中的 `scripts/main.gd / game.gd / database.gd` 与对应专项；测量产物在 `../test/work/`。
- **RISK**：高——陈旧缓存、事件顺序、隐藏UI副作用、同帧击杀后仍使用旧目标、时间分段和数值误差。
- **VERIFY**：固定输入前后状态/事件差分；UI交互验图；对比同机多次采样中位数/P95/调用次数与存档次数。无可重复收益或复杂度增加过多时撤回。
- **EXPECTED_GAIN**：复杂度净下降才接受 / 默认0 / 缓存失效依赖不得扩散 / 仅报告实测收益 / 少读重复计算路径；缓存说明成本纳入净收益。

### 阶段 10：复核核心规则测试

- **GOAL**：确认删冗余后仍覆盖真正的玩法边界。
- **CHANGE**：检查第4节矩阵缺口；补数学、状态切换、时间与旧档边界测试；合并真正重复夹具，不引入测试框架层。不恢复已废弃研发机制，不追求行覆盖率。
- **FILES**：`../test/test_*.gd/.py`、`../test/README.md`；不改玩法。
- **RISK**：中——把过期期望“修绿”会隐藏行为变化；U-004/U-006/U-008等未决问题不得默认为已解决。
- **VERIFY**：全部受影响核心专项通过；确认旧档迁移、离线重复加载、资源守恒、同名槽位、BOSS清弹与UI门槛均有独立断言。已知缺陷单列而非删除断言。
- **EXPECTED_GAIN**：复杂度测试侧小降或必要增加 / 优先0 / 少依赖旧私有字段 / 运行性能无影响 / 减少未来反复推导规则及错误修复成本。

### 阶段 11：压缩AI文档为五份权威文件

- **GOAL**：落实总指令的AGENTS/PROJECT/ARCHITECTURE/STATUS/DECISIONS体系。
- **CHANGE**：逐项迁移独有信息、检查来源后再删旧文档；历史开发记录归Git。保留项目 `AGENTS.md` 和 `docs/` 中其他四份目标文件，根入口仅链接。不要复制数值表。
- **FILES**：项目与根AGENTS；`docs/PROJECT.md / ARCHITECTURE.md / STATUS.md / DECISIONS.md`；待合并的 `GAME_DESIGN / INVENTORY / DATA / TODO / VALIDATION / modules/*.md`。
- **RISK**：中高——压缩丢失规则来源、有效测试命令或未决事项比长文档更危险；需先改入口中的旧路由规则，不能留下失效链接。
- **VERIFY**：逐项检查下方迁移表，所有独有规则/来源/问题ID可找回；无重复权威事实、无断链；只改文档不跑游戏测试。
- **EXPECTED_GAIN**：知识复杂度显著下降 / 13份上述辅助AI文档迁移完毕后可删除；五份保留，人类操作/资产说明按用途保留 / 路由减少 / 运行无影响 / 默认上下文目标较当前降低80%以上，以实际读取量验收，非承诺精确Token比例。

文档迁移目的地：

| 现有内容 | 权威目的地 / 处理 |
|---|---|
| GAME_DESIGN、modules规则与DATA来源 | PROJECT保留稳定玩法与必要来源索引；直接实现约束在对应代码写少量WHY说明，不能把未确认规则伪装成代码即可证明 |
| INVENTORY、ARCHITECTURE、DATA工作流 | ARCHITECTURE只留目录/入口/依赖/数据源/状态所有权及查找指引；跨机操作命令归现有项目README |
| TODO未决ID | STATUS的已知问题保留ID与最短下一步；已解决历史归Git，不复制旧长表 |
| VALIDATION | 当前有效测试入口/隔离命令归既有test/README；历史结果归Git；STATUS只记最近相关验证 |
| STATUS长Done列表 | 覆盖为当前版本、功能摘要、进行中、已知问题、下一步及相关入口 |
| DECISIONS | 每项1～3行，保留不知道就会误改的长期决策 |
| LEVEL_EDITOR、ART_GUIDELINES、资产README | 属于人类操作/美术来源说明，不按“AI文档”数量机械删除；实质重复内容仍合并 |
| 本REFACTOR_PLAN | 实施期间按需读取；验收结果留精简记录，完成后不作为永久默认背景，历史由Git保存 |

### 阶段 12：建立低成本交接协议

- **GOAL**：让不同AI/IDE只用短入口定位，不依赖聊天历史。
- **CHANGE**：L0默认仅AGENTS+STATUS；L1按任务读ARCHITECTURE/PROJECT/DECISIONS；L2搜符号和直接依赖。标准顺序 Search → Minimum Read → Change → Verify → Handoff。结束按 HANDOFF 的 DONE/CHANGED/VERIFY/NEXT，只有需要时加BLOCKERS/DECISION。
- **FILES**：`AGENTS.md`、`docs/STATUS.md`、必要时 `docs/DECISIONS.md`；根AGENTS只指向项目入口，不另建平台记忆。
- **RISK**：低中——入口过短可能漏掉隔离、来源、解锁及存档约束；不能为满足长度删除这些要求。
- **VERIFY**：以“改掉落取整”“改换舰页签”“改分表导入”三种任务模拟陌生AI接手，只读L0和相应L1即可定位实现和测试；不用全仓扫描。记录文件数、读取字节和跳转次数。
- **EXPECTED_GAIN**：协议复杂度下降 / 0 / 跨平台入口唯一 / 无运行影响 / L0建议AGENTS≤80行、STATUS≤60行，普通任务实现上下文尽量2～4文件；以完整约束优先，不机械截断。

### 阶段 13：最终全项目验收

- **GOAL**：证明已实施各项保留现有正确行为，并报告实际收益。
- **CHANGE**：不增加功能；汇总最终源码/配置差异、旧档兼容结果、测试、性能和读取成本；形成总指令要求的REFACTOR_RESULT（BEFORE/AFTER/REMOVED/MERGED/PERFORMANCE/TOKEN/RISKS/NEXT）。
- **FILES**：全项目只读核验；结果优先写现有本方案的验收部分或交付摘要，状态只更新 `docs/STATUS.md`，不另增长篇AI日志。
- **RISK**：高——孤立专项通过仍可能有组合交互问题；此阶段全项目验证有明确的跨模块改动依据。
- **VERIFY**：隔离无缓存启动、当前有效测试集、真实UI交互与截图、QA导入及两种重启、迁移档往返；对照阶段1相同输入。复核Excel/有效投影未意外改变、正式存档未被触碰、五文档导航可用。未过项如实列出，不宣称完成。
- **EXPECTED_GAIN**：报告实测净变化 / 报告实际文件净减少及保留原因 / 报告依赖与双状态消除情况 / 报告同机实测而非估算 / 报告L0读取量和三类任务文件数/字节/Token（可用相同分词器时才精确统计）。

## 6. 本轮交付检查与停止点

- 已完成架构/数据流/所有权地图、分类清单、热点分析、七类行为风险及配置QA风险、逐阶段六字段方案。
- 本轮仅新增 `REFACTOR_PLAN.md`；没有修改代码、测试、数值配置、其他文档或存档。
- 本轮只做静态源码和引用审计、文档结构/链接检查；未运行游戏测试、性能测试或Excel导入，未将历史验证结果冒充本轮结果。
- **停止点：等待用户确认本方案；下一步如获授权，从阶段1建立行为基线开始，不直接进入清理或重写。**

## 7. CHECKPOINT 1 执行记录（2026-09-15）

授权更新：用户已批准仅连续实施 Phase 1～4；Phase 4 完成必须停止，Phase 5 / 8 / 9 各自需要单独检查点。第0/6节及阶段说明中的“本轮不实施”描述的是初版审计交付，不覆盖此授权。正式数值、玩家档与旧状态源保持不动。

### Phase 1：完成

- 修改仅在测试：补五艘舰船空槽/默认安装顺序和独立字典、旧levels/cooldowns写入优先级、旧档迁移；保留旧高科技测试中仍适用的属性/描述/离线上限/进度UI断言到科学家专项，拾取/寿命断言到炼铁炉专项。批量升级新增五类各自单级/10级/MAX预算一致性。
- 修正旧夹具：bulk UI安装护盾；装备上限按实际解锁门槛并安装三件空槽装备；充能属性检查前安装火炮/导弹/护盾。没有改变既有正确规则断言。
- 初次充能测试3项失败，定位为未安装装备而非倍率错误；补夹具后原54项及新增3项全部通过。新增科学家测试曾错误预期133%，按既有compact显示和历史断言修为130%，游戏代码未改，复验通过。未带失败进入下一阶段。
- 环境：Godot `4.7.2.stable.official.ed1daf0bf`；现有bundled Python 3.12.14 / openpyxl 3.1.5 / lxml 6.1.1。系统Python缺lxml，未安装依赖。所有游戏运行都经 `test/run.py` 创建项目与用户目录隔离副本。
- 验证：科学家59、炼铁炉23、批量升级70、拖拽32、装备页282、卸下25、页签解锁14、离线资源11、充能57项全部通过；舰船专项、装备上限专项通过；每项Godot导入退出0。共11个当前有效专项，未宣称全测试集全绿。
- 日志索引：`../test/work/refactor-checkpoint-1/phase1-*.log`，各日志首行给出隔离副本路径。已检查科学家半进度及满装武器页截图；根证书读取提示、卸下测试的QA子窗口提示为当前环境/既有行为，不是规则断言失败。
- 正式配置基线：对总表、分表及清单、运行JSON保存SHA-256到 `../test/work/refactor-checkpoint-1/input-hashes.json`；Excel打开时采用共享只读句柄，不关闭用户Excel。未读正式存档。
- 检查：测试diff与 `git diff --check` 通过。没有启动性能优化、存档改造或状态源修改。

### Phase 2：完成

- 删除 `test_hightech.gd / test_hightech_continuous.gd / test_hightech_progress.gd`，共343行，未发现配套UID或执行代码引用。有效规则覆盖分流：点数/迁移/离线/属性/描述/进度UI归scientists，收入/峰值/领取/寿命归furnace_income，拖拽/页签归hightech_slots；并发计时、暂停项remaining、research切换API是已废弃语义，不迁回运行时。
- 删除 `main.on_event` 的无发射方research分支；保留hightech_complete的文案和deferred重建。补UI描述来源/tooltip/卡片边界和完成事件断言。
- 保留：State枚举（LEVEL_SELECT虽无调用，但删除涉及其他状态整数值，收益不足）；leave/MAIN_MENU/UPGRADE/DEFEAT仍有调用；旧default字段不在此次修改投影链；截图入口、legacy探针、绘图fallback、旧档迁移仍有用途。
- 验证：科学家63项、拖拽32项全部通过，Godot导入退出0；相关执行引用搜索无命中，diff及空白检查通过。日志 `../test/work/refactor-checkpoint-1/phase2-*.log`。无新行为差异或验证失败。

### Phase 3：完成

- default_loadout复用既有empty_loadout，每次仍创建独立槽位字典，默认安装顺序不变，未触及ensure_loadout或旧状态同步。
- 舰船专项、卸下25项、五类批量升级70项通过，Godot导入退出0，diff检查通过。日志 `../test/work/refactor-checkpoint-1/phase3-*.log`。
- 科学家+1按钮直接绑定现有assign_scientist，移除select_research转发和恒定文案函数；文案仅在建钮时设置，未改分配/保存/事件/拖拽。科学家63项、拖拽32项通过，已检查科学家截图，残留符号搜索与diff检查通过。
- 同义装备升级转发仍涉及旧levels和首槽选择，留到Phase 5；公式求值器没有安全净收益，保持不动。以下为源码对照，不冒充运行测试：

| 输入/边界 | inspect_knowledge | level_editor_store | 本轮决定 |
|---|---|---|---|
| 一元负号 `=-1` | 没有UnaryOp分支，报unsupported | 支持负号 | 不合并语法接受范围 |
| 小写 `=round(1.5,0)` | 仅识别大写ROUND | upper后识别 | 不改变合法输入集合 |
| 递归公式中间结果 | Decimal保留到比较 | 每个单元格转float，再转Decimal参与引用 | 不改变精度与缓存内容 |
| 单元格引用/非法值 | 工作簿上下文、审计异常分类 | 草稿cells、数值类型/有限性检查及文件单元格错误信息 | 不创建通用解析层，不引入工具反向依赖 |

### Phase 4：完成；在此停止

- 删除重复BULK_EQUIPMENT定义，批量升级校验/MAX/UI统一引用现有EQUIPMENT；内容与顺序完全一致。武器/防御分类、UI排序、显示名、几何配置和JSON原字段保留；没有修改Excel→JSON链路。
- 验证：五类单级/10级/MAX预算一致性70项、装备上限28项、页签解锁14项、装备页282项全部通过，Godot导入退出0；已检查最终防御页截图，diff及残留符号检查通过。日志 `../test/work/refactor-checkpoint-1/phase4-*.log`。
- 完成后重新读取12份输入文件SHA-256，与Phase 1全部一致；有效游戏数值及配置文件均未改变。正式玩家存档从未读取或写入。

### CHECKPOINT 1

- **DONE**：Phase 1～4完成；每项验证后提交，Phase 3的空槽/按钮两个子项分别提交。未开始Phase 5。
- **REMOVED**：三份废弃计时研发测试（343行）、旧research事件分支、两处按钮包装函数、重复装备常量。保留用途仍存在或有语义风险的候选，详见阶段记录。
- **MERGED**：空槽构建归empty_loadout；装备清单归EQUIPMENT；历史有效断言归科学家/炼铁炉/既有拖拽专项。
- **TEST**：11类相关专项建立基线，Phase 2/3/4分别完成直接影响范围验证，无未解决的断言失败。初次失败为充能旧安装夹具3项与新增显示期望1项，均在Phase 1定位并复验；既有规则断言没有放宽。仍有Windows根证书读取及QA子窗口提示。未跑无关全测试集，不宣称完整旧测试集可直接作为Phase 5验收。
- **BEHAVIOR_DIFF**：在已验证范围未发现游戏行为差异；数值、资源算法、战斗、时间步进、存档迁移和解锁逻辑未修改。源码层移除了无消费者旧API，不能据此宣称兼容任意仓库外调用者。
- **RISKS**：旧levels对首槽写回、cooldowns双键优先级、ensure_loadout读取时替换数组、旧档矛盾字段处理仍在，必须Phase 5专项保护。其他历史测试可能仍混有旧安装/计时假设，先检查夹具再运行，不改变正确规则断言；既有未决规则仍见TODO。
- **DIFF_SUMMARY**：运行时代码只改game.gd与main.gd，净减少12行；测试GDScript净减少205行，合计净减少217行，无新增运行模块/依赖/抽象层。没有进行或宣称实测性能提速；来源统计相对 `7f4d704`，不计方案/状态/README文档。
- **NEXT**：等待用户单独批准Phase 5；Phase 8与Phase 9前再次提交高风险检查点。

## 8. Phase 5专项（2026-09-15）

用户已单独授权Phase 5；完成后必须停止，不进入Phase 6。本阶段先专项基线，再按消费者逐项迁移；存档version不变，正式玩家档不读不写。起点提交 `693f8f1`。

### 基线与调用者清单

- `test_state_ownership.gd` 在未修改运行源码的隔离副本执行：20项中19项通过，首槽卸下独立冷却1项失败；停止该小项，原因与待裁决范围只在TODO U-016登记。日志 `../test/work/refactor-phase5/baseline.log`。
- 已通过：同名等级、暂停、普通独立倒计时、首槽退款/空槽/剩余等级、前进完整CD及冻结、护盾升级保绝对损失、无loadout旧档迁移、矛盾levels只覆盖首同名槽、重复保存加载的装备/生命/资源一致。
- 当前读取副作用探针记录：新游戏stat(laser)会创建充能job；weapon_entries会把旧levels写回槽位。探针只记录现状，尚不是读取纯度通过证明。

| 信息 | 正常运行读取者 | 正常运行写入者 | 旧档/导出边界 | 测试依赖 |
|---|---|---|---|---|
| profile.levels | sync_legacy_level；upgrade_cost/upgrade_costs的无实例回退 | fresh_profile；equip_slot/unequip_slot/switch_ship/upgrade_slot；sync反向写槽位 | load_progress读旧levels；save_progress目前直接序列化profile | bulk_upgrades、equipment_limits、equipment_tabs、game、ships、unequip、delete_save；Phase5基线中的raw字典专属旧输入 |
| 玩家cooldowns名称键 | tick的首同名槽优先取值；main冷却条fallback | change_state(TRAVEL)、tick | 无存档读写；玩家冷却不持久化 | game、target_resistance、travel_cooldowns、ships、Phase5基线 |
| 玩家cooldowns槽位键 | tick、main冷却条 | change_state(TRAVEL)、tick；equip/unequip清槽；start/retreat清全部 | 非持久化运行状态 | 现有ships与新增Phase5基线 |
| 敌方cooldowns数组 | 敌方tick | spawn_group、敌方tick | 不保存 | enemy_weapon_positions及capture；独立于玩家，不迁移 |
| ensure_loadout | 当前被loadout_entries/stat隐式调用，进而影响weapon/defense/slot_entry、tick、绘制与UI资格检查 | normalize重建槽位数组；rebuild_unlocks和load_progress显式调用 | 加载归一化必须保留 | ships、ship_equipment_limit、ship_visuals、unequip；直接改测试profile后须明确写边界 |
| sync_legacy_level | weapon_entries/defense_entries/stat、upgrade_cost/upgrade_costs/can_upgrade_amount/max_upgrade_amount/upgrade | 第一同名槽位level | 目前不限于加载，需收敛 | 多个测试用profile.levels写入后依赖读取同步 |
| 名称升级API | main._process单级/10级/MAX资格轮询 | upgrade/upgrade_max转首同名槽 | 无独立存档责任 | bulk_upgrades、equipment_limits、game；UI按钮回调已调用槽位API |
| stat间接充能读取 | equipment_stat→charge_multiplier→charge_job | charge_job懒创建profile.charge及job | 加载充能仍使用同一job入口 | charge、charge_growth、科学家/舰船属性测试 |

界面按钮字典的名称/槽位混合键目前是控件索引，不是等级或冷却数据副本；迁移时需验证首个同名控件与后续槽位控件分别引用正确实例。QA本身没有读写levels/cooldowns，删除存档测试的旧等级写入是夹具。

### 实施与验证记录

用户对U-016回复“修复”，授权纠正剩余槽位被旧名称键覆盖的缺陷；除此之外不修改游戏规则。以下各项先验证、检查diff，再进入下一项。

| 小项 | 结果 / 回退提交 | 验证日志（均在`../test/work/refactor-phase5/`） |
|---|---|---|
| 玩家冷却按槽位唯一读写；UI取消名称回退 | c9a6af7；保留原失败断言并修复 | cooldown-fix.log、travel.log、targets.log、cooldown-test_state_ownership.gd.log、cooldown-test_ships.gd.log |
| 旧levels仅加载迁移/保存派生，删除运行同步 | 8edaa91 | levels.log、levels-test_ships.gd.log、levels-test_bulk_upgrades.gd.log、levels-test_equipment_limits.gd.log、levels-test_unequip.gd.log |
| 装备查询退出ensure；充能状态创建时初始化 | 1a87f4d | purity.log、purity-fixed-test_charge.gd.log、purity-fixed-test_charge_growth.gd.log、purity-fixed-test_ships.gd.log、purity-fixed-test_unequip.gd.log |
| UI资格查询直接绑定槽位 | be66613；节点索引兼容保留 | ui-test_equipment_tabs.gd.log、ui-test_bulk_upgrades.gd.log、ui-test_equipment_limits.gd.log、delete-fixed.log |
| 科技排序/收入描述退出隐式写入，提交移到明确边界 | b0f4706；只收敛读取副作用，没有依赖整理或生产公式修改 | read-boundary-before-*.log、read-boundary-*.log、final-state-fixed.log、final-test_*.log |
| 同名装备UI专项补充 | 独立测试提交；不新增运行实现 | final-duplicate-ui.log：27项通过 |

失败处置记录（不计作未解决失败）：

- 原冷却基线20项中1项失败，按用户授权修复；没有更改0.15秒的正确断言。
- 充能旧夹具4处直接clear状态后依赖读取懒创建；首次运行脚本错误并由隔离运行器超时退出。停止该项后，将夹具重置改为fresh_profile().charge，原57项及20项成长断言全通过，费用/分配/时间断言未改。
- 删除存档测试原用整个运行profile比较fresh_profile，混入时间戳及保存/UI元数据。693f8f1隔离复跑同样2项失败（delete-baseline.log）；改为显式校验元数据默认值，只有时钟字段不作进度相等比较。7项通过；删除/重启实现未修改。
- 新增重复加载夹具第一次使用会自动保存的构造器，第二次实际读到转换后的另一个输入，补齐零级科技字段导致深比较失败（reload-diagnosis.log）。关闭夹具自动保存后，同一旧输入连续加载，完整深比较通过；未改变科技规则或放宽该断言。

### CHECKPOINT 2

**DONE**

Phase 5完成：运行等级归槽位，玩家冷却仅槽位键，旧字段迁移收敛到边界，装备/充能/科技排序/收入描述读取不再写入运行档案。所有本阶段小项均验证后继续；Phase 6未开始。

**STATE_BEFORE**

- 槽位level与profile.levels双向同步，读取旧别名还会覆盖首槽。
- 玩家cooldowns同时维护装备名称和槽位键，首槽优先读取名称键。
- 普通查询反复ensure_loadout重建数组；stat间接创建charge job；科技槽位查询写排序，描述查询写历史峰值。

**STATE_AFTER**

| 状态 | 唯一运行所有者 / 写入边界 |
|---|---|
| 装备等级 | profile.loadout[category][index].level；安装/卸下/升级/换舰以及加载迁移 |
| 玩家剩余冷却 | BattleGame.cooldowns[weapons_<index>]，以槽位身份索引；不另在loadout存冷却副本，不持久化 |
| 敌方冷却 | 原enemy.cooldowns数组；未改 |
| 当前生命/护盾 | player.armour/player.shield；容量由已装槽位派生，原保损/恢复语义不变 |
| 充能状态 | profile.charge[key]；fresh_profile初始化，加载及明确充能操作更新 |
| 科技顺序、历史收入峰值 | 原profile.hightechOrder/furnaceIncomePeak；仅在对应初始化、加载、解锁、拖拽、保存或收入结算边界写入 |

**LEGACY**

- 保存version仍为1；读取旧levels时仍遵循首同名槽优先、缺失/非法值按1级、其他重复槽保留自身等级的既有有效行为。
- 保存临时字典从当前首同名槽派生levels；未安装装备派生1级。运行profile不保存该兼容副本；旧未安装装备的无效等级不再作为运行状态保留。
- 名称升级/费用API共7个仍由现有测试使用，保留为无状态的首槽查询/转发：upgrade_cost、upgrade_costs、can_upgrade_amount、can_upgrade、max_upgrade_amount、upgrade、upgrade_max。生产UI已全部调用槽位API；没有为删除测试调用而新增通用适配层。
- ensure_loadout保留加载/重建解锁用途及显式测试边界，只有2个生产调用点。玩家名称冷却从未进入存档，无须引入迁移接口。

**REMOVED**

删除sync_legacy_level、profile.levels运行初始化/读写、名称冷却读写及UI回退、查询中的ensure调用、charge_job懒创建、科技排序/描述查询隐式提交。没有删除仍有消费者的名称API。

**READ_PURITY**

状态专项1114项通过，其中539次读取前后profile/cooldowns/player完整深比较、539次槽位数组身份检查。7种状态、每种77个读取入口/参数组合；包括同名不同级、首槽卸下、重载、空槽、残留旧字段、未提交收入样本。无缓存写入豁免；未宣称对任意仓库外直接改写或任意函数做全仓证明。

**SAVE_COMPAT**

缺loadout旧档、矛盾levels、缺levels、显式空槽、同名重复槽、保存派生首槽等级、冷却不持久化、重复导出重开及同一旧输入重复加载均通过。装备/生命/资源保持；未触碰正式玩家存档。初始化提前存在零值充能状态，查询不再懒添加字段；兼容导出仍可由原version 1读取。

**TEST**

专项1114；装备页282；批量70；等级上限28；同种数量限制68；卸下及重复UI27；换舰页8；前进冷却22；抗性索敌21；充能57/成长20；科技排序32；科学家63；炼铁炉23；离线资源11；删除存档7；舰船专项通过。所跑测试均为隔离副本，Godot导入退出0。保留已有根证书提示及QA子窗口警告；没有未解决的本阶段测试失败。历史综合探针限制见TODO U-017，不宣称全仓测试全绿。

**BEHAVIOR_DIFF**

唯一获准游戏行为修复为U-016（影响该缺陷场景的后续开火时机）。在此修复后的基线上，升级、卸下、护盾升级、换舰的资源/生命/等级/冷却/事件序列JSON逐字一致：trace-before.log与final-state-fixed.log对应的state-ownership-trace.json，比较记录trace-comparison.txt。12份正式配置输入SHA-256与Phase 1一致；无数值/生产公式修改。读取不再触发写入是本阶段预期API行为改变。

**CODE_DIFF**

相对693f8f1，运行源码仅game.gd/main.gd：增加42行、删除62行，净减20行；无新增运行文件、依赖或抽象层。测试增加294行、删除53行，净增241行（其中新增212行专项）；不是以删测试追求总行数下降。UI从名称→首槽转发改为槽位入口，属性/武器查询不再进入归一化及同步链。没有性能或Token的实测百分比；理解成本降低来自状态所有权和写入边界明确，而非更多目录。

**RISKS**

公开Dictionary仍可被直接改写；测试或后续代码须使用槽位写入API，原始旧输入只能走加载边界，不能期待读取修复非法状态。名称兼容API仍有测试消费者，未来删除前须迁移消费者。旧version 1首槽优先是刻意保留的兼容规则，不应擅自改成loadout优先。U-017及其他原有未决规则未扩大处理。

**NEXT**

Phase 5直接影响范围已具备进入Phase 6的验证基础；仍须用户确认CHECKPOINT 2后方可开始。本轮停止。Phase 8和Phase 9的单独进入前检查点要求继续有效。

## 9. CHECKPOINT 3：Phase 6～7（2026-09-15）

用户批准CHECKPOINT 2，授权Phase 6→7连续执行；Phase 7后停止，Phase 8与9未获实施授权。本次起点8fedb11。

### DONE

- Phase 6：确认find_python仅使用OS环境变量和FileAccess，不读Window实例字段；改为现有config_panel.gd的静态函数，level_editor直接调用。查找函数体、线程执行参数、编辑器保存/校验逻辑均未改。
- 先建立查找分支及QA基线（2fd0be9），通过后提交生产改动（818d961）。没有新增PythonService、Helper或其他模块。
- Phase 7：核对三个启动脚本、两个场景、测试运行器及受保护模块的调用者；没有值得修改的目录结构，保持现状。仅修正文档中固定旧盘符及引擎位置表述，未移动文件。

### DEPENDENCY_BEFORE

`level_editor.run_action → load(config_panel).new() → Window实例.find_python → free()`：只为查找路径创建、释放窗口，生命周期无业务必要。

### DEPENDENCY_AFTER

`level_editor.run_action → preload(config_panel).find_python()`：直接静态调用。仍保留现有脚本引用，不声称消除了模块依赖；无需理解窗口初始化或释放即可理解Python定位。

### REMOVED

删除一次无用Window创建、一次free及描述该绕行的注释；没有删除其他入口、模块、QA动作或线程。Python优先级仍为有效SPACE_BATTLESHIP_PYTHON → USERPROFILE下既有内置路径 → 字符串python交给PATH。

### KEPT

| 模块/入口 | 保留原因 |
|---|---|
| ship_visuals | game/main共用舰船几何与炮口位置，内联合并会复制规则 |
| number_format | 游戏与UI共用数量格式，集中维护精度及大数显示 |
| hightech_slot | 独立控件负责Godot拖拽、命中与反馈，并非多余转发 |
| restart_host | 必须在旧进程退出后继续导入和启动新进程，生命周期不能并回旧游戏 |
| QA restart_game/reload_game/full_restart | 分别处理保存与忙碌门、deferred场景切换、独立进程重启，不可按函数名视为重复 |
| QA轻量动作入口 | import_config/delete_save等表达按钮动作，未发现足以抵消调用点可读性损失的净收益，保持 |
| ../启动.cmd | 资源导入成功后启动main场景，使用游戏.userdata |
| 打开编辑器.cmd | --editor启动Godot项目开发界面，与游戏启动不同 |
| 关卡编辑器.cmd / level_editor.tscn | 独立业务编辑器、可选引擎覆盖、独立.runtime/level-editor-user |
| main.tscn / project.godot | 正常游戏场景与项目入口配置，不能与业务编辑器场景合并 |
| test/run.py与各专项 | 统一隔离运行器与不同验证职责，测试相对路径已经稳定 |

### DIRECTORY

目录、文件路径和入口数量均不变。scripts/tools/data/config_excel/assets及外置test保留；未拆main/game，未创建src层，未合并AI文档体系。当前边界已有明确用途；移动会增加引用修改与定位跳转，没有证据证明净收益。

### TEST

日志统一在`../test/work/refactor-phase6-7/`：

- before-test_level_editor.gd.log / after-test_level_editor.gd.log：修改前后均18项通过，其中4项覆盖有效覆盖路径（含空格）、无效覆盖回退、空覆盖回退、内置不存在的PATH回退；其余验证读取、编辑、校验、保存、重载及删除引用保护。PATH分支验证返回命令名，不宣称当前机器通过PATH安装了全部Python依赖。
- before-test_config_panel.gd.log：运行代码未改前有3项失败，原因见U-018。测试保留真实拆分按钮检查，随后恢复隔离副本的现行分表用于导入，不改导入规则或正式输入。before-fixed-qa.log / after-test_config_panel.gd.log：14项通过，覆盖无变化不写JSON、暂停/倍速、同进程重启和QA身份/设置保留。
- full-restart.log：独立进程大重启通过，验证忙碌保护、新PID、执行更新代码、同一隔离用户目录、进度及偏好保留。
- 所有运行经test/run.py，创建新的无缓存项目副本、隔离用户目录。三份.cmd仅静态检查，实际运行的是对应场景/重启专项，没有启动正式游戏或访问正式玩家档。
- input-hashes-check.txt：12份正式输入SHA-256与前序基线一致；tools、data、config_excel、game.gd及main.gd均无diff。Godot导入退出0，diff检查通过。无未解决专项失败；仍有既有Windows根证书提示。

### BEHAVIOR_DIFF

受测行为无变化；Python查找优先级、工作线程命令、QA控制与重启语义不变。仅改变静态API调用方式并移除无用对象生命周期。游戏数值、规则、存档格式、正式玩家档和配置实现未修改。

### CODE_DIFF

相对8fedb11：运行代码增加2行、删除5行，净减3行，仅config_panel.gd/level_editor.gd；测试净增35行，仅既有两份专项。新增/删除/移动运行文件、测试文件、入口均为0。Phase 7无运行代码修改。源码和测试合计净增32行，新增内容用于保护定位分支与修正隔离夹具，不以减少断言换取行数下降。

### TOKEN_IMPACT

编辑器的Python定位现在一眼可见，未来AI无需追踪Window实例创建、初始化和释放。未增加通用定位模块，避免新增跨文件跳转。入口地图说明各自职责及隔离目录，降低误删/误合并所需反复审查；没有测量或宣称Token百分比收益。

### RISKS

- find_python仍在config_panel脚本中；静态引用保留是有意选择，移到新文件没有明确净收益。
- 正式三份.cmd未直接运行；已静态核对其不同参数/用户目录，并用隔离场景和真实重启验证对应路径。不能把这当作其他平台启动兼容性证明。
- Phase 8现存输入策略差异不能自动修正；旧总表缺科学家字段见U-018，不能猜测默认数值或用重新拆分覆盖正式分表。
- 原有U-017及其他未决规则继续保留。下一阶段必须重新建立自己的输入与事务基线。

### PHASE8_PLAN（待批准，尚未实施）

本轮只按符号只读复核tools源码，没有运行Phase 8重构或改写其文件。重新确认以下具体边界：

| 当前事实 | Phase 8拟处理范围 | 文件 |
|---|---|---|
| incremental_import允许charge/ship缺清单时按文件发现；若原JSON已有对应节但文件丢失则拒绝 | A12先建立逐入口输入矩阵；只把证实等价的发现/路径部分放回既有config_workbooks，由Store复用。若保留差异需要大量策略参数，取消合并 | tools/config_workbooks.py、tools/level_editor_store.py |
| Store.__init__只对charge特殊处理；ship缺映射会失败；其路径检查显式禁止两种斜杠 | 保留当前接受/拒绝集合、异常与UI提示；不自动让Store接受缺ship，不自动收紧增量入口 | 同上 |
| Store.prepare已调用validate_projection，又有编辑表ID、敌机外观/抗性、武器引用和掉落资源检查 | A13默认KEEP；只有逐项证明范围及错误语义相同才抽取到已有校验入口。不能把编辑器额外检查直接加入所有导入流程 | tools/level_editor_store.py；仅证实有共用项时改tools/import_workbook.py |
| Store.snapshot包含分表、目标JSON及manifest；增量路径使用CACHE_VERSION/directory/target_hash/hashes并提交前复核源文件 | 冻结指纹字段、版本、绝对路径行为和提交顺序；先验证清单/目标/源文件并发变更现状。发现额外风险单列，不顺手加强规则 | 上述tools；manifest、fingerprint及JSON只作隔离夹具/验收目标 |
| Store.workbook_bytes维护公式及XML缓存；atomic_batch已有备份、暂存及回滚；直接导入另有单文件提交 | 不合并不同公式求值器，不改精度、支持语法、缓存、ZIP保真或事务实现。两条入口承担不同事务职责，不强行共用一条完整流程 | 本阶段不预设修改公式/事务函数，仅验证直接影响范围 |

获准后的小步顺序：

1. **基线**：在test/work中复制现行分表、清单和投影；运行现有test_config_workbooks.py、test_level_editor.py、test_import.py及相关配置专项，确认夹具适用。旧总表另作拒绝样本，不补策划值。
2. **输入矩阵**：在既有测试文件补完整/旧/缺失/损坏manifest、charge/ship有无映射与文件、原JSON节存在与否、路径斜杠/非法路径、必需表缺失。逐入口记录接受/拒绝、错误信息和文件是否写入，不预设入口结果相同。
3. **最小共用项**：仅在A12有明确净收益时改config_workbooks/Store；每小项跑对应矩阵并比较前后结果，不通过就定位或回退。A13可不改，绝不扩大校验范围。
4. **事务与投影回归**：无变化时不解析/不写；单表变化只替换对应投影；保留其他JSON字段/source_files；缺公式缓存、坏引用、读中改源/清单/目标、提交失败和回滚失败均按原行为验证。对JSON有效数值及字段逐项比较，对不应变化的分表和ZIP部件逐字节比较；验证失败后原文件、缓存、备份/临时文件状态。
5. **集成**：隔离运行编辑器读取→校验→保存→重载与QA导入→无变化→重启。正式Excel/game_data.json/manifest不作为重构写入目标；任何确需改变旧输入兼容、错误处理或失败原子性的事项另行提出确认。

预计测试修改仍集中在既有`test/test_config_workbooks.py`、`test/test_level_editor.py`，有明确覆盖缺口再改`test/test_import.py`及对应配置专项；不新建框架。检查全部通过、确认行为不变后才推进下一小项。**当前停止在CHECKPOINT 3，必须再次获批才能开始Phase 8；Phase 9性能优化也未开始。**

## 10. CHECKPOINT 4 — Phase 8（2026-09-15）

### DONE

**KEEP CURRENT IMPLEMENTATION。** 从0915e00建立独立基线，先运行现有专项，再对当前正式分表的隔离副本建立输入与故障矩阵，最后逐项判断A12/A13。未找到兼具语义等价和净收益的抽取，生产实现没有修改，也没有进行Phase 9。新增一份独立特征测试用于隔离旧总表夹具问题与当前入口行为；没有新增测试框架或运行抽象。

### INPUT_MATRIX

完整证据：[190项输入/故障结果](../test/work/test_config_input_matrix-p4zzrewj/phase8-matrix/INPUT_MATRIX.md)、[完整返回值、错误文本和文件哈希](../test/work/test_config_input_matrix-p4zzrewj/phase8-matrix/INPUT_MATRIX.json)。记录4个入口×43组输入=172项；另18项故障注入。以下为压缩索引，具体错误文本/调用阶段以JSON为准，不能仅凭异常类型判断等价。

| 输入 | incremental_import | Store.load | Store.validate / save |
|---|---|---|---|
| 完整当前分表、附加JSON字段 | 接受 | 接受 | 接受 |
| 损坏manifest JSON | JSONDecodeError | 构造时JSONDecodeError | 同左 |
| 缺manifest / 空对象 / 空数组 | ValueError | FileNotFoundError / KeyError / TypeError | 同左 |
| sheets缺失 / null / 数组 | ValueError / AttributeError / AttributeError | KeyError / TypeError / TypeError | 同左 |
| 必需映射缺失 | ValueError | 构造时KeyError | 同左 |
| 路径空串 / null / 数字 | ValueError / ValueError / TypeError | PermissionError / TypeError / TypeError | 同左 |
| 父路径、反斜杠、绝对路径 | ValueError | ValueError，错误文本/时机不同 | 同左 |
| 缺文件 / 文件中缺预期sheet / 损坏xlsx | 包装为ValueError | FileNotFoundError / KeyError / BadZipFile | 同左 |
| charge缺映射、文件存在 | 接受 | 接受 | 接受 |
| ship缺映射、文件存在 | 接受 | KeyError | 同左 |
| charge或ship映射null / 空串、回退文件存在 | 接受 | TypeError / PermissionError | 同左 |
| charge缺映射和文件、JSON已有投影 | ValueError | 接受 | 接受 |
| charge缺映射和文件、JSON无投影 | 接受 | 接受 | 接受 |
| ship缺映射和文件、JSON有 / 无投影 | ValueError / 接受 | KeyError / KeyError | 同左 |
| 目标JSON缺失 / 损坏 | 接受并创建 / JSONDecodeError | FileNotFoundError / JSONDecodeError | 同左 |
| 损坏导入缓存 | JSONDecodeError | 接受 | 接受 |
| 有效缓存 / 旧版本 / 错误target_hash | 接受；有效缓存不解析不写入 | 接受 | 接受 |
| 非法生命、重复ID、坏敌群引用 | ValueError | 接受 | ValueError |
| 非法size、抗性、武器引用、掉落资源 | 接受 | 接受 | ValueError |
| 真实公式单元格缺XML数值缓存 | ValueError | 接受 | ValueError |

所有普通拒绝及Store.load/validate均验证文件内容不变。成功时，增量导入只可能写JSON/导入缓存，不写Excel/manifest；Store.save按现有逻辑写编辑表、JSON、缓存与备份，不写manifest，具体写入集合按各行记录。已验证有效缓存增量导入连mtime也不变。完整返回结构保存在JSON，不用统一错误接口替代。

“重构前/后”相同：**没有生产修改**，矩阵记录的三个tools文件SHA-256与最终源码核对一致；没有声称对某个改写版本做过差分。full_import另运行旧总表缺techPointGet拒绝与不写目标验证；没有用猜值制造可接受总表，也未完成其所有可接受总表组合的验证。

### SHARED

本阶段新增共享逻辑为0。既有read_changed_file、validate_projection、atomic_batch及指纹/编码工具继续复用，不重复抽取。

### KEPT_SEPARATE

- A12的manifest读取：缺失、空值、结构错误的异常类型与时机不同，不能直接用read_json替换Store构造逻辑。
- 分表发现：charge/ship可选规则不同；用统一函数需要策略开关，违背净复杂度要求。
- 路径及存在性检查：表面相近但空值、目录、缺文件及错误包装不同。剩余单行路径拼接的抽取不能减少理解成本。
- Store.snapshot/prepare/save与增量指纹/提交前复核不同；full_import另用单目标替换，不合并事务模型。

### VALIDATION

A13 KEEP：原有通用投影校验保持共享；编辑表ID校验的时机与上下文、敌机外观/抗性、武器引用、掉落资源仍由Store负责。即使重复ID等最终都拒绝，也没有证明其全部输入范围、错误语义和调用时机等价，不增加普通导入的拒绝条件。

### TRANSACTION

逐项记录替换顺序。增量提交目标JSON→缓存；Store先备份再提交编辑表/JSON/缓存，回滚按完成顺序逆序恢复。暂存失败与缓存替换失败且恢复成功时，原文件全部恢复、无临时文件残留。成功Store保存的备份与写前原始字节一致。

**恢复本身失败时，当前实现不满足“失败不得半提交”。** 两条写入入口均抛RuntimeError并可能遗留修改过的JSON；Store备份也可能在回滚中删除。测试明确观察此既有行为，不把该用例通过当作事务安全认证。问题唯一记录于U-019，未擅自修复。

### PROJECTION

隔离修改mon.health，仅解析mon、仅改变enemies投影；其他JSON字段（含未知字段）逐值相等。source_files仍为原有路径行为，完整返回保留于矩阵；CACHE_VERSION=4、target_hash及每个source hash逐项核对。Store保存生成的缓存被下一次增量导入接受且不解析。没有修改正式投影或源数值。

### EXCEL

Store隔离编辑level两项公式，验证ROUND(1.005,2)=1.01及D4/3的Decimal→float引用边界；公式文本和XML数值缓存匹配。其他分表整文件字节相等，目标xlsx的ZIP成员名称/顺序相同，非目标worksheet部件逐字节相同，备份是原始完整字节。没有修改公式求值器、XML缓存算法、workbook格式或ZIP实现。此为指定样本验证，不宣称穷尽Excel公式语言或ZIP压缩细节的所有组合。

### FAILURE_CASES

- 损坏manifest、缺表、错误路径、坏引用：类型、全文、阶段和文件副作用见矩阵；不同入口差异保留。
- 源文件并发变化：增量拒绝，Store.save拒绝；只留下注入的外部修改，没有本次提交。
- manifest/目标并发变化：增量仍提交，目标外部新增字段被覆盖；Store.save拒绝并保留外部修改；Store.validate没有提交前最终检查，返回成功但不写。见U-020。
- 暂存失败、提交失败及恢复失败：18项故障组合包括只校验入口不触及写入注入点；恢复失败的危险结果如TRANSACTION所述，未隐藏也未修复。

### FORMAL_INPUT

正式总表、9份分表、game_data.json及manifest共12份，SHA-256与既有正式输入基线全部一致；核对证据在[formal-input-hashes.json](../test/work/refactor-phase8/formal-input-hashes.json)。本轮测试只写test/work隔离副本，没有操作正式玩家存档、正式缓存或正式备份。

### TEST

- 独立矩阵：172项输入结果、18项故障结果，212项断言通过；日志见[Phase 8 UTF-8运行日志](../test/work/refactor-phase8/matrix-utf8.log)。首次完整回显曾因GBK编码失败，改为进程环境PYTHONUTF8=1重新运行，不改运行器或生产实现。
- 既有test_level_editor.py：8项通过。
- 既有test_config_workbooks.py：14项中4项通过、10项因旧总表techPointGet缺失报错；test_import.py同原因在初始导入失败。原正确断言未改，没有带着失败叠加生产重构。日志在[基线目录](../test/work/refactor-phase8/)，问题见U-018。
- 未改UI/游戏代码，未重复执行Phase 6的QA/重启或游戏专项；本阶段完成Store读取→校验→保存→重载和后续增量缓存验证。不能宣称全仓测试全绿。

### BEHAVIOR_DIFF

生产行为变化为0。观察到的入口差异及异常风险均来自原实现。没有合并、加强验证或调整错误处理；没有全项目重写。

### CODE_DIFF

生产代码新增/删除0行，运行文件数量变化0；新增一份321行独立输入矩阵测试，未删除或放宽既有断言；文档更新检查点、状态、风险和测试入口。测试专为当前分表与故障观察独立存在，避免混用U-018历史总表夹具。文件总数净增1，仅测试文件。

### COMPLEXITY

运行复杂度、依赖、调用链和运行开销均未变化，不声称代码缩减收益。得到可按需查询的入口证据，后续AI无需为A12再次通读三条完整链路；增加测试阅读成本，默认只读本节结论，完整矩阵留在test/work按需读取。未引入mode/strategy/policy等策略参数。

### RISKS

U-018/U-019/U-020仍在；尤其不能保证恢复失败原子性和多写入者安全。本次KEEP并不意味着这些风险已消除。故障模拟覆盖指定调用点，不替代断电、磁盘损坏或操作系统权限全部组合；完整旧总表正向导入仍受真实字段缺失阻碍。

### PHASE9_CANDIDATES（仅候选，未测量/未实施）

| 当前入口 | 获批后值得测量的指标 | 不得破坏 |
|---|---|---|
| main._process、refresh_scientists及进度/按钮刷新 | 每帧调用次数、耗时中位数/P95、稳定状态重复计算 | 即时可点击、暂停、拖拽与文本变化 |
| main.on_event→call_deferred(build_ui) | 同帧重建次数、分配量、UI帧耗时 | 事件顺序、滚动、弹窗、页签解锁 |
| game.weapon_entries/stat与database.enemy_weapon | 同tick重复查询/数组分配占比 | 槽位独立、装备变化即时生效、敌武器规则 |
| game.tick/tick_projectiles | 固定敌舰/弹体数量下P95与遍历次数 | 同帧击杀换靶、时间推进、资源/生命计算 |

只有实测显著且复杂度净下降才考虑修改；当前停在CHECKPOINT 4，等待批准，不进入Phase 9。

## 11. CHECKPOINT 5 — Phase 9（2026-09-15）

### BASELINE

Phase 9A先完成测量与排名，再进入9B。完整[PERFORMANCE_BASELINE](../test/work/phase9-baseline-final-_urn6lcv/PERFORMANCE_BASELINE.md)包含全部场景frame/tick median/P95、逐类UI耗时、build及同帧重复、weapon_entries/stat/DB/scientist MAX/索敌排序/弹体遍历/save计数。每轮原始统计在同目录raw-0～2.json、instrumented-0～2.json及results.json，不能只取最快一次。

固定当前JSON、随机种子1701、1440×810、Godot 4.7.2 GL Compatibility、RTX 2060、关闭VSync；每组预热30帧、采样120帧，三次独立进程。驱动以固定delta=1/60调用原main._process，1/2/5X仍由生产代码细分。frame为调用至下一process_frame的墙钟间隔，含渲染/调度；不等于纯GPU耗时或自由运行FPS。偶数样本median取上中位数，P95取nearest-rank；汇总使用三轮统计值的中位数。

IDLE、NORMAL、FULL_LOADOUT、HEAVY_COMBAT、UI_EQUIPMENT、UI_SCIENTISTS（含科技）、UI_CHARGE、LARGE_VALUE、LARGE_SCIENTISTS、INCOME_60S均测1X/2X/5X，共30组；另有离线与实际保存样本，各轮预热5次后采30次。以下为5X索引，其余倍速及tick详见完整基线，单位ms：

| 场景 | frame median / P95 | main CPU median / P95 |
|---|---|---|
| IDLE | 5.322 / 6.750 | 1.293 / 1.642 |
| NORMAL | 6.874 / 9.191 | 1.544 / 1.856 |
| FULL_LOADOUT | 13.254 / 16.198 | 4.821 / 5.933 |
| HEAVY_COMBAT | 13.622 / 17.279 | 4.912 / 6.675 |
| UI_EQUIPMENT | 5.745 / 7.033 | 1.485 / 1.724 |
| UI_SCIENTISTS | 5.952 / 7.359 | 1.561 / 1.852 |
| UI_CHARGE | 5.955 / 7.430 | 1.450 / 1.749 |
| LARGE_VALUE | 12.188 / 14.163 | 7.754 / 8.926 |
| LARGE_SCIENTISTS | 8.246 / 246.131 | 3.579 / 3.920 |
| INCOME_60S | 5.669 / 7.715 | 1.528 / 2.249 |

离线median/P95=15.500/19.607ms；真实隔离保存=1.753/2.210ms。非IDLE/NORMAL夹具解锁当前70关；满装为8武器槽+4防御槽，符合同类限制；重编队由当前配置选取，实测最多6敌舰、20弹体。大资源为1e100；大量科学家为100万人、1000人研究；收入窗口用240个样本；离线为100人研究、当前4小时上限，充能任务未启动。所有写入均在test/work，不改正式输入或玩家档。

试跑未混入基线：先有超时与离线UI监听夹具问题；随后定位临时Engine元数据未清理导致退出异常。最小探针移除元数据后退出0，最终测量器同样清理。最终before及after各6个完整进程全部退出0。源码/配置均来自隔离副本；插桩包含子调用及记录开销，仅用于归因，不能直接替代raw收益。

### RANKING

| 等级 | 候选与决定 |
|---|---|
| HOT，优化 | 科学家MAX可用性：LARGE_VALUE中反复完整枚举，占据明显帧预算，可只判断首个付费购买，保持原购买算法 |
| HOT，保留 | 满装装备MAX刷新，约2.1～2.2ms/帧（插桩包含子调用）。不能直接替换为can_upgrade_slot：空成本、整数转换等边界未证明等价；不增加策略参数或缓存来强行优化 |
| HOT，保留 | 实际build_ui重建成本，详见U-021。观测31次重建而非重复重建；局部刷新需增加控件维护与事件验证，本轮不扩大改动 |
| WARM | hightech/charge/装备按钮和描述、DB查询、tick及tick_projectiles；有可测成本但没有已证明复杂度净下降的独立修改。不能把嵌套耗时重复算作收益 |
| COLD | weapon_entries/stat、索敌排序/导弹占用、收入统计、当前离线与保存样本：本次规模下不值得引入状态或索引；低频保存不因耗时而延迟 |
| COLD | on_event→同帧deferred合并：全部场景同帧额外重建为0，明确不实施 |

### OPTIMIZED

仅`game.can_generate_scientist(amount<0)`：用`scientist_purchase(1)`确认首人可负担，再检查首人至少有一项正费用。旧MAX遇到全部免费首人会返回0，此语义仍保留。正数量查询和`generate_scientist(-1)`实际购买流程保持不变；没有新增价格公式、状态或接口层。

### REVERTED

没有生产优化被撤回：只实施上述一个候选并通过保留门槛。UI同帧合并和其他热点在修改前就因无重复证据或复杂度/行为风险取消，没有把未尝试内容冒充回退。失败的测量试跑已排除，不算优化成果。

### PERFORMANCE

同一探针逐字节一致，前后源码哈希仅game.gd不同；配置哈希相同。[完整before/after](../test/work/phase9-after-scientist-asjbrfwo/PERFORMANCE_RESULT.md)记录全部30组及各轮范围，以下为LARGE_VALUE，单位ms：

| 倍速 | raw main CPU median/P95 前→后 | raw frame median/P95 前→后 | refresh_scientists median/P95（插桩）前→后 |
|---|---|---|---|
| 1X | 7.550/9.129 → 3.311/3.905 | 12.058/14.309 → 7.878/9.319 | 5.711/6.141 → 0.173/0.217 |
| 2X | 7.587/8.686 → 3.290/3.885 | 12.098/13.916 → 7.896/9.961 | 5.687/6.679 → 0.173/0.209 |
| 5X | 7.754/8.926 → 3.305/3.548 | 12.188/14.163 → 7.616/8.765 | 5.685/7.720 → 0.175/0.215 |

5X三轮CPU median分别为7.754/7.648/7.762→3.304/3.305/3.306；frame median分别12.188/12.026/12.249→7.616/7.844/7.600，区间不重叠。没有将其他场景的小幅波动归功于优化。大量科学家场景的frame P95仍约248ms，其全量重建问题没有消失。

### BEHAVIOR

修改前后可购买性专项1009项通过，涵盖正数/MAX/负数别名、锁定、多资源、免费与费用递减、大数、profile深比较和暂停时按钮即时更新。修改后科学家63项、大数11项通过；没有修改已有正确断言。行为专项通过后才开始性能复测。

三轮逐场景比较，tick、tick_projectiles、targets、missile_target、weapon_entries、stat、save_progress、build_ui调用数，以及排序/弹体/导弹占用遍历数全部一致。它们是辅助证据，不能替代规则断言。生产diff只涉及可购买性读取，没有改时间步进、伤害/资源公式、冷却、事件、UI结构、拖拽、滚动、保存承诺或旧档迁移；未发现行为差异。

### ALLOCATIONS

LARGE_VALUE每120帧，scientist_cost调用104400→1800，减少102600次费用计算；完整MAX枚举120→0。can_generate_scientist与scientist_purchase总调用均360→360，refresh_scientists仍120→120，因此不是跳过UI刷新。每个费用调用创建的费用字典随调用减少（代码可推导），没有可靠测量总分配字节、峰值内存或GC收益；不把临时插桩数组算成游戏分配。

### CACHE

没有引入缓存。`first`仅当前调用的局部结果，无跨帧生命周期、失效规则或第二状态源。测量器只存在于测试副本，退出前移除Engine元数据，不进入生产场景。

### CODE_DIFF

运行代码仅game.gd净增4行，未删行、未增加运行文件；测试新增3份，共308行：专用启动器102、隔离探针156、可购买性专项50。无通用Profiler/Manager/Service。其余为检查点、状态、风险及测试入口文档；具体提交diff可回退。

### COMPLEXITY

仅增加一个负数量分支和首人非免费判断；价格/舍入/资源判断仍调用已有权威计算。复杂度代价小，布尔查询不再按可购买人数循环，无缓存失效或跨模块同步。**KEEP**：收益可重复、行为专项通过、未明显增加运行复杂度。

### TOKEN_IMPACT

未来理解MAX按钮无需追踪整次批量购买循环才能判断性能；边界注释解释免费首人的特殊语义。测试工具仅性能任务按需读取，常规任务不读完整矩阵；没有宣称测得AI Token百分比。

### RISKS

U-021及装备MAX刷新仍是剩余热点。测试是固定步长/指定配置的同机比较，不代表所有硬件、无限敌人、全部进度或活动充能的性能；实际分配字节未可靠测量。U-018/U-019/U-020原样保留，本阶段未处理数据正确性/事务问题。

正式12份输入SHA-256与Phase 8基线全部一致，[哈希证据](../test/work/phase9-after-scientist-asjbrfwo/formal-input-hashes.json)。实测存档位于隔离userdata目录；没有读取或写入正式玩家档。根证书提示为既有环境信息，测试和完整测量进程正常退出。

### NEXT

本次修改具备进入Phase 10核心规则测试复核的直接验证基础，无未解决相关失败；后续仍须用户批准。**Phase 9完成后停止，未开始Phase 10。**
