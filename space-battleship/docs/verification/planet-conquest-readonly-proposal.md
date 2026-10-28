# 当前星球累计征服来源：最小只读提案

仅设计文档，待根线程及同一原独审核，未实施或运行测试；main不动，原M10 WIP不夹带。唯一入口为[设计README](../game-design/README.md)，候选字段/单位及局部失效的唯一正文见[Planet分册第11节](../game-design/contracts/planet.md#11-待审设计当前星球征服事实与累计来源摘要)。玩法只按[03第5节](../game-design/03-progression.md#5-星球探索与建筑)及重铸第7节，不借展示改变规则。

## 固定来源与复用

- 当前后端`feat/amount-safe-previews@26832431d6546a436774c802e80aff2dc086f7dd`；Planet与本项相关Session路径未因反应炉展示实现改变。消费者缺口固定[a91f65b4的buff-readonly-gap.md](https://github.com/rlmclmc2-boop/space_idle/blob/a91f65b4/space-battleship/docs/verification/planet-single-side-godot/visual-r2/buff-readonly-gap.md)，原M7场景仍只覆盖当前星球，不能拿单设施来源或重铸按钮充当累计Buff。
- [Planet](../../src/systems/planet.gd)的visual_snapshot/planet_options/is_available可直接用于星体/选择器/实际开放，facility_facts只给设施状态及来源；status_rows是文案，save_state是完整保存快照，prepare_reforge是动作准入，均不替代新读口。
- contributions会写_factors；_contributions还维护_sources并在初始化时修改changes，不能从UI调用，也不能把它当纯只读助手。现有纯_buff只读state/配置，已经拥有原add/mul/max汇总顺序；四项现有贡献字段是equipment_levels、enhancement_levels、free_charge、luck，Session持有其已发布副本。新口只复用这些已存在的来源语义，不拼全局VM/最终效果。

## 最小实现方案（审核后才做）

1. 新增一个Planet.conquest_facts(planet_id)，不给UI私有状态/配置。当前球conquered直接取已接纳标记；本球shared_experience复用原带only_planet参数的crew_exp_share判断，不能仅凭征服标记硬推共享为真。
2. 把_contributions原四项构造最小提取为纯_conquest_bonuses(state,buffs)，原路径与新读口共用。保留四次_buff调用顺序、两个int转换及两个float域，原_buff实现不变；不重新实现叠加、不假设配置编号连续、不恢复已删除行。新读口不求设施倍率、不调用contributions暖_factors，不借读取接纳/推进或新增RunState.fail。
3. rewards仅为全体已接纳征服的四项累计来源，带稳定kind/target、原value/unit与提供方display_text。设备/强化是额外等级计数；免费量是比例而非供能金额；幸运是原幸运加成而非概率。原浮点比例的百分比转换仅作提供方显示格式化，不改业务类型或让UI另算。planet_unlock的实际开放直接复用原公开选择器/可用性，不再添解锁账本。
4. 新增一个Planet实例局部conquest_changed(ids,cumulative_changed)，只围绕征服标记/四项来源的净变化做deferred合并。首次基准必须在真实替换之前保存；读取、设施/探索缓存变化不参与。当前球标记和累计区分开dirty，不让其他星球的普通计时或当前球施工反复重算Buff。

## 实际写入与失效边界

| 已有路径 | 当前源码事实 | 设计要求 |
|---|---|---|
| Planet.accept_reforge | prepare_reforge校验成功后把_state[id].conquered置true、清_factors并刷新开放 | 仅此真实标记写入前捕获通知基准；原准入失败零事件，不能在prepare_reforge预览阶段发新通知。 |
| Planet.restore_state | 完整校验后整体替换_state，清设施/贡献与领取候选缓存；可能改变任意征服标记 | 成功赋值前捕获基准，最终按标记及共用四项值核净差；恢复相同征服集合但探索/建筑不同不发征服通知。 |
| Session.initialize/_restore_modules | 在新实例恢复并调用contributions，随后完成growth/native初始化；UI由宿主Ready后绑定 | UI只绑定正式当前Session；首次读原纯源即可，不制造新缓存账本或把旧_factors缺失伪装为无奖励。 |
| Session.prepare_reforge | 新候选恢复旧Planet→accept_reforge→重新contributions/世界贡献→native配装与新起点完成；宿主再_replace_session | 候选自己的通知不转发到旧页面；原会话未替换时旧累计/标记保持原值。完成后新Session初读/重绑。新口只表达已接纳征服来源，不声称native最终战斗/全事务验收。 |
| claim_build/accept_prepared_claim、advance、set_automatic、人员调整 | 改设施/探索/时钟或人员，不写conquered；领取候选另存_claim_state/_claim_factors | 保留原模块通知，不使本摘要失效；读口不读领取候选或用contributions填缓存。 |

通知比较只在真实征服来源写入处进行，最多持有本批瞬时基准；getter始终由已接纳_state+原纯助手给事实，通知快照不成为奖励权威。未知/未开放对象沿原准入拒绝；非有限源值/读错误明确未知，不填0。合法没有征服奖励的0与未共享false沿原值。不能返回未征服星球未来奖励或把已知零值解释为“数据缺失”。

## 审核后必要定向验证（本次未执行）

- 与原_buff/_contributions及Session发布四项逐项一致，含多球叠加、当前球未征服但其他球已生效、已删除/非连续配置行、原int/float与单位；不把免费比例当实际Reactor供能或最终倍率。
- 冷_factors、领取候选、读取前后完整状态/缓存/通知标记不变；结果深改不污染所有者；未知/锁定/非有限源不伪成功。
- accept_reforge/restore的首基准在赋值前，deferred最终净差、同批合并、A→B→A/同征服集合零事件、回调重入及失败零事件。
- 当前ID标记与全局累计dirty分别过滤；探索/施工/人员/自动开关零征服刷新，隐藏零投影；候选预览/取消不污染当前页面，完整换Session后新读。

本次只作源码与需求静态核对、文档链接/diff检查；不改源码、配置、保存、native或消费者，不运行游戏/测试。未关闭累计Buff或完整M7/V7接入缺口，待原双审后才能实施。本线程已实际压缩；完成本次文档自然项后交接停止。
