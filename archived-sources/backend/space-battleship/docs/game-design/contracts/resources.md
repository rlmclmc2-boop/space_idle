# 全局资源整数契约

[回唯一入口](../README.md)。用户明确“全局游戏的所有资源不能非整数，有必要的话向上取整”“无论展示还是实际值”；本页记录本轮执行边界。实施基线`aaba6683829ca11606003690224a1be9ea16080c`；资源消费最新固定版`feat/amount-safe-previews@f9244a30ad1843128aaa0a620c4dc3e4866685b2`已普通发布，**获同一Astra high限定只读复核通过：非法奖励键在restore/Claim前拒绝、完整候选钱包前置校验，chrono按当前请求窗口比例还原支持秒数，关闭两处退点。91项为作者证据，非独立复测、完整游戏或main验收，未合main**。消费者按各自既有依赖精确合并，不覆盖新UI、不停止其他制作；[源差异、依赖与证据](../../verification/integer-resources-implementation.md)。

## 数量与取整

- 实际资源包括钱包铁1、铀2、jewel、chrono、四种普通材料及ultimate_cores、待领掉落和已固化奖励、最终费用及超空间energy。资源持有和实际转移使用非负整数Amount；已有离散int核心/份数保留整数语义。通用Amount不改，不能将伤害、倍率、每秒收入/投入、计时、研究工作或成长进度全局ceil。
- 原本已整数的装备Q/初级特例、逐级价格求和、反应炉/强化报价和MAX曲线保持；所有者最终费用与Economy验资/支付共用向上整数化。实际支付先完整验资，再给整数候选钱包；接纳才改变真实钱包。费用失败不降为资源不足，不新增退款/故障回滚规则。普通材料material_unit_scale=10保持原完整单位，不能库存÷10、费用缩小10倍或继续展示0.1材料。
- 掉落出生作为整数资源持有；领取时的最终倍率完整求值后ceil入账，sample.actual记录同一整数。普通碎片旧roundToCent已移除。定时物沿原出生冻结/领取转移时点，不逐帧产资源。旧已整数的离散奖励/材料floor节点不因本次擅改产出公式。
- 星系等连续产出沿原结算事件调用credit_yield，累计已结算的不足一单位进度跨事件保存；本次只增累计ceil的差额。因此原总raw=1，分成10次0.1也只入账1，不能每帧或每事件重复ceil。进度不能转移/支付，不是资源钱包或可展示的小数资源。
- 科研投资与chrono加速先消耗已付服务进度，需要新增扣款才ceil；未消化进度跨帧、完成边界、暂停/变速及恢复保留。速率段按累计时钟求Amount总量差，不反复把rate×dt取整；同总接受时长的不同分帧扣费相同。科研完成资金预览按同一服务进度求整数资金，不把服务进度混进展示余额。
- energy持有改Amount，普通和后期线性爬升按累计时钟积分后只接纳整数增量，封顶沿原cap；不启用当前票耗0的消费、不变初始满能量、不改Excel。late_supply_work及生成进度仍为工作/时钟。

## 恢复与展示

旧存档仅在内存候选通过相应所有者完整校验后，向上规范wallet、pending drops amount/production_base、sample.actual/production_base、固化材料奖励/最近forge费用及energy。未改用户原存档文件，也不扩展M10保存事务。新增Economy.yield_progress、Research.funding_progress/funding_meters、Session.times.chrono_progress/chrono_meter、Hyperspace.energy_progress/energy_meter，旧档缺省零/空；进度非负，数学上不足1，Amount近似可能规范为1，允许0..1且大于1拒绝。段时钟须有限非负且已存total与原Amount积分一致，非法状态/金额不部分接纳。新energy保存为Amount，旧energy有限数值可读；旧版本不保证能读新字段。

| 可消费出口 | 说明 |
|---|---|
| Economy.budget/payment/can_pay/credit_yield | 实际资源整数Amount；payment返回整数候选，credit_yield累计入账。balances_text/balance_rows为Owner已格式化整数文本。 |
| Economy.quantity_text(value)、cost_texts(costs) | 资源专用只读格式化，返回ok/text或ok/texts，整数系数、无float转换；极大值如123×10^998仍表示整数。不得给速率/倍率使用，不再将这些结果传PlayerText.number二次解析。 |
| Reactor purchase_preview/purchase_max_preview及MAX成交回执 | 原costs规范文本/数量/资源身份不变，新增cost_integer_texts，直接显示；预览/×10/MAX/扣款沿同费用。 |
| Session.preview_hyperspace_forge | cost_amounts保留规范金额，增cost_integer_texts；实际forge同源最终整数费用。 |
| Research预算资源行 | balance仍规范Amount文本，增balance_integer_text供直接显示；income_rate/net/speed/game_seconds仍是速率、速度或时长。required_funding为整数资金。 |
| Hyperspace.online_status | energy由float改为规范整数String；另给energy_text（直接展示）及energy_amount（整数Amount）。idle.work/duration仍float秒，不能把整个返回值取整。 |

消费合并必须以本候选的**所有者源码差异**为单位，在较新的各模块树上处理冲突；不能用本旧树覆盖新UI。消费者需改用整数展示字段/Owner格式化，不能只隐藏小数或将缩写小数系数当可支付金额。本候选不改src/ui；实际新UI全局资源显示验收由根线程协调既有组完成。
