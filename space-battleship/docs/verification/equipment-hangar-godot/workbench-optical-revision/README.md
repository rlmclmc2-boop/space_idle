# 装备当前入口：就地直接切换概念，规则冲突待裁

**最新覆盖：** 用户已撤回“更换→二级预览→确认安装”提议，认为多步和整页是负担；最新交互目标为槽当前名称/图标就地展开候选，点即切换，无额外确认，详细比较仅按需且不阻碍切换。主页面不常驻整套候选，升级贴对应槽且独立显示现装升级费用；保选槽→收益→升级连续、舰船不夹两步。当前仅新概念/规则事实记录，未实施；成功后“立即切回”与现Owner每槽10游戏秒锁存在冲突，须根裁规则，不能由UI默删/加冷却或确认。运行源码仍304、信息内容保3916，304/a3a已用户退回，806取消精简/Figma不恢复。

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

## 最新就地直接切换方向（新概念，未实施）

**终局容量硬约束：5武器＋3防御，共8槽。** 根当前四行直升E稿未覆盖八槽，不能定稿；新概念稿必须使用最终八槽检验结构，不得只用早期四槽证明布局。当前建议“同一工作区紧凑八槽索引＋单槽操作区”，索引贴属性/升级，不跨舰船；这只是待确认结构建议，不在本轮实施，也不取代下方就地点击交互目标或Owner规则。E指本轮四行概念，不能误作已批准终局结构。

槽位选择贴现装升级工作区；槽当前名称/图标就地展开候选，点候选即发起切换，不再走“更换→整页/二级预览→确认安装”。比较/详细预览只在需要时看，不挡直接切换；主页面不常驻整套候选，也不让候选选择移动原现装升级工作点。现装升级费用与候选切换对象始终分清，65铁不是安装价。舰船主体保留但不隔断选槽与升级。

7b7047e8所记二级确认方向已撤，之前根“槽位总览→默认升级工作区→按需替换”表述和本轮A/B/C横顶槽/底部原地模式概念均非获批实现；不与历史B/C台账整页方案混用。最新点即换是用户目标，不表示当前代码已实现。只记录方向与下面冲突，等根规则裁定及后续概念，不写UI/图稿/代码/测试。

## 旧下拉真实链与当前规则（本轮只读核实）

指定旧main对象已核为 `e93c221239a10d377b2ca89dd395ebcfa99c9819`。其equipment_panel.gd:22–24的slot_picker.item_selected只刷新选项，:32–34创建equipment_picker下拉并另设“更换所选装备”按钮；:34按钮才调用Equipment.equip_slot，**没有equipment_picker.item_selected→equip_slot绑定**。_command:91–98直调action；旧main.gd _command_button:508–525的pressed在会话/重铸门禁后直接action.call，无换装二次确认。补查更早 `d00d51a4a6f54cf392a52b6287bcdf11fe420c48` main.gd:243、251–253也是槽下拉刷新＋更换按钮。它们可证旧链较短/单按钮直达Owner，不能把它们记成已证“候选点即换”；用户所述另一个旧版未获精确源码证据，不否定用户新意图，也不继续扩大历史追查。

旧e93 Equipment.equip_slot:511–537已含同物NoChange、按slot.switch_ready_at检查锁、成功写该slot的game_time+_cooldown并_submit_refit；_cooldown:33来自参数，旧generated/config.json不在该Git对象中，不用当前配置冒充旧值。当前精确事实如下：

| 事项 | 当前真实来源／行为 | 与最新意图的关系 |
|---|---|---|
| 费用 | 当前equipment.gd equip_slot:636–651→_submit_refit:288–293传原inputs.balances；没有Economy.payment/quote.costs。Session publish_equipment_refit:853–889原生提交成功才接纳原wallet | 当前切换不收资源升级费，65铁只在_buy的现装槽升级支付链；无资源付款不等于无冷却或其它换装副作用 |
| 锁的范围和值 | equipment.gd:35读equipmentSwitchCooldownSeconds；当前本机generated/config.json:1066–1068值10，既有03-progression.md:17明确“每槽换装锁10游戏秒” | **每槽，不是全局**。A槽换装只改A的switch_ready_at，不能由UI给B槽追加全局锁 |
| 成功后立即切回 | _equip_admission:620–634检查inputs.game_time < 该slot.switch_ready_at；equip_slot:647–651候选成功路径写该slot新timestamp并待提交 | A→B成功后，同槽立即B→A会EquipmentSwitchLocked；返回原装备也没有豁免。与用户“出问题可立即切回”明确冲突，待根裁定，当前不删/缩短/绕过锁 |
| 同物 | 合法同物在锁检查前NoChange；不准备新槽、不增加generation、不刷新锁 | 点当前项可不变更；不当成功换装或重置锁 |
| 时间/暂停 | Session.frame:453–460有pause_reasons就return；_step:474–476才增加game_time；slot_facts:168–178算剩余值 | 是游戏时间；暂停下等10墙钟秒不能据此认为解锁。本次不改暂停或自动清锁 |
| 升级与清锁 | _buy_quoted_levels:610–618只改paid_level；03:17规定升级不触发换装锁、既有遭遇清空/通关/死亡等边界清锁 | 不能把购级变成切换锁或给UI增加“立即回切”清锁捷径；边界原规则不改 |
| 拒绝/故障 | UnknownSlot/FirstDefenceRequired/EquipmentLocked/类别/generation/锁等拒绝在接纳前返回；_submit_refit失败discard_prepared；Session原生fault停止会话 | 普通拒绝时现装未换，不应先把候选当已装备再“切回”。原生故障未知不能假定可立即补偿换装；就地点击也须保Owner拒绝，不另加确认代替规则 |

**待根裁定的唯一新增规则冲突：** 用户“成功换错可立即切回”是否要求改变当前每槽10游戏秒锁/定义豁免。既有10秒此前明确保留，本条新要求不能默默当已废止；规则未裁前不实现回切例外。就地候选展开、点即提交、比较非阻断、取消二级/确认是最新交互目标；UI减少步骤不等于放宽Owner准入。其它原价格/等级/槽位/原生接纳/资源身份及卸下已取消约束继续保留。

根已研究参考，仅引用来源，不重复联网验证或引外部游戏资产：[AC6官方装配指南](https://en.bandainamcoent.eu/armored-core/news/armored-core-6-fires-of-rubicon-beginners-guide-basic-strategy-and-combat-theory)、[Warframe官方EQUIP/UPGRADE](https://support.warframe.com/hc/en-us/articles/200500194-Mod-Guide-Use-Fusion-Transmutation-Sale)、[God of War列表/详情关系](https://www.gamepressure.com/god-of-war-ragnarok/best-armor-set/zb1062b)。这些参考不能把本项目槽位成长改成外部游戏物品成长规则。

## 现场与历史证据

本次恢复HEAD a3a77ee0、tracked干净，无运行命令，自该交付后未执行新锚点补丁/提交/采图/测试。304/a3a与[原完整图](upgrade-group-coherence/README.md)仅用户已退回的研究对照；[3916字段版](shared-field-reduction/README.md)、[9e版](candidate-balance-and-armour/README.md)保原时点。806原panel/完整patch/json与revert历史、全部tmp/cache/未跟踪均保留，不作为新功能；Figma已取消不恢复。不改main/Library/Space、不新代理/任务/工作区。本轮仅文档固定结构清单，运行源码仍304；等待根裁回切冲突及后续概念，暂停运行实施，原目标未完成。本SOL未实际平台上下文压缩。
