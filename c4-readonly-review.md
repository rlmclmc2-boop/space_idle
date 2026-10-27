# C4只读审核：来源信息、触发许可与父攻击关系

核对代码基线 `50ed7cda`，C1更新 `b7bb3de3` 不改以下战斗实现。设计来源为已通过拆分的 `main@929aaa26`：02第3.2/5/6/7节、04第8节传说表、05第6节、06第5节。本轮不改递归实现、不替用户裁决未明确组合，不把讨论扩写成统一禁用派生规则。以下是静态调用链审核，不是实操或性能基准。

## 结论先行

不需要为了“禁止连击再触发连击”保存完整父对象历史。现有同类防重入使用调用入口、派生标记与一次性机会即可判断。**但是来源信息不等于可删：出生快照、共享机会、来源身份、计时任务所有权与导弹共享上下文直接影响玩法，仍必须保留。** 各效果的许可不同，不能把全部 derived 统一解释成“禁止一切衍生”，也不能仅凭有 parentId 就认定安全。

用户说的“连击”在当前文本没有唯一专用字段；下表分别按既有 repeat/连发与 chain/连锁核对，不把二者混为一种。是否允许一个未来特例继续触发，必须由该效果明确声明和验证；当前代码没有一个已启用的通用“允许第二代连发”开关。本结论不预设今后所有例外都同一种实现。

## 现有字段的实际职责

- `BirthConfig`、`Attack.birth`：保留出生时武器/等级相关快照、类型、齐射数、连锁数、连发延迟/倍率等；延迟任务不能读换装后的新配置。Attack保存伤害、critical/critical_bonus_applied、secondary/repeats、Higgs与奇异物质出生参数。
- `Instance.attack/chain_used/count/primary/links/derived`：同批共享不可变攻击与有限连锁机会；不是父链目录。`chain_used` 在派生前先置位，防止连锁子命中再次扩张。
- `Flight.repeated/chain`、`Timed.damage_derived`：区分载体来源与共享连锁机会；`Flight.instance` 连到当前攻击实例，并没有 `parentAttackId -> parentAttackId` 的全历史链。
- `MissileContext.source/derived/wild/wild_used/guidance_* /factors`：来源统计、派生导弹不再加制导层、同批对同目标共享因子、狂野爆炸一次性许可。删除会改伤害与触发。
- `Timed.owner_flight/owner_generation`、`Handle.index/generation`、source_slot/source_uid、Flight.serial/contact_order：生命周期、来源失效、池复用安全与稳定排序；不能当纯调试元数据删除。
- `StrangePacket.order/damage/type/source_slot/source`：到期释放所必需的伤害快照、排序与统计归属；不保留父Attack对象。

定位：combat_execution_kernel.h:70–186、303–330、604–610、646–679。这里的 source 字符串提供模块/无人机统计归属，不等于可沿其还原完整祖先树。

## 逐项对照

| 类别 | 现行设计依据 | 代码来源/许可与行为 | 判断与未明确点 |
|---|---|---|---|
| repeat连发 → repeat连发 | 02§5“重复攻击不继续递归”；§6第二代连发功能不启用；§7显式例外 | primary在1585–1618只抽一次Attack.repeats；到期kind=2在1918–1926调用launch(...,repeated=true)，不重走primary。持续光束1710仅首跳且!f.repeated可安排连发 | 当前直接重复不再重复，与所核规则一致；不靠追父链。没有已启用的第二代许可。未来明确特例需单列次数/终止条件，不自动放开原 Attack.repeats。 |
| chain连锁 → chain连锁 | 02§3.2一次攻击同一连锁机会只消费一次 | hit_enemy:930–942先设置Instance.chain_used再birth(chain=true)；连锁弹共享instance。弹体命中1811令chain的trigger与chain_trigger均为false；光束link命中936传trigger=false | 当前同一连锁机会不会再次扩张。共享instance/chain_used是玩法状态，父链不必需。不能把它解释为“所有不同派生实例共享全局一次额度”。 |
| repeat/secondary → chain | 02§3.2/05§6定义连锁机会；02§7又概述派生不触发任意主攻击类效果 | trigger与chain_trigger分开。repeat新建instance，普通炮1534、光束1701仍传chain_trigger=true；飞行命中1811按!chain和!wild允许连锁。secondary1618共享primary_instance，消费同一个机会 | **不是一刀切禁止**：代码可允许派生攻击的有限连锁，但不因此赋予主命中/击杀触发许可。是否每一类都应这样，现有概述不足以单独证明；先保留并提交交叉组合清单，不擅自收紧或放开。 |
| scatter散射、Higgs多目标 | 04表scatter_pulse是普通激光多目标，Higgs是一次炮击带宽筛选 | scatter1603–1608共享primary_instance；Higgs1510–1530按冻结目标顺序多次主命中，同一个chain_used | 是一次规定攻击的多目标成员，不应仅因多个hit称为递归。每个主命中可能按既有规则触发相应效果；不扩写为通用例外。 |
| 奇异物质 → 奇异物质 | 04§8明确派生不再生成自己 | 主炮Attack固定strange参数1548–1554；hit846需inst+strange_enabled+trigger才排入事件。StrangePacket释放325–330传空inst、trigger=false、chain_trigger=false | 事件仍能伤敌/造成正常死亡掉落，但不再次生成奇异事件或连锁。保存伤害/source/排序足够执行；完整父Attack引用无当前执行依赖。 |
| 狂野导弹爆炸 → 狂野爆炸 | 04§8每3普通+1特殊，命中后raw50%全体爆炸 | 1585–1598特殊批禁secondary/repeats；context.wild_used在858–863先置true再做AoE，派生AoE传trigger=false并共享同一context | 同上下文只爆炸一次。局部C++调用是有标记阻断的有限嵌套，不等于无限触发链；不能因“去递归”删共享context。 |
| 敌方死亡爆炸 → 死亡爆炸 | 02§7禁止爆炸递归重跑原击杀；死亡由活到死的一次命中拥有 | 911–915仅trigger允许a.explosion；子伤害传空inst/trigger=false/chain_trigger=false，死亡状态先变更且generation增加 | 子爆炸可杀敌并正常掉落，但不再触发该类死亡爆炸。它与狂野/奇异有不同门，不能统一只看repeated。 |
| 棱镜光束连接 | 04§8第一条非重复有效光束占唯一塔 | birth:731–758以!repeated挑塔，Instance保存primary/links；每跳继承同Attack，通过936只命中已有links | 这是明确的连接扩展，不给link新的主攻击/连发机会。是否未来允许“棱镜派生再次成塔”没有现行许可，不推定。 |
| 闪避反击 | 04§8冷却+抽取现有武器反击 | 1187–1207新建Attack、继承birth并计算反击伤害，secondary/repeats/strange保持默认false；launch(...true)，导弹context标derived | 没有重走primary抽样，不触发重复连发或奇异。其chain机会按独立instance路径仍可能存在（见上行交叉问题）；不以泛化derived替代专项决定。 |
| 黑洞释放 | 04§8累计我方raw后计时释放；不反推已过抗性损失 | 1167–1184用black_release与独立source，hit传空inst、trigger=false、chain_trigger=false、bypass_absorption=true | 释放不会再次被同吸收窗吸回，也不触发Attack级奇异/连锁。只需累计值/计时/来源，无父图执行依赖。 |
| 无尽光束 | 04§8普通槽来源选择与目标死亡后重选 | endless_eligible1622排除repeated，生命周期保留原f.instance/Attack；重选是持续载体目标变化 | 不等于重新出生一次规范攻击；当前没有“连发出的无尽光束再继续无尽”的默认许可。 |
| 暴击后继增益/制导层 | 02§6 derived不更新B1/B2；04制导同批同目标 | B1/B2仅在primary1609–1611更新；制导context->derived在778–779阻止再增层，factors缓存因子 | 都依赖明确运行期来源/快照，不需要完整祖先历史；但不能删成只有伤害数。 |

## 跨其他效果绕回：单列而不补规则

直接 repeat→repeat、chain→chain、奇异→自己、狂野爆炸→自己、死亡爆炸→同类爆炸已有明确阻断。repeat→chain、counter→chain 是代码中真实分开的许可，不等于发现无限循环；chain之后没有返回primary/repeat调度入口。当前核查路径没有发现“绕一圈重新抽primary连发”的入口，但这不替代所有组合的运行验证。

设计§7有泛化TriggerPolicy描述，代码实际是布尔参数与每类字段；尤其上述跨类别chain许可与概述之间仍需专项确认。不能把用户举例自动扩大为“所有派生永远不能触发其他效果”，也不把现状默认签成所有组合等价。没有发现当前表内明确授权一个第二代repeat再次repeat的有效特例；未来例外按具体条目审查。

## 运行期、存档与调试分开

1. 运行期保留上述实际依赖的出生快照、归属、代际、计时任务、共享次数/上下文；它们不是冗余历史。
2. 现行06§5明确不保存残血、弹体、光束、临时效果与战斗事件队列。核 persistent_state仅保存history_counts、RNG和ID水位；当前没有把全父链写入存档的玩法需要，也不应在本轮新增。
3. `next_ids.attack`目前保存的是flight_serial（kernel:2303–2313；battle.gd:279–290映射projectile_serial），并非规范Attack对象的独立ID。这个命名/身份契约差异与“是否存父链”是两件事；不能为避免追踪开销而悄悄把原AttackId要求等价掉。本轮只报告，不改格式/迁移。
4. 完整祖先树、回放因果查询、逐命中血缘日志目前无实际伤害求值消费者，属于诊断能力候选；若以后确需，可另行评估按需有界记录，不默认常驻或进入存档。

## 最小必要方案（供审核，未实施）

- 保留现有每类效果已经需要的标记、快照与共享机会，不新增完整parent对象历史。
- 先冻结一张“来源类别 × 允许效果 × 自触发终止条件”的审查表，优先确认repeat/counter是否继承chain等交叉项；规则等价后再决定是否用更明确的本地类型/具名许可替换容易混淆的布尔参数。不是现在增加万能TriggerPolicy框架。
- 没有明确可继续的同类触发，不通过重新走primary来获得许可；有明确例外时，逐条给有限次数/截止条件和针对性验证，不统一开放或一刀切全部禁用。
- 以少犯错为先：新增效果应逐项说明出生快照、源失效、单次消费和调度入口。性能只比较必要元数据与保留生命周期；本轮无基准，不宣称某方案更快或给虚构比例。

本轮未改combat_execution_kernel.h、保存格式、递归/连锁/爆炸实现或任何C4数值。最终裁决仍由用户/整体审核处理。
