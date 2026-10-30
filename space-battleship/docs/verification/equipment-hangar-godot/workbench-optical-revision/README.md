# 装备当前入口：结构研究中，运行修改暂停

**最新覆盖：** 用户退回源码 `304883fbde448cd32fa288ae97967e43100209bc`／证据 `a3a77ee0a723ac33b6795bba6ddfde62c0dda041`：“你这平移就不奇怪吗”。已撤两态接受口径；同一槽位升级对象未变，选候选却使升级组横移，尺寸/材质相同不等于操作连续。用户后续将任务升级为结构研究，暂缓固定按钮等补丁。用户现已明确一级/二级职责，具体新概念稿仍待形成；**本轮只记结构约束，不修改代码/采图/复测/Figma/图稿**。3916信息内容保留，已取消806隐藏购级/复用候选主值不复活；不以旧原审或0失败代用户接受。

## 现有结构与职责（只读，不是新规范）

按当前304源码核实，现界面是上方机库及武器/防御槽索引，下方同一工作台并列“现装升级”和“候选替换”；不是装备背包/独立物品成长系统。

| 现有部分 | UI当前展示／动作 | 真实数据与职责 |
|---|---|---|
| 上方选槽 | 武器/防御分组、槽号、现装名称、paid Lv；点击改变_selected并将_candidate还原当前equipment_id | Session.equipment_slot_facts→Equipment.slot_facts，Owner给id/category/equipment_id/paid_level/effective_level/dormant/cooldown_remaining；UI不重造槽位/挂载规则 |
| 当前装备工作区 | 标题槽号/现装/Lv、正式图标；当前→升级后主值、当前槽升级费用 | comparison.current/upgrade及quote；武器攻击力、防御容量均scope=charged_base，不是最终DPS或战斗当前HP |
| 候选选择 | 原可装类型卡、名称/已装备/选中面；选择只预览，不立刻提交 | panel_equipment(_selected)给类型/开放事实；同槽借当前paid_level算candidate，不创建独立候选等级或虚构物品仓库 |
| 替换比较与安装 | 异物时另显示现装/候选主值，武器附原周期；安装键明确目标及Owner禁用/原因 | comparison.candidate/switch_admission；当前槽购级费与安装是两种对象关系，例65铁是现装护盾槽购级费，不是装甲安装价 |
| 倍率/费用/购买 | ×1→×10→MAX循环只改报价；独立购买作用于_selected当前槽，选择候选不改购买对象/mode | Owner quote_slot/quote_max_levels、Economy支付、publish_equipment_levels；UI只格式化真实金额/数量，不推价格或MAX |
| Batch | 顶部入口、当前启用槽名称/Lv、每槽×1/×10/逐槽MAX及执行；无记录/成交明细 | buy_all_levels按Owner原顺序/可支付规则使用余额，可能部分槽成交；不是UI承诺全成或自行分配预算；独占生命周期仍has_exclusive_ui/prepare_host_hide |

## 状态与不可改变的业务约束

- 同物：候选就是现装，Owner返回NoChange；当前UI隐藏替换比较/安装，保原购级。异物：展示同槽等级下的现装/候选比较及真实安装准入，购级报价仍属于当前槽；预览不冒充已装备。
- 真实空槽、休眠与未开放是不同状态。Owner保空槽/首防御槽不得卸空的规则；未开放类型按用户要求仅保纯空位，无交互。卸下入口是用户明确取消的设计，非遗漏，不恢复。不能自行推导空槽一律禁购级或改Owner准入。
- 冷却由Owner的game_time/switch_ready_at/cooldown_remaining决定，当前图10秒不代表UI写死规则；可浏览候选，是否允许安装由switch_admission决定。预算不足/进化材料限制属于升级付款准入，不能串成安装费或用相同灰态掩掉唯一原因。
- paid_level成长属于槽，替换使用该槽既有等级；有效等级/主值/周期等均由Owner给出。UI不得从primary显示字符串反算DPS、成长、容量、比例或完整公式；恢复率/延迟/damage_type虽有Owner字段，当前未显示，不为对称擅自加字段。
- 保两键语义、Owner支付/原生提交后接纳、精准局部刷新/缓存、资源helper原色、正式舰/装备身份、无记录，以及公共宿主/独占边界。结构研究不授权改数值/开放/冷却/保存或把上方逻辑防御画成伪物理舰体部件。

## 现有准入与接纳调用链

`select_slot → 已接纳slot_facts → candidate=现装 → panel_equipment / Session.equipment_comparison → Equipment.slot_comparison(current, upgrade, candidate, quote, affordable, switch_admission)`；选候选只更新UI选择和必要比较，不提交Owner。

`_buy → buy_levels / buy_max_levels(_selected, inputs, Economy.payment, publish_equipment_levels) → Owner报价/支付/原生级别提交 → 接纳并按受影响slot刷新`；`_equip → equip_slot(_selected,_candidate,inputs,publish_equipment_refit) → _equip_admission(首槽/同物/冷却/开放/类别/generation等) → 原生换装提交 → 接纳现装`。`_buy_all → buy_all_levels`自持逐槽报价/支付/提交次序，UI不能复制。Session只补既有mounts/balances/game_time/公开倍率输入，数值和准入归Equipment/Economy/native。

核对点：equipment_panel.gd select_slot/_select_candidate/_refresh_comparison(658/665/718)、_buy/_equip/_buy_all(917/922/925)、_refresh_batch(943)、_process(962)；game_session.gd equipment_inputs/slot_facts/comparison(764/768/779)；systems/equipment.gd panel_equipment/slot_facts/_comparison_value/slot_comparison(161/168/181/218)、buy_levels(597)、_equip_admission/equip_slot/quote_slot/buy_all_levels(620/636/653/670)。这些是现有实现事实，不另造权威契约，规则仍由game-design README/M2/13及原Owner负责。

## 当前空间与操作连续性问题

**用户最新明确的核心：** 问题不是槽位ID是否足够显眼，而是“上方选槽→下方看收益/升级→选下一槽又回上方”，舰船展示夹在连续操作的两步之间。设计约束是槽位选择贴近现装升级工作区，让“选槽→看收益→升级”在同一区域连续完成；保留舰船展示，但不能让它成为选槽与升级之间的空间隔断。这是研究必须满足的关系，不是已确定的具体布局。

槽索引和候选卡是两层选择：前者决定被升级的槽，后者只决定替换预览。现页面并列两对数值、重复现装身份和两类动作，容易把“当前槽升级后”与“候选替换后”、升级费与安装对象混读；现阶段保其信息，组织方式留结构研究。

304同状态旧图确证：仅选择候选、_selected未变，96/292升级组仍从global x204/312移到36/144；相同节点/皮肤不能抵消同一升级工作点移动。原未选没有右比较/安装时空域明显，扩大图/移动整组也未获用户接受；不能用填说明、加框、拉满购买键或隐藏购级来替代结构解决。本轮不把研究预锁成固定按钮坐标，也不先画新布局。

## 用户已明确的一级／二级结构方向（待新概念稿，不实施）

- **主页面：现装总览＋直接升级。** 槽位选择贴近对应现装升级工作区，使选槽→看收益→升级在同一区域连续完成；保留舰船主体，但不能让舰船夹在两步之间。主页面不预留候选空间，不因选择候选而移动/重排升级对象或操作。
- **点“更换”才进入二级界面。** 候选选择、现装/候选比较、替换预览、Owner准入及安装操作全部属于二级，不把所有操作铺在一级，也不是在原主面板留一个按需展开区或底部原地切模式。
- 这是已明确的职责与连续性方向；二级界面的具体形态、布局/预览组织、入口/返回以及安装后衔接等待新概念稿，不在本轮自行选定或实现。当前槽升级费仍属现装升级，替换准入/提交仍归Owner，不因分层改规则或恢复卸下；取消806一级主值复用/隐藏购级WIP不当新结构实现。

根确认本次A/B/C横顶槽概念没解决上下往返；后续A/B/C底部原地切模式也过度拘泥一级展示，均非获批定稿，后者作为定稿方向废止。这里的代号只指本轮概念，不与历史B/C台账整页方案混用。早先“槽位总览→当前装备工作区（默认升级）→按需候选替换”的研究表述由上述明确一级/二级职责覆盖，不能继续解释为一级给候选常驻留半幅或原地换模式。

根已研究参考，仅引用来源，不重复联网验证或引外部游戏资产：[AC6官方装配指南](https://en.bandainamcoent.eu/armored-core/news/armored-core-6-fires-of-rubicon-beginners-guide-basic-strategy-and-combat-theory)、[Warframe官方EQUIP/UPGRADE](https://support.warframe.com/hc/en-us/articles/200500194-Mod-Guide-Use-Fusion-Transmutation-Sale)、[God of War列表/详情关系](https://www.gamepressure.com/god-of-war-ragnarok/best-armor-set/zb1062b)。这些参考不能把本项目槽位成长改成外部游戏物品成长规则。

## 现场与历史证据

本次恢复HEAD a3a77ee0、tracked干净，无运行命令，自该交付后未执行新锚点补丁/提交/采图/测试。304/a3a与[原完整图](upgrade-group-coherence/README.md)仅用户已退回的研究对照；[3916字段版](shared-field-reduction/README.md)、[9e版](candidate-balance-and-armour/README.md)保原时点。806原panel/完整patch/json与revert历史、全部tmp/cache/未跟踪均保留，不作为新功能；Figma已取消不恢复。不改main/Library/Space、不新代理/任务/工作区。本轮仅文档固定结构清单，运行源码仍304；等待新概念稿，暂停运行实施，原目标未完成。本SOL未实际平台上下文压缩。
