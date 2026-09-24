# 船员系统（第一版）

## 范围与来源

船员、升级、岗位、模块效果、存档与 UI 已接入。2026-09-22 初版只提供经验 API；2026-09-23 星球探索开始发放经验。装备仍只预留，不提供掉落、背包、属性、强化或套装。

新增三个独立分表，沿用 `config_excel → config_workbooks/import_workbook → game_data.json → ShipDatabase.data`，不另建配置系统。前三行为字段、说明、空行，第 4 行起数据。日常编辑分表后使用 QA「读取配置」并重启，勿用旧总表覆盖分表。没有 manifest 条目时沿用可选分表发现；旧总表缺船员表时保留已有船员投影。导入失败不提交。

当前配置为六个无固定职务的船员、normal 1～3 级和四个系统分配项；成长/岗位数值采用用户示例，两格预留槽是本版初始配置，不代表平衡验收。船员默认待命，未分配不会改变原游戏数值。2026-09-22 用户后续确认：船员无职务区别；显示名称为船员01～06，前三个历史 crewId 保留为存档身份。装备系统统一每秒尝试全部模块，玩家选择升1级/10级/最大值。

### 船员解锁

用户指定六名船员依次通关10、20、25、30、35、40关解锁。统一编辑 `unlock.xlsx / unlock`，`type=crew`、`mode=cleared`；crew.xlsx 的 unlockId 只引用该记录，不重复保存门槛。

| 船员 | crewId | unlockId | 通关层数 |
|---|---|---|---:|
| 船员01 | navigator | crew/navigator | 10 |
| 船员02 | engineer | crew/engineer | 20 |
| 船员03 | researcher | crew/researcher | 25 |
| 船员04 | crew_04 | crew/crew_04 | 30 |
| 船员05 | crew_05 | crew/crew_05 | 35 |
| 船员06 | crew_06 | crew/crew_06 | 40 |

沿用既有“指定关卡已通关”判定，单纯到达不解锁；通关时进入现有解锁通知，授权状态沿原存档流程保存。旧档保留已有 crewId、等级、经验和分配；尚未满足新门槛的船员不产生效果，也不在页签标记中泄露信息，新增三名按配置初始化。

用户补充：第一名船员解锁前不显示船员页签，判定为至少一名船员满足其配置门槛，不把10写死在UI。页签开放后正常显示已解锁成员；未解锁部分只显示门槛最小的一张通用剪影与“通关第X层解锁”。不显示姓名、等级、职务、效果、提示详情或交互入口；更后面的成员不生成行。没有已解锁船员时隐藏详情及分配控件；全部解锁后隐藏剪影。复用单个预告控件和既有已解锁行，未改变时不重复写入或重排。剪影资源为 `assets/ui/crew_locked.svg`，提示KEY为 `crew.unlock_at`，层数来自unlock配置。

## Excel 字段

| 分表 | 字段与含义 |
|---|---|
| `crew.xlsx / crew` | `id, name, description, icon, baseLevel, maxLevel, basePower, expGroup, defaultAssignment, unlockId, equipmentSlotCount, baseExp, expGrowth`；另有可选 `defaultTargetId`，填写默认岗位时须成对填写 |
| `crew_level.xlsx / crew_level` | `group, level, needExp, powerMultiplier`；`needExp` 保留为逐级配置参考，实际升级经验由 crew 的 `baseExp` 和 `expGrowth` 计算；第 1 级为 0 |
| `crew_assignment.xlsx / crew_assignment` | `id, targetType, effectType, baseValue, levelScale, powerScale, interval, maxCrew, description, titleTextId, descTextId`；自动装备与自动AI岗位均用 `upgradeModes=1,10,max`；宝石岗位只需正数 `interval`，无需数量选项；可选 `targetCategory` 区分高科技具体项目和整个系统 |

`crew.id` 是唯一实例 ID。本版没有招募或同一配置的多个副本。全部配置实例初始化，`unlockId` 留空直接可用，否则读取现有 unlock 权限。未知 ID 不产生实例。

名称、船员说明和图标直接由 Excel 提供，属于用户指定的文案来源例外。岗位 `titleTextId / descTextId` 可引用现有文案表；两者留空时，标题使用 `description`，效果提示使用通用模板附带实际数值和间隔。因此复用已有行为的新岗位只改 Excel 即可。非空文案 KEY 必须存在，标题不能含参数，效果模板仅允许 `{value}`（百分数）、`{interval}`（秒）、`{description}`、`{mode}`（升级选项文字）。按钮、等级/经验标签、未开放提示在 `ui_text.json`，参数契约仍由 `ui_text_contract.json` 管理。

导入校验包含重复 ID、重复 group/level、缺失成长行、非有限/负数、等级上下限、正整数人数/槽数、自动岗位的正能力/间隔、默认岗位与 unlock 引用、文案 KEY/参数、效果运算溢出。未注册的目标/效果组合在 UI 禁用并提示，不执行任意配置代码。

## 动态数据与升级

```json
{
  "crewId": "navigator",
  "level": 2,
  "exp": 50,
  "assignmentType": "equipment_upgrade",
  "targetId": "equipment",
  "upgradeMode": "10",
  "equipmentSlots": [null, null]
}
```

`profile.crew` 为上述数组；只保存七个动态字段（本次增加 upgradeMode），不保存名称、图标、基础能力或岗位数值。`profile.crewEquipment = {}` 为预留结构。`crew.equipment_slots(game, id)` 返回独立槽数组；`crew.crew_equipment(game, equipment_id)` 预留查询返回空字典。本版槽位只允许空值。

`game.add_crew_exp(crew_id, amount)` 查询 crew.expGroup 与下一等级行；从当前等级升下一级所需经验为 `round(baseExp × (1 + expGrowth)^(当前等级−1))`。初始为100，此后120、144。逐级扣除，余量保留，达到 Excel 的 maxLevel 后经验归零。星球探索完成发放经验；拒绝负数、非有限经验及未知船员。加载时同样规范经验和等级。

效果公式仅在 `crew_system.effect_value`：

```text
value = baseValue × basePower^powerScale × powerMultiplier^levelScale
```

被动效果的两个指数配置为 1，等于需求中的 `baseValue × basePower × powerMultiplier`；指数 0 可关闭对应成长影响。数值全部读取 Excel。装备分配设置 baseValue=1、powerScale=0、levelScale=0、interval=1，因此任意等级均每1秒检查一次，不受成长加速。

## 岗位与行为

`game.assign_crew(crew_id, assignment_type, target_id)` 执行分配/更换；两个目标参数均传空字符串解除。一次仅一个岗位。当前四个岗位的 Excel `maxCrew` 均为 1；占用按「targetType + targetId」检查，不同岗位也不能重复占用同一系统目标。失败保持原岗位。

| 初始岗位 | 注册组合 | 目标 | 实际行为 |
|---|---|---|---|
| equipment_upgrade | equipment + AUTO_UPGRADE | 整个装备系统 `equipment` | 每1游戏秒按武器索引、再按防御索引遍历全部启用模块；依选项调用统一升级接口 |
| hightech_scientists（显示为“高科技”） | hightech + AUTO_SCIENTIST | 整个高科技系统 `hightech` | 每1游戏秒按船员选择的x1/x10/MAX调用 `generate_scientist`；仅购买成功后调用 `distribute_scientists` |
| jewel_auto（显示为“宝石系统”） | jewel + AUTO_COMBINE | 整个宝石系统 `jewels` | 每1游戏秒自动合成背包宝石，再把已镶嵌宝石升级或替换为同类型更高级宝石 |
| production_output | production + OUTPUT | 现有炼铁炉键 | 原产出乘 `1 + 聚合 OUTPUT + 聚合 EFFICIENCY`，最后沿用原向上取整 |

两个炉的 SPEED / OUTPUT / EFFICIENCY handler 仍已注册，现有配置只启用炼铁炉产出岗位。炉没有独立生产消耗，EFFICIENCY 与 OUTPUT 都是产出加成，两者加算；SPEED 独立改变周期。科研速率不再读取船员 EFFICIENCY；原离线近似规则未改。

`game.get_crew_modifier(targetType, targetId, effectType)` 聚合当前有效船员的加成，目标系统按需读取，不修改 Excel 投影或目标基础数据。未分配、未解锁、失效目标均贡献 0。

装备分配面向整个系统，不再选择单件武器/防御。每次遍历当前舰体启用范围，停用尾部不升级；空的启用模块仍按既有模块成长规则升级。1级与10级必须完整满足该次资源/条件，不足则跳过该模块、继续检查下一件；最大值先用 max_upgrade_amount_slot 计算，再调用 upgrade_slot。各模块按顺序使用剩余资源，不复制或绕过升级规则。

高科技岗位由原自动科学家岗位更名而来；旧 `hightech_efficiency` 配置已删除。当前 `baseValue=1, levelScale=0, powerScale=0, interval=1, maxCrew=1`，故等级不加快周期。购买量存于现有动态 `upgradeMode`，仍只有一个主要 assignment。x10 完整购买条件与原按钮相同；MAX 传 `-1` 给原购买接口，保留免费首人边界。购买失败不改变原科学家分配；成功后相当于自动点击现有“平均分配”，采用同样的槽位顺序、余额扣除、事件和存档流程。暂停和离线仍不推进自动购买。

宝石岗位取代原宝石熔炼速度岗位。每到 Excel `interval / effect_value` 秒，先线性扫描背包判断有无可合成组；无材料时不调用完整一键合成，也不保存或通知 UI。有材料时复用 `combine_all_jewels` 的配方、等级上限、保护标记、碎片补位和存档规则。合成后只处理已有孔位中未锁定、未停用的宝石：优先从背包换入**同 ID 且严格更高等级**的未保护宝石；否则在原位配方满足时复用 `upgrade_socket_jewel`。空孔不自动填充，不跨宝石类型换属性。所有变化复用正常镶嵌校验；同一轮多孔位只保存一次，并通过 `jewels_changed.slots` 仅刷新受影响装备卡片。满包仍允许等量交换。连锁合成按每轮分组批量结算，避免每个配方重扫整包；仍只在最终成功后提交、保存、通知。此岗位没有独立资源消耗，自动合成会消耗符合配方的背包宝石；自动原位升级也会消耗匹配材料。

调度器仅累计游戏时间，到期才做目标与升级条件检查；不逐帧尝试升级。暂停不推进。同一船员单次 tick 最多检查一次，大步长遗漏的周期不追补消费；离线不补自动升级。切换/解除分配重置该船员时钟（仅修改升级选项不重置），时钟不写存档，重启从完整周期开始。

## 扩展

`crew_system` 持有 `targetType → target provider` 与 `targetType + effectType → Callable` 两个注册表。AUTO_UPGRADE 适配现有升级入口；被动 handler 供统一聚合读取。核心不按岗位 ID 写分支。

例如只编辑 crew_assignment，复制 production_output，改成 `id=smelting_output, targetType=smelting, effectType=OUTPUT`，调整倍率、上限和描述；titleTextId/descTextId 留空或复用既有 KEY。导入重启后，岗位选项、具体目标、实际效果、人数限制与提示自动出现，无需修改 UI 或船员核心。

新游戏模块需提供现有对象 ID 列表，并通过 `register_target` 接入；已有被动行为可复用 `register_handler(..., crew.passive)`，由目标模块读取 get_crew_modifier。只有新行为才编写 handler。不承诺仅靠 Excel 创造尚不存在的游戏模块或其执行行为，船员核心无需修改。

## UI 刷新与旧档

船员页签位于现有页签之后。点击船员，选择分配系统；装备系统显示1级/10级/最大值选项，高科技系统显示AI购买数量，宝石系统选择唯一目标 `jewels`；点击分配；装备只显示未开放槽数。分配标记只在对应系统页签标题显示 `👤`，不显示人数，也不在模块内部显示；页签悬浮提示列出船员姓名、等级和当前效果。装备岗位对应装备页签，高科技/生产岗位对应高科技页签，宝石岗位对应宝石页签。升级选项即时保存为该船员的 upgradeMode。

船员参与探索时，列表改为“探索中 + 星球名 + 剩余秒数/完成经验”；选中详情显示同一星球与倒计时，提供“查看星球探索”和“召回船员”。探索期间岗位控件隐藏，召回或完成后恢复待命与常规分配。仅可见船员页按整数秒更新该船员行和选中详情；未变化时不写属性，隐藏页恢复时补齐。

高科技岗位选择整个系统时也显示x1/x10/MAX购买选项，不要求选择具体科技。岗位更换、解除和升级选项变更时只更新受影响页签的标记/提示；科技舱及装备卡片不因船员事件刷新。岗位名称、说明、周期、购买模式和容量来自 Excel；按钮文字来自 `ui_text.json`。

| 触发 | 变化数据 | 刷新范围 |
|---|---|---|
| 经验/分配/解除/升级选项 | 该船员等级、经验、分配、upgradeMode | 复用该船员行和选中详情；仅旧/新系统页签标题与提示 |
| 换装/换舰/解锁/首次完成科技 | 可选目标、可用状态 | 船员页目标选项、涉及的行/详情；隐藏页仅标脏 |
| 打开船员页 | 补齐隐藏期变更 | 复用所有既有行/控件，保留选择、草稿、焦点和滚动 |
| 配置新增/删除 | 行/选项集合 | 只增删相应船员行或重建变化的下拉选项列表 |

无船员数据的旧档按 Excel 初始化待命船员，不改旧档版本或旧模块数据。现有档规范字段类型、等级/经验、人数和目标，丢弃未知船员及静态字段。有效但暂不可用的系统分配读档后保留。旧 weapon_upgrade/defense_upgrade 自动迁移为 equipment_upgrade + equipment；旧 `smelting_speed` + 宝石熔炼炉目标迁移为 `jewel_auto` + `jewels`，保留等级/经验。同一系统目标若有多个旧分配，按船员配置顺序保留首个，其余转待命，不丢等级/经验。旧 `hightech_efficiency` 分配读档后转待命，不自动转换为会花资源的高科技岗位；等级/经验保留，玩家可手动重新分配。缺失或非法 upgradeMode 使用 Excel 首个选项（当前1级）；有效选项跨读档/切页保留。正式玩家存档未被测试读取或写入。

## 修改定位与验证

### 自动升级性能审计（2026-09-22）

本轮仅测量，未修改游戏实现或 Excel 间隔。隔离项目使用真实存档写入和原 UI 事件路径，覆盖最小/最大舰体、装备页可见/隐藏、1/10/MAX、每种资源 0/1e6/1e100，共36组；每组从1级相同状态开始，预热2次后采样10次。另测4组空闲调度。探针暂停战斗并直接推进船员时钟，结果是同步调用耗时，不是完整游戏帧率；1e100 为巨额存量压力输入，不代表日常进度。

12模块、装备页可见时，一轮耗时如下（毫秒，中位数 / P95；10样本的P95等于最大值）：

| 输入 | 升1级 | 升10级 | MAX |
|---|---:|---:|---:|
| 资源不足（0） | 0.41 / 0.53 | 2.07 / 3.24 | 0.37 / 0.54 |
| 每种资源1e6 | 46.19 / 48.35 | 56.73 / 59.58 | 26.81 / 28.33 |
| 每种资源1e100 | 44.84 / 50.44 | 53.38 / 80.36 | 710.79 / 741.16 |

1e6升1级时12件成功升级，逐件同步存档共约21.57ms，原升级UI事件共约23.15ms；隐藏装备页后整轮降至23.69ms，但仍有12次存档。MAX压力场景的最大等级搜索约225.24ms，原条件检查和扣费还会分别逐级重算费用，整轮约710.79ms。不能把整轮MAX耗时都归因于搜索。

结论：资源不足时检查负担小；成功升级的同步存档/UI，以及MAX跨大量等级的重复计算存在卡顿风险。60帧预算约16.67ms，常规成功升级已超出该预算。无资源、MAX分配时，按60帧推进的调度平均摊销约0.017ms/帧（1倍速）、0.088ms/帧（5倍速），调度器本身不是主要热点。main按游戏倍速推进时钟，因此1游戏秒在稳定5倍速下约每真实0.2秒触发；资源足够且每轮12件成功时，理论可达60次存档/真实秒，实际受资源和卡顿限速影响。

随后经用户授权实施优化：`game.upgrade_equipment_batch` 同步遍历并复用 `upgrade_slot`。逐件 `upgrade` 事件保留并附带 batch 标记，供原统计/战斗消费者读取；批次结束仅保存一次，再发出含实际变化槽位的 `upgrades_completed`。未成功升级不保存、不发完成事件。手动升级仍立即保存和刷新。UI按变化槽位集合更新属性，共享资源可升级状态、排序和选中详情只检查一次；隐藏装备页仅标脏，宝石详情仅在当前槽位改变时刷新。

费用复用仅存在于这次同步调用内：OWNER为BattleGame，KEY为装备费用配置键+目标等级；由upgrade_cost_for_level写入并供MAX搜索、原校验和扣费读取，批次返回前清空，不跨帧、不写存档。各级费用及取整仍调用原公式，MAX仍按原逐级扣减顺序确定可买数量；没有近似求和或改升级规则。

同40组复测，12模块装备页可见、每种资源1e6时，中位数升1级/10级/MAX由46.19/56.73/26.81ms降至6.67/7.81/7.39ms，P95为7.13/8.22/8.24ms。升1级的存档约2.01ms、UI约3.68ms，12次写盘降为1次。1e100压力MAX由710.79ms降至97.24ms（P95 101.39ms），仍有精确逐级处理的单次峰值，不能宣称该极端输入达到60帧。优化日志 `../../test/work/crew-performance-opt.log`，数据 `../../test/work/test_crew_performance-jla447em/space-battleship/.runtime/crew-performance.json`。探针UI计时包含新增完成事件，未遗漏合并后的刷新工作。

复现：`python test/run.py test_crew_performance.gd --timeout 300`。日志：`../../test/work/crew-performance-run.log`；详细数据：`../../test/work/test_crew_performance-yp8vicj0/space-battleship/.runtime/crew-performance.json`。仅隔离副本写入存档。

单级后续优化：`equipment_card` 首次创建读取船员标记，之后由既有 `crew_changed` 及隐藏页脏标记刷新；装备等级/资源变化不再重算无关船员提示。整体失效时仍刷新标记。`equipment_item` 已查过可升级状态，刷新循环不再对刚更新的同一模块重复查询。`ShipDatabase.equipment_cost` 只投影费用字段，复用原 equipment_growth 与 ceil 规则；避免为了费用生成攻击、防御等无关属性，返回独立字典，不增加跨帧缓存。费用专项与旧完整 equip 行投影对照，覆盖当前配置、无效等级/键、别名、空值、零费用、递减和取整。

细分探针 `test_crew_single_probe.gd`：12模块静止刷新中位数，完整装备刷新3346→1481µs，详情756→496µs，10级费用161→70µs。原无变化卡片循环880µs，其中标记808µs；分离标记后循环18µs。这些是隔离微测量，不与整轮计时简单相加。原/新日志 `../../test/work/crew-single-before.log`、`crew-single-after.log`。

整轮同场景（12模块各升1级、装备页可见、每种资源1e6）：中位数6.67→5.57ms，UI 3.68→2.20ms，首测P95 7.51ms。由于首测尾部波动，追加一次确认：中位数5.33ms，P95 5.58ms，UI 2.10ms，单次同步存档2.25ms。两次各40组完成；可确认平均开销下降约17%～20%，不把单次测量视为固定帧率。日志 `../../test/work/crew-performance-single-opt.log`、`crew-performance-single-confirm.log`。本轮回归247项：费用92、局部UI79、船员UI30、装备46；覆盖旧费用投影一致、船员标记事件/隐藏恢复与装备升级不查询标记。

- 新增：`scripts/crew_system.gd`、`scripts/crew_panel.gd`、`assets/ui/crew.svg`、三个 crew 分表。
- 接入：`scripts/game.gd`（经验/分配/聚合 API、调度、科研/炉、存档）、`scripts/main.gd`（页签/事件/系统标记）。`scripts/equipment_tab.gd`、`scripts/equipment_card.gd` 已移除模块内标记。
- 配置：`tools/import_workbook.py`、`tools/config_workbooks.py`、`tools/level_editor_store.py`；仅新增三段 game_data 投影，保留已有其他段；新增船员文案和现有装备显示绑定。
- 专项：`../test/test_crew.gd`、`test_crew_ui.gd`、`test_crew_equipment.gd`、`test_crew_import.py`；相关回归 `test_module_refit`、`test_furnace_income`、`test_local_ui`、`test_ui_text.py`。证据与当前结果见 STATUS。

没有新增攻击或伤害结算路径：自动升级复用原 upgrade_slot，自动宝石复用原 socket_jewel/upgrade_socket_jewel，战斗组合行为由原模块接口保持。宝石换入后原 `jewel_effects` 按新等级读取效果，不复制或叠加一份船员效果：

| 攻击类型 | 通用效果入口与边界 | 验证 |
|---|---|---|
| 激光、炮、导弹 | 每发仍由 `jewel_attack → jewel_fire → hit_enemy` 处理伤害、暴击、增伤、重复攻击、命中和击杀；多枚导弹各走原发射路径 | `test_jewels`、`test_balance_metrics`、`test_module_refit` |
| 长激光 | 每次周期命中仍由 `jewel_attack → hit_enemy` 处理同类效果；重复光束继续按原有效目标/中断规则 | `test_long_laser`、`test_balance_metrics` |
| 防御装备 | 不产生攻击、命中或击杀事件；原属性/减伤/修复读取新宝石等级 | `test_jewels`、`test_balance_metrics`、`test_crew_jewels` |

船员仅变更宝石归属，不新增攻击次数、CD、BUFF 或击杀触发时机；`test_crew_jewels` 验证自动替换后既有暴击值随等级变化，且多孔位只发一次变更通知。正式玩家存档未被测试读取或写入。
