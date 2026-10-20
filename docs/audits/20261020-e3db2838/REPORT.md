# space_idle 独立代码审计

审计基线：远端 main，`e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3`（本次读取时的 HEAD）。原工作区为 `d2293ce92733766b51bd1aa4f54bec6ea265fd0f`，未切换、未修改其项目代码。远端版本在 `/tmp/space-idle-audit` 独立解包检查。

## 总体结论

项目有明确的领域拆分意图，并已有实质性的防护：存档临时文件校验与恢复副本、异空间状态验证、原生执行器能力准入与状态交接、配置源校验、启动器源代码/二进制指纹，以及大量专项测试。不能把它概括为“完全没有架构或测试”。

但当前版本存在可以独立复现的损档、发布阻断及成长数值错误。最突出的问题不是代码风格，而是跨模块契约不一致：不同保存入口维护不同字段集；大数能力没有贯穿成本与容量；领域变更依赖调用者手工失效缓存；发布脚本维护另一份运行依赖清单。建议先修下列 P1，再处理 P2 和结构治理，不建议先开展大规模重写。

P1：损档、有效成长规则失效或标准发布流程阻断，应在下一次分发前修复。P2：特定边界、故障恢复或质量门禁缺陷，应进入近期修复。

## 已核实的问题

### A01 / P1：导出、导入和“当前进度备份”静默删除 AI 科技等有效状态

位置：`space-battleship/scripts/save_transfer.gd:8`、`:55`、`:121`、`:142`、`:177`；对照 `scripts/game.gd:189` 和 `:587`。

`schema()` 没有收录 `aiTechLevels`、`aiTechProgress`、`aiTechActive`、`aiTechInput`、`aiIncomePeak`、`aiTechCompletionUnread`、`productionElapsed`、`equipmentSwitchUntil`。`clean()` 会丢弃所有不在白名单中的字段，而导出、导入预处理及导入前的 current-progress.json 备份都使用它。resourceSamples 中的 `production_time` 也不在该样本的白名单里。

复现：构造含 singularity 等级 3 的当前有效游戏进度，调用正式 portable_save_data → prepare_data → load_progress_data。prepare_data 返回空错误，但恢复后的 aiTechLevels 为 `{}`。对保存对象做字段差集，正好出现上述八个顶层字段。

影响：玩家导出后换机、主动导入普通存档，或使用导入前的“当前进度”备份恢复时，科技投资/研究进度和收益峰值被清空；换装期限与生产时间域也失去对应状态。正常自动存档本身包含这些字段，因此这属于传输边界的数据丢失，不应描述为“所有保存都丢科技”。

方向：建立统一、版本化的持久状态契约，让普通保存、便携导出、预览、备份和恢复共享字段定义。保留严格清洗，但明确区分持久字段和本地元数据。增加覆盖每个持久字段的完整往返比较，尤其验证新科技、生产时间和冷却期限。

证据：`probe_integrity.log`。现有 `test_save_transfer.gd` 的 58 项检查全部通过，却未覆盖该问题。

### A02 / P1：主存档只要有合法 version 就被视为有效，后续保存会覆盖真正的恢复备份

位置：`scripts/progress_writer.gd:75`、`:104`、`:28`；`scripts/game.gd:350`、`:362`。

`_read_progress_file()` 对没有 hyperspace 字段的对象只检查 version；未验证核心结构、必需字段及整体可加载性。`read_progress()` 优先返回这个主文件，因而忽略有效 `.bak`。`load_progress()` 又以 hyperspace.last_error 判断加载是否成功，无法识别这类缺失。

复现：`.bak` 放完整进度，主文件放 `{"version":5}`。启动接受主文件，`save_enabled=true`、`startup_error` 为空，资源变为 0、最高关卡变为 1。随后执行正式 save_progress，原有效 `.bak` 被删除，新的 `.bak` 内容变成 `{"version":5}`。

这是“语法有效、语义残缺”的存档，不是声称正常截断写入一定产生该对象。非法 JSON 已有防护，但这个防护不覆盖合法 JSON 的结构损坏。

方向：在选择主文件或恢复副本前，先做完整的、无副作用的版本迁移与语义校验；加载器返回明确成功/失败结果。失败时保留现场、禁用覆盖保存，选择经过相同校验的恢复副本。不要依赖某一个子系统的错误字段判断整份存档。

证据：`probe_integrity.log` 的 CORRUPT_START、AFTER_SAVE 输出。

### A03 / P1：发布 staging 清单缺少当前启动必需的数据文件

位置：`tools/build_release.ps1:132`；`scripts/database.gd:19`、`:22`；`scripts/hyperspace_reward_binding.gd:12`。

发布脚本只复制固定的 12 个 JSON，缺少 `ai_tech_tree.json`、`equipment_evolution.json`、`space_enemy_reward_early_frozen.json`。前两项由 ShipDatabase 初始化无条件读取；第三项由奖励/冻结配置契约要求。export_presets 中的 data/*.json 无法补救 staging 根本没有的文件。

复现：按发布脚本的实际 JSON 清单构造独立 staging，使用未修改的当前脚本初始化数据库与 BattleGame。输出 ai_tech_tree=null、equipment_evolution=null，随后 startup_error=`invalid_hyperspace_config_pack`。

影响：标准发布路径缺少运行依赖。构建脚本本身会扫描错误并停止，因此不能据此宣称“损坏 EXE 已经成功分发”；结论是当前发布脚本不能据此清单生成有效的当前游戏。

方向：统一维护运行资源依赖清单，由发布 staging 和验证共同消费；构建前检查必需项、版本和散列，构建后从实际包内初始化数据库、创建新游戏并执行存档重开。避免手工复制清单与代码依赖长期分离。

证据：`probe_release.log`。这是 Linux 下对 staging 依赖的复现，并非 Windows 完整打包测试。

### A04 / P1：反应炉在现行配置下升至 98 级后容量归零

位置：`scripts/game.gd:1182`、`:1186`、`:1220`。

reactor_energy 使用浮点指数成长，reactor_capacity 直接 `int(floor(...))`。容量没有进入 GrowthNumber 体系，也没有在交易前验证是否处于 int64 安全范围。

复现：当前基础参数为 100 × 1.5^(level−1)，无额外能源乘数时，97 级约 8.0308e18，98 级约 1.2046e19。给定足够且有限的资源，调用正式 upgrade_reactor(1)，97→98 返回 true，但容量变成 0。额外能源倍率会使边界提前。

影响：合法升级后充能容量与分配计算失真，免费充能效果也失去容量基础。这不是需要达到 float 上限才出现的问题。

方向：先明确容量与分配的数值契约。若成长无设计上限，应把容量、分配、剩余量、比例计算一起迁到能覆盖该范围的表示；若必须使用有界整数，应在扣费前拒绝越界，并取得明确的设计上限依据，不能把隐式溢出当作玩法上限。测试加入 97/98 级及乘数提前触发的边界。

证据：`probe_reactor.log`，包含真实升级调用的 `ok=true level=98 capacity=0`。

### A05 / P2：升级反应炉后，免费充能影响的装备基础属性缓存未失效

位置：`scripts/game.gd:1141`、`:1220`、`:1230`，以及 `_compiled_configuration_event` 和 `crew_system.gd:on_event`。

upgrade_reactor 更新等级并发送 reactor_changed，但没有失效 stat_cache。equipment_stat 会缓存包含 reactor_multiplier 的基础属性。已有星球免费充能奖励时，等级改变容量，继而改变免费充能加成；当前事件处理并不会替代这次缓存失效。

复现：使用当前配置、第一颗星球征服奖励、缓存开启，先读取 laser 一级属性，再调用反应炉 1→2 升级。容量 100→150，缓存版本仍为 4；缓存值仍为 223251，手工仅失效缓存后同一属性变为 228328。没有修改配置表，也没有改装备等级。

影响：面板/战斗可继续读取旧加成，直到另一个操作触发全量缓存失效；不是永久不可恢复的损档。

方向：让“升级反应炉”作为完整领域事务拥有依赖失效和通知；对容量、免费充能、装备基础属性和原生配置建立明确依赖。增加开启缓存、激活免费充能奖励后的升级前后对比，而不仅测试默认无奖励状态。

证据：`probe_reactor.log`；现有 reactor 和 stat_cache 专项均通过。

### A06 / P2：配置事务回滚失败时，恢复材料仍被删除

位置：`tools/config_workbooks.py:41`、`:54`、`:69`；`tools/level_editor_store.py:238`。

atomic_batch 在安装失败后尝试逆序恢复；恢复失败会记录 problems，但 finally 仍删除所有临时文件。关卡编辑器把备份和正式文件放进同一批次，回滚时新建备份也会被删除。

故障注入：先写入旧版本备份，再成功替换 A，替换 B 时抛出 OSError；再让 A 的恢复替换失败。函数正确抛出 RuntimeError，但最终 A 是 NEW_A、B 是 OLD_B，备份文件不存在，所有 .tmp 也消失。

影响：磁盘、权限或占用故障的组合条件下，配置处于部分提交状态，程序还清理了用于人工恢复的材料。不是普通一次 replace 失败就必然丢数据；现有单失败回滚测试通过。

方向：备份应独立持久提交，回滚失败时保留恢复临时文件及事务清单，并返回明确 recovery_required 状态和路径。多文件发布可采用版本目录加单一指针切换，或实现可恢复日志，不能只凭函数名 atomic_batch 推断跨文件事务原子性。

证据：`probe_atomic.py`、`probe_atomic.log`。与仓库已登记的 U-019 一致，本次做了独立复现。

### A07 / P2：大数支持没有覆盖装备成本，产生未声明的成长硬上限

位置：`scripts/database.gd:68`、`:88`、`:116`；`scripts/game.gd:899`、`:921`、`:2692`。

装备伤害/耐久已支持 GrowthNumber，但 equipment_cost 仍依赖返回 float 的 equipment_growth；批量费用也使用 float 累加，购买逻辑拒绝所有非有限成本。与此同时 max_equipment_level 返回 2147483647，并注释没有玩法上限。

复现：当前 laser 和 armour 的第 3873 级成本为 `{"1":inf}`。即使资源是合法的 `{m:1,e:400}`，购买判断仍直接拒绝。更早的批量总价也需要单独检查累加溢出，不能只检查单级价格。

方向：成本、批量求和、扣费、比较、报价缓存及 UI 一起使用统一大数契约，并保留已批准的原有取整规则。若实际玩法需要上限，应显式设计、展示和验证，不应由浮点溢出偶然决定。

证据：`probe_integrity.log`。该问题与反应炉 int64 容量溢出是两类不同边界。

### A08 / P2：统一测试入口仅检查退出码，可能把 GDScript 运行错误报为通过

位置：`test/run.py:74` 至 `:84` 及末尾返回路径。

runner 记录日志后直接返回子进程退出码，没有判断 GDScript runtime/parse 错误或要求结构化完成标志。Godot 的脚本错误并不必然导致非零退出。

最小复现：deferred 函数访问 Dictionary 的不存在字段，Godot 输出 SCRIPT ERROR；另一个 deferred 收尾函数仍执行 quit(0)，进程退出 0。按当前 runner 的返回逻辑，这会被当作成功。发布脚本已经检查错误日志，但通用测试入口没有同等门禁。

方向：统一测试协议，检查退出码、预期完成标志、断言失败数和未预期的脚本/解析错误。故障注入专项确实可能预期错误输出，应使用显式精确标记或白名单，不能简单忽略全部日志错误。

证据：`probe_test_gate.gd`、`probe_test_gate.log`，包含 SCRIPT ERROR 和 EXIT_CODE=0。

## 架构修改方向

1. **先统一数据边界。** 将持久状态定义、迁移、纯校验、导出清洗和恢复验证收敛为同一个版本契约。不要简单取消导出白名单，也不要用会修改 live state 的加载函数充当校验器。
2. **收敛变更入口。** 领域命令统一拥有校验、扣费、状态更新、缓存版本和事件发布。先修反应炉这类有证据的依赖，再逐步减少外部直接修改 profile，而不是一次性替换全部 Dictionary。
3. **统一数值策略。** 明确普通 float、大数、计数器和有界索引的边界；逐项审核所有 float/int 转换。强化费用已有大数几何求和与二分查找，可作为其他增长系统的参考，但必须保持各系统已批准的取整。
4. **分解大文件应围绕责任。** 当前 scripts 有 156 个 .gd、约 39,357 行；game.gd 4,476 行、main.gd 4,049 行。优先提取保存/迁移、经济交易、战斗调度和 UI 页面协调。行数不是独立缺陷，真正风险是同一状态在多个入口重复解释，已由 A01/A05 体现。
5. **双战斗执行器保留明确契约。** GDScript 与 C++ 共存具有性能价值，当前已有准入拒绝和交接机制。应针对相同种子、目标顺序、伤害、掉落、RNG、升级中断和数值越界跑同源差分测试；不要仅比较最后是否通关。此次没有执行 Windows 原生 DLL，不能对两者全局等价作保证。
6. **发布与测试共用运行依赖。** 为实际 staging/PCK 建立启动、新建进度、跨系统存档往返门禁，避免开发工程完整而发布包缺项。

## 验证结果与边界

环境：Linux，Godot `4.6.3.stable.official.7d41c59c4`；项目指定 Windows `4.7.2.stable.official.ed1daf0bf`。以下属于本环境的可重复结果，不能代替目标 Windows 引擎、原生 DLL、真实显示/GPU 和最终 EXE 验收。

未修改项目代码。Godot 导入、测试用户目录和所有注入故障仅位于隔离副本或 /tmp。最终原工作区 `git status --porcelain` 为空。已有测试在同一隔离源快照上逐项启动独立进程和用户目录，以复用素材导入；没有使用真实玩家存档。

| 专项 | 本次结果 |
|---|---|
| test_save_transfer.gd | 58 checks，0 failures |
| test_large_numbers.gd | 14 checks，0 failures |
| test_state_ownership.gd | 1,282 checks，0 failures |
| test_stat_cache.gd | 9,177 checks，0 failures |
| test_ai_tech_tree.gd | 49 checks，0 failures |
| test_hyperspace_state.gd | 284 checks，0 failures |
| test_time_steps.gd | 151 checks，0 failures |
| test_module_refit.gd | 48 checks，0 failures |
| test_reactor.gd | failures: 0 |
| test_projectile_iteration.gd | 8 checks，0 failures |
| test_rule_rounding.gd | 19 checks，0 failures |
| test_missile_retarget.gd | 71 checks，0 failures |
| test_level_editor.py | 10 tests，通过 |
| test_player_entry.py | 17 tests，通过（恢复隔离副本 Git 元信息后重跑） |
| test_save_policy.gd | 48 checks，4 failures（按测试要求修正隔离目录后重跑） |
| test_config_workbooks.py | 14 tests，1 error |

合计 16 个现有专项，14 个通过、2 个未通过；另有 5 个针对性审计探针，不能将探针退出 0 等同于被审计功能正确，需看其观测值。所有通过的 GDScript 专项还核对了日志中无 SCRIPT ERROR。

未通过专项的解释：save_policy 涉及“时间戳重载精确相等”、强化购买、分支与重载联动；其强化夹具只给 1e9 碎片，而当前第 31 级费用为 100×2^30≈1.0737e11，至少这一失败存在明显夹具/现行配置不一致。config_workbooks 的 test_hightech_limit_and_offline_max_validation 因 level.xlsx!D4 缺公式计算缓存报错。没有把这些测试失败直接计作已确认的玩法缺陷；应修复夹具、区分机制测试与配置验收，再恢复可靠门禁。

未完成的验收：Windows 发布全链路、官方指定版本回归、native DLL 实际运行、真实 GPU/UI 操作、自然新档长时数值平衡、多实例写档压力及所有历史专项的全面执行。项目量级超过一次人工审计可逐路径穷尽的范围；报告是全项目结构审查加关键高风险链路验证，不宣称全部 311 个 GDScript 测试和 33 个 Python 测试已执行。

另一个待专项验证的风险是多实例共享 progress.json：导入有 owner marker，但普通保存仍使用固定 .tmp/.bak 路径且缺少进程级锁/提交代号。此处仅列为静态风险，未将它计入八项已核实缺陷。

## 建议实施顺序

- 第一批：A01、A02，先确保导入、恢复、备份不会损失进度；同时修 A03 发布依赖。
- 第二批：A04、A05，保障反应炉正常成长和实际战斗属性一致。
- 第三批：A06、A07、A08，完成可恢复配置事务、大数成本闭环和可靠测试门禁。
- 每项先添加针对本报告复现的失败测试，最小修复后执行相关专项；最后在 Windows 指定引擎和实际发布包上复验。不要把独立 Linux 逻辑通过当作 Windows 发布批准。

附件目录：`/workspace/space-idle-audit-evidence/`。报告和证据均位于原仓库外。
