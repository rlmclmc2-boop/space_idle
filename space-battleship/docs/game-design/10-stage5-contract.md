# 第 5 阶段模块交接契约

玩法权威仍为 `docs/game-design/README.md` 所列文档。本页只记录当前代码端口、状态归属和验证边界，不增添规则。

## 状态所有者

| 模块 | 独占状态 | 对外端口 |
|---|---|---|
| `Hyperspace` | 路线层数与最佳时间、凭据账本、奖励与改造随机流、仓库/溢出、装备 ID、预设、挂设、图鉴、过滤、能源 | `prepare_*` 先校验并返回候选；`accept_*` 只在外部端口成功后接受。查询返回副本。 |
| `Campaign` | 主线位置、驻守及返回目的地、舰型与通关事实 | `hyperspace_return_target`、`enter_hyperspace`、`return_from_hyperspace`；`hyperspace` 状态每固定步推进原生核。 |
| `Crew` | 船员岗位、等级及占用 | `hyperspace_candidate`、`reserve_hyperspace`、`release_hyperspace`。船员等级只从该模块取。 |
| `Equipment` | 已购买的所有装备槽及付费等级 | `drone_weapon_source` 取同类全部保存槽的最高付费等级，生成共享战斗 schema。 |
| `Battle`/native | 生命、防御、弹幕、无人机战中状态与传说战斗动态 | `prepare_player`/`commit_player`、`start_wave`/`advance`；不读超空间仓库或钱包。 |
| `Economy` | 唯一余额及收入 | `payment`/`accept_budget`；超空间不保存材料余额。 |
| `GameSession` | 固定步顺序及跨模块事务 | 校验各准备结果，原生接受后提交装备/无人机/钱包，最后通知界面。 |

## 交接顺序

1. 手动入场：读取 Campaign 返回目的地与通关事实，Hyperspace 准备凭据；结算旧掉落、重置 Battle、Campaign 切状态、接受凭据并开始独立编队。每场成功由 Hyperspace 增加波次，十场后固化奖励；失败与退出返回记录的目的地。
2. 挂机：Crew 校验空闲与等级；Hyperspace 准备任务后才占用船员。凭据在完成边界固化奖励。领奖先检查仓储和 Economy 的 Amount 加法，再接受凭据与余额。`(round_id, run_id)` 在本轮账本中索引，旧任务即使下一任务已开始也能幂等重试。
3. 配装/改造：Hyperspace 准备实体及贡献，Battle/native 先验证整组，随后同一次 `publish_equipment_refit` 接受状态、钱包和通知。预览只用实体随机流的局部副本；相同改造操作 ID 与内容返回最近结果。
4. 重铸候选由 Hyperspace 从现有实体推导，保留槽、星球封存门槛从配置计算；旧轮凭据无效。按 `07-verification.md` 的实施顺序，完整新会话重铸属于第 6 阶段：届时必须依 `03-progression.md` 第 7 节构造并校验一份新的 GameSession，保留旧会话直到新会话完全可用。当前没有可触发的 Session 重铸入口。

## 当前验证与限制

`foundation/tests/_hyperspace_probe.gd` 使用同一 Godot/native 核接纳四条路线各十场以及 5、8、20、220 层的 160 场，覆盖手动返回、固定步推进、单次/自动凭据、旧任务幂等领取、改造预览与重复操作、换装、过滤分享、挂设升级、预设保护及候选重铸轮次失效。原生核还实测无人机造成伤害、卸装后停止造成伤害，以及传说效果配置的提交。

五帧 headless 主场景启动曾记录两条 `Parameter "material" is null`：定位为 dummy 渲染器创建战斗 GPU 视图时调用空 material。headless 启动现跳过该视图，会话和原生核仍正常运行；复测无此报错。

五类挂设已分别接入资源、研究速度、反应炉容量、碎片与超空间材料端口；领奖/拆解引起的挂设升级也先计算候选，再和钱包及原生状态一起提交。数值重抽的保底费用以 Amount 计算。界面提供路线、凭据、仓库、收藏、过滤、预设、挂设与基本改造入口。

阶段内超大数专项检查覆盖 9×10¹⁸ 目标量的 2:1 兑换、超出 64 位整数的扣款、1×10⁵⁰⁰ 的不足额拒付与钱包不变，以及保底改造报价经 Amount 解析。完整新会话重铸与长期保存/恢复属于第 6 阶段；第 5 阶段无已知剩余实现项。

## Audit closure: growth and stable handoff

- The drone record owns its identity and forge history. `weapon_generation` is the native weapon incarnation and remains stable while the same drone is equipped. Forge revisions, affix changes, omen changes, research, reactor, paid equipment levels, and world bonuses update native values without replacing that incarnation. A newly generated drone starts at generation 1; older records default to 1.
- `Equipment.drone_weapon_source` reads staged slots during a paid level transaction. `GameSession` prepares drone contributions from candidate research, reactor, and world factors, sends `drone:<id>` rows through `Battle.commit_values`, and accepts the new cached contributions only after native success. The native row keeps the same `id`, weapon key, and generation, preserving due time and combat state while changing base damage and external factors. A configuration refit remains the boundary for add/remove/equip and legendary changes.
- The material wallet and ultimate forge cost use the same `ultimate_cores` resource key. Claim remains keyed by `(round_id, run_id)`; a repeated claim yields the recorded result without a second credit. After an auto receipt reaches `CompletedPending`, a successful claim permits the next fixed step to start a fresh run using the reserved crew. Pending rewards block this transition.
- Hyperspace waves use the selected layer's endpoint life, attack, and resource ratios for all ten waves. Only mainline combat uses entry-to-end interpolation.
- Modernization computes its target from the current round's mainline highest reached stage and the route's actual best-time record keys. It picks the highest recorded layer at or below that stage, and requires it to exceed the drone's current level. Caller-supplied targets cannot bypass this choice.
- Exchange accepts decimal text, converts through `FoundationAmount`, requires a positive integer amount, and performs the 2:1 debit and credit atomically. The UI passes text directly, so quantities above signed 64-bit range remain exact.

## Audit closure: automatic receipts and candidate reactor factors

`GameSession._advance_hyperspace_online` is called from every fixed step. It advances the online receipt and claims an auto reward immediately when it becomes `CompletedPending`, using the same idempotent `claim_hyperspace` transaction as a manual claim. A full warehouse leaves the receipt pending for retry; the next run starts on a later fixed step after a successful claim. Crew stays reserved until auto mode is stopped. The probe completes and credits two successive auto runs without an explicit claim call.

Equipment refits first derive module totals from the candidate drone IDs and hanging slots, then prepare the candidate reactor. They rebuild drone weapon contributions with that candidate reactor before submitting the native player configuration. Ship capacity truncation, hanging changes, and preset application therefore use the same reactor factor for ordinary equipment and drone weapons. Forge operations compare the prospective contributions with the active native loadout; a change confined to forge history or other noncombat fields commits only the drone record and wallet. `Battle.configuration_commits` counts successful native configuration submissions for this transaction test.

## Auto continuation fixed-step snapshot

A completed auto run is claimed in its completion step. At the start of the next fixed step, `GameSession` asks `Crew` for the still-reserved assignee's current level and reads the current permanent luck buff. `Hyperspace.prepare_auto_continuation` creates the new receipt from those values; that same fixed step then advances its work. Earlier receipts retain their own duration, crew level, luck, and luck RNG snapshot. `Hyperspace.advance_online` no longer creates a receipt from cached auto fields. The probe checks first-step work and old/new duration and luck across a crew-level and buff change.
