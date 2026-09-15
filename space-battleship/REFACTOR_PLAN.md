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
