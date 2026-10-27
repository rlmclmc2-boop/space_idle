# 装备与强化：结构化比较、报价和效果摘要最小待审规范

仅提案，未实现接口/玩法/UI。承接[cd4169清单](frontend-readonly-gap-followup.md)，按[唯一入口](../game-design/README.md)定向核对14§2–5、03§1/1.1–1.4、06§3、02§5–6及M2/M5；未定历史动态乘数、未来收益及首槽换型死亡裁定均排除。main仍暂停。

## 固定来源与具体消费者

| 范围 | 固定版本/消费者 |
|---|---|
| 后端 | `feat/amount-safe-previews@4c1de5074377278a474befb9bd618c0f19d27d65`；Equipment/Enhancement与`main@e93c221239a10d377b2ca89dd395ebcfa99c9819`对象分别完全相同：Git blob `2f37403d4860573fcbd685abf080cefa44b52647`、`117cd6ab7bc226ff2db241880916b4dc0175a16c`。本提案不把前面三项候选合入main。 |
| 前端 | `design/g1-internal-organizations@a3e05ea05418841821e2acfec6899b900d8d0b90`的`godot-restoration.md`§3及`g2-enhancement-restoration.md`含R1/R2；均位于`docs/ui-redesign-plan/g1-internal/`。 |
| M2消费者 | 当前槽卡/休眠与冷却、当前对象比较台、+1/+10/MAX固定报价区、批量操作成交反馈；五舰图/挂点仍纯前端，不进入本协议。 |
| M5消费者 | G/B/E等级行、六效果卡、分支详情、买1/最多10报价区、上次成交区；按稳定effect id及节点0–2定位，不能靠中文名称关联。 |
| 早期候选 | `b7bb3de33287783721a8bbd9417f2ea040ad32ff`，仅定向审查其presentation_slots/equipment_comparison/equipment_presentation_inputs、Enhancement.presentation_model/accept_prepared，不整支搬入。 |

## 早期候选：可复用和不能沿用部分

| 候选 | 可复用计算/事实 | 不可据此声称已有完整规范 |
|---|---|---|
| Equipment.presentation_slots | 稳定slot id、key/paid level、dormant、ready_at/cooldown；_charged_base在slot副本上求值这一方式可用 | primary和price均是字符串；primary止于成长/进化/科研/供能的charged_base，没有native历史/分支/外部/临时层，标题不能只写最终伤害/容量。未知/求值失败不能用空串冒充0。 |
| Equipment.equipment_comparison | 当前/候选类型、基础周期/齐射/护盾恢复配置；_charged_base的同口径静态值 | 返回整段中文；升级变体硬编码paid_level+1，不能当+10/MAX或自定义n结果；只遍历启用槽，未知/休眠槽不能被含混当空槽。未做完整换装准入。原row.cd等配置量也不是当前所有强化/临时效果后的最终周期。 |
| Session.equipment_presentation_inputs | 当前世界额外等级、AI/反应炉实际因子来自正确所有者 | 只是装配上下文，不是比较结果、报价或提交许可。前端不复制这些组成计算属性；最小装配处内部传给Equipment，不用整份因子做UI失效签名。 |
| Enhancement.presentation_model | paid/bonus/effective、顺位、主效果/节点门槛和保留choice的基本来源 | price是中文，报价固定1且先用永真可支付谓词，不回答最多10可成交数量/总费；rows没有完整已生效A/B摘要。node.enabled只反映开放门槛，不能表示每个所选功能已生效。返回可写缓存；缓存键bonus/open与旧失效策略不能原样承担新增依赖（如装甲数影响记忆上限）。 |
| Enhancement.presentation_changed | 本模块需要接纳后的最小失效通知这一用途 | 旧accept_prepared在_state写入后、_values替换前发信号，同步监听可看到新状态+旧输出；未来必须在相关所有者本次接纳完成后通知。旧缓存/通知代码不直接移植。 |

没有发现既有quote算式需要改动；上述问题是结果数量、展示口径、充分性、隔离及通知时序，不能为修展示重写费用或效果规则。

## 装备：最小读取截面

下列为语义规范，方法名在实施评审时确定；按Equipment所有权拆成必要读取，不增通用VM/DTO/第二账本。Session仅在需要真实AI/反应炉/世界因子时作薄装配，前端不自报这些值。

| 读取/消费者 | 最小字段与来源 | 边界 |
|---|---|---|
| 槽事实 → 卡片/所选槽 | `id/category/index/equipment_id/paid_level/effective_level/dormant/switch_ready_at/cooldown_remaining`；槽、额外等级和当前mounts/game_time由原所有者提供；未知slot给原UnknownSlot | 空槽、休眠、未开放和冷却分别表达。冷却只约束换装，不给购级加新禁令；首防御槽规则不改。可复用候选字段，不能从panel_slots.label拆取。 |
| 同口径比较 → 当前对象比较台 | `slot_id/candidate_id/upgrade_count/scope="charged_base"`，current、upgrade、candidate三行分别含装备身份、paid/effective等级、主值Amount规范文本、状态/原因；类型特性用有单位的具名字段（配置周期/齐射/充能或盾恢复/延迟），不返回拼接中文作数据 | current=现装当前付费级，upgrade=同装备本次**报价实际count**后，candidate=候选装备沿当前付费级，不暗中再购级；候选+购级组合不在最小范围。_charged_base复用原计算，作用于脱离slot，包含它实际提供的静态层，不含历史/分支/外部层；不调用会写_pending的prepare/values/mounted_configuration冒充查询。 |
| 确定数量报价 → +1/+10固定区 | 直接复用现有`quote_slot(slot_id,n)`的`ok/reason/count/costs/extreme`；costs保留resource id→Amount，展示边界经既有Amount.to_display生成规范文本；可支付/原因复用Economy.can_pay和同批预算 | **不新增第二确定数量报价算法或新价格层。** 武器槽统一laser、防御统一armour曲线，跨进化材料、普通/极端边界沿原_quote_levels；+10单槽仍整批要求支付，不像强化自动缩为可购2级。余额不足不把完整报价改成2级。 |
| MAX报价 → MAX固定区 | 如需公开，只在Equipment薄包装原_quote_affordable_levels，传同批预算的只读can_pay，输出同样count/costs/extreme及原reason | 准确保留原搜索：候选报价失败或不可支付均作搜索边界，最终可购0统一返回NoChange；并不逐项透传被探测报价的错误，另有原离散级数极限返回EquipmentLevelRangeExceeded。不能借公开读取顺便改搜索/错误策略；不用log或显示缩写估级，不新增封顶。升级后比较按搜索结果count，不用1或用户请求数替代。 |
| 当前战斗详情 → 装备详情的“当前实战” | 复用Battle.attribute_details中的entry稳定id及base/value或maximum、已有周期/连发等已接纳事实 | 与charged_base比较分栏并明确口径；不拿当前native最终值对比候选静态值，不扩成假想候选native历史乘数预览。当前盾甲余量不当作候选升级后最大值。 |

比较准入与提交许可分开：候选锁定/类别、首槽卸空、冷却等只读原因复用equip_slot的原检查；如要显示最终无人机/Higgs组合许可，由原Session接纳链提取可复用纯准入，不调用真实提交来探测。本提案不承诺当前候选主值可计算就能提交，也不为休眠/空槽新增购级限制。静态主值未知时为null+原因，空槽有明确状态，不伪造当前战斗数值；不把所有普通拒绝新增成RunState故障。

批量不是单槽报价相加：buy_all_levels按启用武器槽序→防御槽序使用逐项剩余预算，买不起项可跳过。若后续消费者需要整组报价，必须在Equipment复用同一遍历/报价/脱离预算推进，提供每槽实际count/costs及总支出、跳过/失败原因；不得承诺全成全不改。**本轮最小读取方案不新增整组预览**，批量先保留现有动作与真实成交反馈，不把各槽独立MAX相加作可执行总价。 buy_all_levels可能先成功接纳已成交槽，再返回后续failure；因此ok=false也可能已有真实成交。回执必须保留该已成功提交批次的逐槽count/spent、总支出及已提交边界，不能只在ok=true时附加这些事实。

## 强化：购买报价和六效果摘要

| 读取/消费者 | 最小字段与权威 | 明确不做 |
|---|---|---|
| 等级/效果事实 → 等级行/六卡/节点详情 | `paid/bonus/effective/available/reason`，实际weapon_order/defence_order；效果行`id/category/position/threshold/active`；节点`index/threshold/choice/open/function_active/reason`。由_effective_level/_describe与原规则投影，世界额外+原extra_levels计入bonus，不抬高购买费用 | 不从published_output的内部键在UI猜完整效果，不按位置/等级在UI复制门槛。保留选择与实际生效分别显示；repeat节点2的B不产生第二代功能，不把open误标为function_active。repeat-B2旧选择可保存但功能不生效；原_choose准入不借展示改变，不能新增命令拒绝。 |
| 买1/最多10报价 → 当前报价固定区 | 新具名只读报价复用`_quote_purchase(state,request_count,rules,api,can_pay)`，保留request_count、purchasable_count、costs、extreme及reason；只显示现有买1/最多10，不新增强化MAX | 请求10可能成交2；NoChange表示可成交0，不伪造10级费用或真实成功。第1级所需费用可沿_quote(state,1)给作不足提示，与实际可成交总费分开；等级/Amount故障保持错误，不伪装余额不足。 |
| A/B可选规则说明 → 所选节点详情 | 无论未选、未开放或当前未生效，所选effect/node均返回A/B各自的稳定规则标识、静态参数/单位、门槛、当前选择及可选/功能生效原因；由Enhancement复用同一原规则投影，必要参数不得只在已生效分支上提供 | 这是选择前的规则说明，不是已接纳结果，也不是假想历史乘数或未来收益。UI可本地化规则文字，不按等级/节点自己补公式或猜参数；禁用第二代连发等规则同样保留可读原因，不伪装可用功能。 |
| 当前已生效静态合成摘要 → 六效果卡主文本 | Enhancement在同一已接纳state与真实bonus/开放/armours上下文上复用_describe/_combat，生成具名summary参数及完整生效A/B规则片段。卡片不解析内部战斗字段，不只有裸旗标。具体截面如下表 | **不调用evaluate**取得查询结果：它会写_pending_output。不调用purchase/set_branch/move_forward来预览。规则片段/说明可前端本地化，业务参数、有效A计数/B状态与作用单位由所有者给出；不输出伪实时历史乘数或未来收益。 |

| effect id | 最小静态摘要截面（仅已生效参数与规则） |
|---|---|
| proficiency | A合成伤害倍率、B2周期倍率、B3抗性穿透规则/参数、B1连续主目标规则；历史成长当前倍率不在本提案。 |
| repeat | 叠加A后的触发概率、重复伤害倍率、延迟、B1额外连锁数/B3独立额外目标概率，repeat-B2明确不启用。 |
| critical | 含A的原始暴击率、静态爆伤倍率与已生效B1/B2规则；B3保证**效果触发**与额外爆伤机会分开说明，不能把_combat.weapon.critical_rate直接标成B3后的最终触发率。当前层/剩余攻击数/时长不新增估算。 |
| adaptation | A合成容量倍率、B1同源规则、B2周期护罩规则/时间、B3已有匹配抗性规则；护罩所依赖真实当前容量不在UI另算或当作未来值。 |
| memory | 含全部A的恢复比例/周期与保护上限比例，原armours参与的B3上限修正；B1/B2规则及B3每盾充能规则完整呈现。不把“每盾加成”当实际盾数累计最终值，若需该实值另取原装备/核事实。 |
| deferred | 当前静态延期比例/周期/时长、含A的**未强制清除概率**及B1/B2/B3完整规则；B2禁随机清除/B3强制清除与来袭倍率语义不可被底层基础概率掩盖。 |

上表六效果截面描述当前已生效的静态合成结果；节点详情的未选/未开放A/B规则说明是独立截面，不能用当前摘要代替，也不能把选项说明显示为当前已生效。两者均由所有者提供必要参数，非要求把现有_combat所有内部字典整本透给UI；缺少的分支语义从同一原规则投影，不在前端二次实现。当前临时层、攻击/来袭历史乘数、动态暴伤/层数及未来收益仍排除；已有Battle详情可独立显示确有的当前事实，不由本方案新推导。

## 费用、成交和失效的共同边界

- Amount成本/主值规范文本与本地化缩写分开；resource id和比较variant为身份，不靠“铁/碎片/伤害”字符串解析。报价失败保留原reason；枚举或Amount错误不伪造0。显示秒数、比例沿现有类型，不能先float化Amount再重建。
- 预览只读，不调用支付接受、native提交或临时占用；_charged_base会写slot._charged，故仅给脱离slot。原MAX局部search_cache可复用，不写真槽/准备状态；新摘要缓存必须覆盖真实依赖，不搬旧bonus/open缓存键。返回脱离/只读截面，不返回可写所有者缓存。
- 现有命令按提交时最新状态重新quote/准入。每次执行仅以该次quote支付；凡已发生成功接纳，回执均需最小附加实际count/逐资源spent（批量按slot）及提交边界，供“上次成交”显示，不能仅挂在ok=true分支；buy_all_levels即使最终ok=false返回后续failure，也须如实给出已提交槽及数量/支出、总支出，同时保留后续reason。未成功提交的候选数量/费用不得冒充已成交；提交后fault或结果不确定仍沿原政策标明边界，不虚构完整回滚。回执不是下一次报价，不靠通知后重读等级/钱包差反推，保持原部分成功语义。不得为保持旧预览费用而锁钱包/级数或重放旧候选。
- 所选slot/candidate/request模式变化清对应报价；购级、换装、换舰、材料开放、预算或比较因子实际变化使对应读取失效，冷却沿真实游戏时间。装备先沿现有slots_changed/loadout_changed/options_changed和预算事实，不新增总线。强化可用最小具名通知或可见时重读，不建事件框架；若补presentation_changed，必须在Session钱包等本次整批接纳完成后发布，监听读取同批_state/_values与钱包最终事实，不能只在Enhancement.accept_prepared内部提前发信号。外部bonus/装甲变化经accept_output更新效果而不改变购买/分支state，也必须被通知或可见重读覆盖；不得只按_state变化失效。通知后不写回旧候选。前端保持未提交草稿和稳定对象，隐藏不停止领域推进。

## 实施前复审与证据范围

本轮只做源码、候选范围、链接与差异核对，不运行游戏测试。若提案获准，必要验证为：n=1/10及MAX口径一致、材料跨阶/普通极端与离散边界；强化最多10部分数量/0与首级价；可写返回不污染槽缓存/准备态；未选/未开放A/B规则参数可读且与当前合成结果分开，改序/分支后A叠加和B语义完整、原存选择不丢；批量已成功接纳后返回failure仍有逐槽count/spent及提交边界；报价后状态变化确认取最新，成交/下一报价分离；同步通知在Session整批接纳后不读到旧_values/钱包，外部bonus/装甲经accept_output变更也可见；MAX错误作边界/0为NoChange及repeat-B2保存但不生效的原语义保持。动态历史/未来收益、UI品质和几何验收仍不包含。未批准前不实现这些端口。
