# 14 模块前后端连接契约

[回唯一入口](README.md)。本页统一列模块级状态读取、操作与结果、变化通知、前端本地状态和待补接口；玩法仍见01–04，数据/保存见06，纯前端布局、美术与资产接口见[13](13-art-interaction.md)。不新增全能中间层、通用DTO或消息总线，不以本页授权批量重写后端或改C4实现。

## 1. 版本与使用边界

| 标记 | 含义 |
|---|---|
| 主线现有 | 以 `main@08bf2e1e10d69a5edf2e94919ffc9357234129d9` 的源码核对，含已合入的C1容量消费修正。下表第2节仅列此版本确有的端口/连接。 |
| 候选已实现、未合主线 | `rewrite/ui-review-followup@b7bb3de33287783721a8bbd9417f2ea040ad32ff` 中的展示扩展和反馈修正。只有C1已单独合入；其余不能当作主线现有能力或整体通过。第3节显式列出。 |
| 待补/待审 | 已识别的交换数据或展示缺口，不表示端口已经存在，也不默认批准新增字段、规则或实现。先复用现有公开查询，再确认最小增补。 |

来源记录为[共用接口候选及验证边界](https://github.com/rlmclmc2-boop/space_idle/blob/fa1373dd13ca8b8e3eb12d928ede107191f96741/interface-candidate.md)及同提交的[交接说明](https://github.com/rlmclmc2-boop/space_idle/blob/fa1373dd13ca8b8e3eb12d928ede107191f96741/review.md)。候选中的受控回调/历史GPU画面不证明当前主线实操通过；不据历史窄屏证据启动适配或检查，本阶段范围服从入口的桌面宽屏要求。

后端拥有规则、费用、Amount、容量/解锁、进度、随机、候选接纳和真实状态。前端只读必要事实、提交稳定对象ID与候选输入、显示实际结果；跨模块动作走现有GameSession协调口或注入callable，普通模块动作保持所属模块直调。**读取查询、命令和消费事件必须区分，不能把所有返回Dictionary的方法当作只读查询。** 不由UI重复计算成长、报价、MAX、伤害、研究速度或任务推进。

购买／升级处的 ×1、×10、MAX 是一个循环数量键的三个显示状态，顺序固定 `×1 → ×10 → MAX → ×1`；旁边仅有一个执行购买／升级的动作键。报价、当前数量键、执行键须构成同一操作组，布局按新关系重新设计：数量是报价条件，执行键是唯一提交动作，不能遗留旧三键空槽或把单键机械拉长。点数量键只更换本地候选并读取对应报价／可购买事实，绝不能调用购买、支付、发布通知或改动领域状态。点执行键才按当前模式走所属模块既有命令；MAX 的求值和部分成交继续由后端拥有。前端对每次候选切换、余额／对象变化及执行结果刷新同一对象的显示，不能用旧报价搭配新数量。

两键操作组绑定同一个稳定对象与数量模式：同一横向操作关系中数量键在左、唯一执行键在右，报价与当前模式先于这对键被读到；均分等独立动作有自己的作用范围，不夹在两键之间。数量键显示当前模式，报价与可购/禁用理由必须由该模式的当前 Owner 查询得出，执行键只消费这组仍有效的事实；对象切换、余额/等级变化或命令完成时使对应报价失效并重读，保留应保留的本地选择与焦点。视觉上的普通、悬浮、按下、选中、禁用、焦点及组合态、字形净空、材质和效果层序统一按[13第 2.3 节](13-art-interaction.md#23-所有模块共享的状态与反馈)及各 M/V 落实，不把像素安全区或贴图层序写进后端端口。装备候选由 Equipment/Session 现有比较和报价口负责，反应炉候选由 Reactor 的 `presentation_model`、`purchase_preview`、`purchase_max_preview` 与既有命令负责；这些候选端口仅在实际接入版本存在时调用，不把它们倒填为上文旧 main 基线的现有能力。公共壳的导航、余额和输入焦点协调不替模块重算报价、替换内部按钮或覆盖旧特效。资源金额仍取 Owner／Economy 事实；余额、报价、奖励和掉落的视觉身份统一调用 [13 第 2.2 节](13-art-interaction.md#22-全局信息层级与适配) 所列 `ResourceVisuals.icon(id)`／`icon_modulate(id)`／`color(id)`。各模块只替换自己费用与奖励的图标呈现，不能借资产接入改变价格、结算或掉落规则。

费用不足按[13 第 2.3 节](13-art-interaction.md#23-所有模块共享的状态与反馈)逐资源标记：所属模块以当前模式的报价逐项调用既有 Economy `can_pay`／预算端口，只将不足项的**消耗值**文字标红，资源名与图标保原色；“费用”标签－图标－资源名－消耗值在同一排，三处文字同字号同基线、图标垂直居中且各留固定小间隙，双费用与长数也按同一节奏，不用省略号丢量级或越出卡片；不以合并后的总布尔值染整行，也不常驻另一个不足原因。数量键不调用购买、不弹失败；执行键即使余额不足仍可按 Owner 允许的业务入口提交并接收普通 `InsufficientResources` 拒绝，再显示短暂提示且不扣费。其他拒绝和停机不受此例外覆盖，MAX 无可购数量等边界继续由所属 Owner 判定；不得为求提示绕过命令或自行改支付语义。当前装备逐槽参考实现入口为 `src/ui/equipment_panel.gd::_refresh_card/_render_fees/_cycle_slot/_buy_slot`；其他模块由原组按各自 Owner 端口接入，不将该局部实现宣称为全模块已完成。

跨页控件的选择／关闭、提交、选中、禁用与焦点视觉角色依 [13 第 2.3 节](13-art-interaction.md#23-所有模块共享的状态与反馈) 同版整屏核对；角色层级属于前端样式契约，不改上述两键命令、报价 Owner 或业务刷新边界。公共控件由整体组实现，星球内页控件由星球组实现，装备和反应炉内区各归原组。

## 2. 主线现有模块连接

以下文件名均指 `src/ui/<名称>.gd`；公开方法由对应 `src/systems/<模块>.gd` 或 `src/game_session.gd` 提供。结果解释及接纳顺序见第4–5节；不要求所有命令拥有同一组附加返回字段。

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 战斗/航程/拾取：battle_view、battle_hud、campaign_view、economy_view、attributes_panel | Battle `hud_values/statistics/attribute_details/presentation_clock`；Campaign `status_text/progress_facts`；Economy `balance_rows/drop_markers/budget` | 表现绑定/绘制；Campaign `toggle_guard`、Session `set_pause`；Economy `collect_at` 后调用注入的 `refresh_growth`。`consume_damage_receipts`另按第4节单一消费 | Campaign `status_changed/progress_changed`；Economy `display_changed`；native表现按帧读取 | 伤害数字寿命、HUD展开、显示变换和悬停。拾取输入先逆变换到逻辑战场；不改共享命中几何。 |
| 舰体：fleet_panel | Campaign `ship_options/ship_facts`，后者提供 `mounts/drone_capacity` | `change_ship` 调用注入的 Session `commit_ship_refit`；保留原换舰截断和native接纳结果 | `ship_changed/progress_changed` | 候选舰、选中态与预览；不能将预览尺寸当战斗尺寸。 |
| 装备：equipment_panel | Equipment `panel_slots(mounts,ids)/panel_equipment/price_text`；Session `equipment_inputs`；公开 `quote_slot(slot_id,count)`可给确定数量报价，当前页面主要显示下一级价 | `buy_levels/buy_max_levels/buy_all_levels/equip_slot`；注入 `affordable/payment/publish_equipment_levels/publish_equipment_refit` | `slots_changed(ids)/loadout_changed/options_changed`，可见帧合并失效对象 | 当前槽与候选装备、输入、焦点、滚动、展开；冷却/余额是后端事实。 |
| 反应炉：reactor_panel | Reactor `panel_options`；Session `reactor_inputs` 提供容量因子与免费供能输入，不能据此冒充已有完整分配展示模型 | `purchase/allocate_text/distribute`；注入 `payment/publish_reactor` | `choices_changed`；主线没有专用 `presentation_changed` | 设备选择与金额草稿、控制区展开；实际分配与增益归Reactor。 |
| 科研：research_panel | Research `panel_model/choices`；panel_model提供选项、当前每资源投入、自动开关和比例，不是完整工作进度舞台模型 | `select/set_investment_text/set_automatic`；返回原拒绝/成功事实 | `choices_changed/investment_changed` | 每资源投入草稿、自动比例草稿、焦点和选择；刷新不能将草稿伪装成已生效值。 |
| 强化：enhancement_panel | Session `enhancement_inputs` 提供bonus、开放查询及装甲数，当前是操作准入输入；主线无专用页面 `presentation_model` | Enhancement `purchase/set_branch/move_forward`；注入 `affordable/publish_enhancement` | 主线没有专用强化 `presentation_changed`；不能假定它已通知界面 | 效果/节点/分支候选与展开；有效顺位、门槛和数值仍由Enhancement决定。 |
| 船员：crew_panel | Crew `member_options/status_rows/job_options`；Planet/Galaxy `assignment_options` 提供任务身份；Planet `assignment_capacity`、Galaxy `assignment_admission`为各自领域端口 | Session `coordinate_assignment(member_id,kind,target,...)`；保留唯一占用与原协调结果 | Crew `members_changed(ids)/options_changed`；Planet `assignment_options_changed/availability_changed`，Galaxy `availability_changed` | 选中成员、派遣候选与筛选/滚动。按kind/target关联任务，不能越权读目标私有账本。 |
| 星球：planet_panel | Planet `planet_options/status_rows/building_options/visual_snapshot`；注入视觉上下文paused/speed | `set_automatic/claim_build`；注入 `coordinate_planet_cancel/publish_planet_claim` | `status_changed(ids)/buildings_changed(ids)/availability_changed`；主线面板未接入Crew人数通知 | 选中星球/设施、视角、详情与终端开合。owned仅消费已建成快照；ready与领取分开。 |
| 星系：galaxy_panel | Galaxy `status_rows/assignment_options/visual_snapshot`；上下文来自Crew `galaxy_assignments`及Session暂停/速度 | 当前星系面板主要读地图；派遣通过crew_panel的 `coordinate_assignment`。探索/施工/升级由Galaxy推进 | `status_changed(keys)/availability_changed`；主线面板未订阅Crew变化，没有候选的所选节点详情刷新链 | 当前区域、节点选择、pan/zoom和详情开合；不能在UI推进工程量。 |
| 超空间：hyperspace_panel | Hyperspace `routes/online_status/manual_receipt/warehouse/module_growth/filter_configuration/legend_collection/player_catalog/material_ids`；钱包由Economy `budget`提供 | Session `start_hyperspace_manual/start_hyperspace_single/start_hyperspace_auto/claim_hyperspace/equip_hyperspace_drones/set_hyperspace_hangings/dismantle_hyperspace_drone/exchange_hyperspace_materials/save_hyperspace_preset/apply_hyperspace_preset/preview_hyperspace_forge/forge`；模块 `organize/set_favorite/set_filter/import_filter/export_filter/set_legend_collected/release_sealed` | 主线没有领域变化信号，当前界面每秒读取并保持选择；不是已具备对象级通知 | 仓库区/筛选/选择、编队与改造草稿、预览fingerprint/source/operation_id/完成状态。原请求绑定、失效和幂等仍有效。 |
| 档案/通知/设置：archive_panel、notifications_panel、main | Battle `enemy_intelligence/statistics`；教程completed；Notifications `entries/unread`；PlayerSettings及SaveFiles原状态口 | Notifications `mark_seen/mark_read`；main中导入/新游戏/重铸预览、确认与取消；设置与保存协调 | Notifications `changed`；保存通过现有poll/状态读取。主线反馈没有候选的完整重显/持续摘要修正 | 路径、导入来源、待确认摘要、展开、焦点与错误呈现；候选Session、文件备份/恢复与保存事务仍由原所有者控制。 |

## 3. 候选展示扩展与尚未补齐的交换

**下表“候选”均只在第1节指定的候选代码存在，未因文档收录而进入主线。** 新前端可据此评估接入依赖，不能直接调用不存在的主线方法，也不能以读取私有字段替代缺少的端口。

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 舰体/装备 | Battle `hull_presentation`；Equipment `presentation_slots/equipment_comparison`；Session `equipment_presentation_inputs` | 舰体开放的结构化门槛；批量/MAX的本次总费/数量展示。确定数量报价先复用主线quote_slot；MAX预览若需公开，必须复用原求值，不在UI复制算法。 |
| 反应炉 | `presentation_model/allocation_preview/adjust_allocation` 及 `presentation_changed` | 与前端设备身份、工作/停机和编辑器连接；资产锚点属于前端，不向后端新增像素字段。 |
| 科研 | Research `presentation_model`；Session `research_presentation_inputs`；页面注入真实暂停、人员和时间事实 | 清楚显示未应用草稿、暂停后的预计时间口径和岗位续研状态。已有字段先正确消费，不能重新计算研究速度。 |
| 强化 | `presentation_model/presentation_changed` | 当前有效数值及A/B具体增量的充分展示；如输出不足，在Enhancement复用实际效果求值形成最小展示输出。 |
| 船员/星球 | Crew `assignment_count(kind,target)`；候选页面将人数事实接入星球详情并订阅成员变化 | 目标人数/容量/任务进度的充分关联展示；各目标模块提供自己的公开事实，不新增通用任务账本。 |
| 星系 | `node_presentation(region,id)`；候选面板订阅Crew变化，可见所选详情每250ms只读刷新 | 完整发展阶段、撤人/恢复与升级结束实操未通过；不能用静态字段存在代替该验收。 |
| 超空间 | 只读 `forge_display_limits(id)`；页面补究极核心余额、预兆/究极词缀/传说参数、装卸对象与具体拒绝原因 | 仓库/挑战对象级通知仍无实现。若需增补，只加受影响对象/状态的最小通知，不重写成全模块事件广播。 |
| 设置/危险确认 | 统一反馈重显；导入/新游戏/重铸的持续预览区域及来源变化/取消清除 | 主线尚无该修正；完整真实保存故障、恢复和危险事务实操仍需覆盖。持久预览不能只靠六秒吐司。 |

候选新增查询的最小字段截面如下，均为展示输出而非新增全量业务状态副本：

| 候选查询 | 已有候选字段 |
|---|---|
| Reactor.presentation_model | `level/capacity/remaining/load`；modules行 `id/name/enabled/allocation/free/effective/factor/ratio/load`，区分手动、免费、有效供能和最终增益。 |
| Research.presentation_model | `speed/remaining/rows`，行内 `id/name/level/active/available/work/required/progress/effect_summary/effect`；不由UI推进工作量。 |
| Galaxy.node_presentation | `name/state/level/effect/bonus/explored/reachable/explore_remaining/construction_remaining/upgrade_remaining`；人数仍由Crew事实按区域关联。 |
| Hyperspace.forge_display_limits | `affix_limit/hanging_limit/reroll_ranges[]`；范围行 `kind/key/minimum/maximum`，普通词缀另有tier。不表示随机结果已取得。 |

## 4. 查询、操作结果与单一消费事件

- 查询结果按只读消费；只把方法实际保证的副本/只读性作为保证，不推定所有Dictionary都深只读。显示缓存不能成为业务真相，不经float重建Amount；概率、坐标和秒数仍按现有类型处理。
- 命令传稳定ID与候选输入。普通拒绝保留可修正的草稿并显示领域reason；`message`可能由当前页面补充，不假定所有命令都有统一details、new_level或balance字段。成功后读取对应模块当前值、实际费用/余额和效果，不以动画或控件变化冒充提交成功。
- 跨模块接纳遵守第5节。保存请求的 `ok`/generation只代表请求已接受或排队，不自动等于磁盘完成；失败、busy和持久完成继续读取SaveFiles状态。
- 危险预览要持续到确认、取消或失效。对象/来源/输入改变后不能确认旧预览；重复确认保留原幂等保护，不重新扣费。预览、前后对照与实际余额应绑定同一对象身份。
- **`Battle.consume_damage_receipts()`不是只读查询。** 它在 `src/systems/battle.gd:215–218` 从_events提取kind=8并移除。当前唯一调用者是 `BattleView._process`（`src/ui/battle_view.gd:25`），由它一次消费、生成伤害数字并发出既有damage_received音效信号。HUD、统计、其他页面和调试观察者不得再次调用，避免先取走/吞事件；它们使用hud_values/statistics/attribute_details等独立查询。
- 伤害回执是帧内表现事件，可受显示预算限制，不是完整持久伤害账本，也不能据此结算奖励。若未来需要复用同批表现信息，由单一消费方在消费后提供局部只读副本，不各自drain；不为此新增业务广播链。宿主/native的业务结果仍由既有单一业务入口接纳。
- 变化通知只使相关对象/选项失效，在可见显示帧合并读取。隐藏的局部舞台停止无用刷新，但业务时间/任务不因页面隐藏而停下；缺少通知的模块如仍轮询，必须明确为现行事实，不能冒充已具备信号契约。

## 5. 既有跨模块接纳与通知约束

下列内容自05的“现行模块交接契约”移至本页集中维护；属于原有接纳约束，不是本次新增统一协议或每条实现已完成实操验收的声明。此表是后端所有者之间的协调协议，不是前端可直接调用的接纳清单；UI仍从第2节的动作或注入callable进入，不调用accept_*或native提交口绕过协调。

**既有分工约束：** 模块前后端仅通过必要的领域状态、具名操作、操作结果及变化通知交接；后端负责规则与真实状态，前端据此独立设计布局、美术与控件。画布、安装框、锚点、贴图和效果等纯表现元数据属于前端资源契约，不混入业务协议；确有命中用途的共享几何仍按既有native契约处理。具体主线端口与候选状态见本页第2–3节，不增设另一套通用协议。

模块化的边界是业务入口和结果，不是信号连接顺序。模块只能拥有自己的候选与已接纳状态；`GameSession` 只协调具名端口，不读取候选内部字段来决定下一步，也不以 UI 通知承担接纳。入口返回 `ok=true` 表示本次业务交接已完成；`ok=false` 且 `fault` 不为真表示普通拒绝，当前子命令的所有者保持原状态。批量购买可能先接纳已成交子项，再返回后续子项的拒绝，已成交部分不回滚。native 或几何在提交中发生致命故障时 RunState 停机，不假装已回滚。通知只在所有受影响所有者完成接纳后发出；监听者同步读取应得到同一批状态。发出通知后，外层调用不得再写回该批的旧候选，以免覆盖监听者的重入操作。

| 所有者 / 入口与输入 | 输出与成功含义 | 状态、拒绝、故障和通知 |
| --- | --- | --- |
| Equipment `equip_slot`、`buy_all_levels`、`resize_mounts`：部位/选择、当前装配事实、报价与支付、`publish_equipment_refit` 或 `publish_equipment_levels` | `ok` 表示 native 接受且装备候选、钱包、船型/必要撤退已接纳；批量购买允许已成交部分保留，空批次返回 `NoChange` | Equipment 独占槽位候选和槽位账本；Session 调用 `accept_prepared`，再发布 `slots_changed`/`loadout_changed`。普通报价、支付或 native 拒绝丢弃候选；致命故障停机。防御换型按[03第1.4节HealthAdjustment](03-progression.md#14-容量改变时的生命规则)保留同类总当前/总最大比例并重建模块损伤；未决仅为[03第1节首槽换型](03-progression.md#1-舰体槽位与升级)本身使两类当前余量均为0时是否立即进入死亡判定。 |
| Enhancement `purchase`、`set_order`、`set_branch`：可用性/装甲数、报价、native 发布口 | `ok` 表示强化状态、native 值及钱包/必要撤退全部接纳；无变化跳过 | Enhancement 独占强化候选，经 Session 的 `publish_enhancement` 后显式 `accept_prepared`；不发业务接纳信号。拒绝不写强化或钱包，致命 native 故障停机。 |
| Reactor `purchase`、`allocate_text`、`distribute`、`refresh`：容量、开放模块、支付与 native 发布口 | `ok` 表示分配状态、native 值及钱包/必要撤退已接纳 | Reactor 独占 `_prepared_state`；Session 调用 `accept` 后更新贡献和钱包。普通拒绝丢弃候选；致命故障停机。`choices_changed` 仅作接纳后的 UI 提醒。 |
| Planet `claim_build`：建筑、贡献发布口 | `ok` 表示建筑、世界贡献、native 和必要撤退均已接纳 | Planet 独占建筑候选；Session 通过 `accept_prepared_claim` 显式接纳，再发建筑/开放通知。普通拒绝不改变建筑或世界贡献；故障停机。 |
| Campaign `advance`、`observe_battle`：固定步长、native 战斗结果、终波领取口 | 返回位置变化事实；清关和新关事实在完整关卡位置/战点更新后可见 | Campaign 独占关卡、波次、驻守和撤退。`take_progress_changed` 交给 Session 同步 Research、Reactor、Equipment、Crew、Planet、Galaxy 的开放缓存和必要贡献；之后才发布进度与状态通知。终波收取先批量接纳，随后统一通知。普通关卡拒绝不推进；native/几何故障停机。 |
| Economy `payment`、`accept_budget`、`collect_due`：费用、候选钱包、拾取时间和收益因子 | 支付只返回候选钱包；`accept_budget` 后才归属变更；批量领取返回 `collected` | Economy 独占余额、掉落和收入历史。通知可延至跨模块接纳后；终波多个掉落合并通知。拒绝不扣款或领取；已领取后续致命故障停机，不虚构回滚。 |
| Battle `commit_player`、`commit_values`、`advance`：准备好的战斗描述与变更种类 | native 接受后返回 `ok`/`defence_changed`；结果只含已发生的战斗事实 | Battle/native 独占战斗状态与攻击出生快照；普通拒绝不接纳外部候选，`fault` 触发 RunState 停机。Session 只根据公开结果完成其他所有者接纳。 |
| Research `refresh_progress`/`advance`、Crew `refresh_availability`/`contributions`、Galaxy `refresh_availability`/`contributions`：Campaign 开放查询或时间/分配事实 | 返回开放变化或贡献；成功后由所属模块持有状态 | 各模块独占自己的开放缓存与进度。Session 先同步相关缓存及贡献，再调用独立 UI 通知端口；不以模块私有字段或消费者刷新顺序作为契约。普通拒绝保持归属状态，推进中故障停机。 |

一次命令的时序为：模块校验并保留候选 → Economy 给出候选钱包 → Session 组装并提交 Battle/native → 所属模块显式接纳 → Session 接纳钱包、世界/研究/反应炉贡献、船型与必要撤退 → 发布各模块展示通知。没有效果的命令跳过提交；部分批量成交只提交已成交部分。通知可同步重入，新命令必须看到上一批完整状态，上一批外层调用此后不再改写它。

终波的 native 掉落登记与强制领取先静默进入 Economy；Campaign 完成清关事实，Session 同步开放缓存，再按本步最终收入刷新贡献，最后合并发布掉落/余额、开放和进度通知。非终波新掉落也在该步 Campaign 处理完成后通知。致命 native 或几何提交故障的公开结果保留 `fault=true`，供调用者区别于普通拒绝。

## 6. 前端本地状态与资产接口

选择、草稿、焦点、展开、滚动、pan/zoom、显示变换、临时反馈与待确认UI记录属于前端；已付等级、钱包、实际占用、进度、随机、有效贡献与保存事实归后端。前端本地状态不能回写为领域状态，刷新不得覆盖未提交草稿；对象失效时清除旧详情并阻止向旧ID提交。

模块状态先映射为设备身份、运行/停机、进度、选中等前端显示输入，再由美术和控件消费。画布、可见边界、底座/管口锚点、允许裁切区、点击区、文字安全区、图层与导出约定只在[13全局规范及相应M/V](13-art-interaction.md#3-按模块读取设计与验收)定义；不把资产坐标加入经济/研究/分配领域对象，不将金额或进度烘焙进图。真正参与命中的共享几何继续使用既有native契约。

资产、布局与业务可以分别迭代，但以相同稳定对象ID和公开端口连接。需要新交换数据时先确认所属模块已有端口及最小缺口；不以本页的新设计表述自动授权后台、递归/父身份、保存格式或玩法变更。C4仍以裁定清单的只读审核/待定状态处理。

## 7. 已实现出口：敌盾与双条的最小战场展示契约

**状态：最小只读展示出口已实现；不代表双条画面、G9或全场性能达标。** 实现前设计核对基线为`main@6b8c266556b0b95d8aaa3a97a5a756bd98f653f5`；仅该实现前基线中涉及的运行代码与`317548d7`一致。依据为[只读核对012283f4第6节](https://github.com/rlmclmc2-boop/space_idle/blob/012283f42725aeb8fb316a585489e79284329f95/g0-envelope-and-godot-coordinate-review.md#6-追加可达敌阵的占位归属及三项装配边界)。范围只含敌舰盾状态、双条数值与定位；无人机锚点、敌阵重排、完整装配包络及G9验收分别待定，不混入此提案。

实现版本为`7f77acf6`，dirty合并修订为`f4ccf4ca`。验证记录、适用边界与成本限制见[定向语义证据](../verification/enemy-presentation/7f77acf6/README.md)及[成本证据](../verification/enemy-presentation/cost-7f77acf6/README.md)。

### 7.1 实现前基线与已实现出口

| 层 | 实现前基线 | 已实现最小增补 |
| --- | --- | --- |
| native Actor | 持有`generation/uid`、`hp/max_hp/shield/max_shield`及存活事实；战斗推进、受击和恢复仍由核心负责，运行中的generation会因生命周期失效而改变。`enemy_views()`缓存行当前有uid、位置、hp、dead、视觉身份等，未输出完整盾甲值/上限。 | 沿原`enemy_views`内部读取链补展示出生代数及`max_hp/shield/max_shield`，展示出生代数取安装时冻结的generation，保留既有hp/dead；不改Actor生命周期，不新增另一套账本、数值求解器或面向UI的native调用口。 |
| Battle | 已有共享敌轮廓/锚点及`draw_enemy_overlays`；玩家`hud_values`已有盾甲当前/上限/比例。敌情`enemy_intelligence`目前没有最大值，shield缺字段时返回0，不能据它绑定真实盾条。 | 已提供具名只读`enemy_presentation()`，将核心事实与当前共享几何关联成下表行；敌情等既有消费者仍经Battle，若复用新字段由Battle内部适配，不要求本轮重写其页面。 |
| 前端 | BattleView与HUD已有绘制/刷新路径；没有完整敌盾/双条绑定。 | 敌盾/双条数值和定位只从Battle新入口读取；前端拥有外缘美术、条形布局、投影、显隐与过渡，不读`_kernel`、`_enemy_hulls`或存档，不从伤害回执倒推余额。 |

`Battle.enemy_presentation()`返回只读行数组，以下字段均为必要输出，不增设通用响应封套：

| 字段 | 类型/来源 | 消费含义 |
| --- | --- | --- |
| `id` | 不透明String，由Actor安装时冻结的generation与uid派生 | 同一安装实例的稳定展示身份；死亡、撤退后的运行中generation不得覆盖其展示出生代数。数组下标、mon配置ID、槽位和显示名称都不能替代它，前端不解析组成。 |
| `visual_key` | String；复用既有敌舰视觉身份 | 供前端关联该舰的外缘资产/样式，不从数值size或终波序号猜模型，不传native对象或内部句柄。 |
| `origin`、`body_bounds` | Vector2、Rect2；来自同一敌舰当前共享逻辑锚点与舰体轮廓 | 都是战场世界坐标，仅承诺双条与外缘的粗定位。body_bounds只含舰体，矩形不表达贴轮廓形状，也不是炮台/护盾/文字的完整包络，不据此关闭G9；贴轮廓与完整装配外缘需求待前端具体设计后按M1单独定稿，不预先扩展通用接口。 |
| `dead` | bool；核心存活事实的映射 | 前端决定隐藏/退场；不得用单条归零、盾甲相加或贴图状态另判死亡。 |
| `armour`、`max_armour` | String；分别映射核心`hp/max_hp`的Amount规范十进制文本 | 仅展示敌装甲当前值与上限；不是另建装甲状态或改生命规则。 |
| `shield`、`max_shield` | String；核心Amount规范十进制文本 | 区分无盾上限与有盾但暂时耗空；禁止缺字段时用0伪装已接线。 |
| `armour_fraction`、`shield_fraction` | 有限float，范围[0,1]；native使用与Amount `to_ratio`相同的类型化`Amount.ratio`路径，Battle转交缓存 | 仅作绘制比例，不反算金额或回写业务。最大值≤0时比例为0；最大盾>0、当前盾为0仍是耗空盾条，不等于死亡。 |

### 7.2 身份、快照与失效

- 身份稳定性限于当前Battle绑定生命周期。主线和异空间各自分配uid，不能只靠uid跨编队复用前端节点；安装时将当时的generation与uid冻结为该展示实例的出生身份，再由Battle形成id。后续死亡、撤退引起的Actor.generation递增只沿用既有生命周期语义，不改写展示出生代数，避免同一实例在退场时换id。换波重新安装形成新身份；会话替换/恢复或Battle重建时，装配处重新绑定并清空旧视图缓存，不要求恢复前后展示id连续。不把展示id写入存档，也不改变既有Actor、Encounter/Attack身份或保存水位。
- 同一次读取的数值、dead与几何必须来自一次已完成推进/接纳后的状态。换波、清场、撤退、恢复及共享几何更新后使对应展示缓存失效；行从完整快照消失或dead为真时，前端清除旧锚点/交互，过渡只保留其本地副本，不再绑定旧对象。
- native沿既有`actor_view_changes`更新：安装标记初始展示字段并写入上限；当前值/上限、受击仅耗盾、盾恢复及dead变化都必须使对应行失效并更新，不能只等hp变化。同一读取间隔内的命中/恢复仅向既有dirty集合合并盾甲字段位，在`enemy_views()`重建只读快照时从最终已接纳的类型化值投影一次；dead单独变化不重算盾甲文本或比例。恢复继续在现有战斗推进处结算，查询不得调用advance或恢复结算。
- Amount规范文本只在对应当前值或上限事实变化时生成；每条比例只在其当前值或上限变化时经Amount计算。安装后的首次快照生成初始展示值，未变化的上限文本与几何继续复用；几何仅在对应共享几何事实实际变化或重新安装时更新。当前盾变化不得触发静态上限与几何重算，显示帧和UI尺寸变化也不触发这些重算。
- BattleView在可见显示帧合并读取一次即可；不加全模块广播、每弹事件通知或UI业务轮询器。native可按失效事实重建只读显示缓存，多次读取只复用或装配该缓存，不消费领域结果或伤害事件，不按显示帧重新生成Amount文本、比例、静态上限或几何。隐藏视图不停止Session推进；重新显示读取最新完整快照。

### 7.3 隔离、Amount与绑定边界

原始Amount保留核心语义，以规范文本越过展示边界；不得`float(armour)`后除上限，或由条长重建数值。比例在native只读行缓存重建时直接使用已接纳Amount值的`ratio`（与`FoundationAmount.to_ratio`同一路线），按第7.2节的dirty字段变化合并生成，Battle仅映射缓存；死亡后的实际文本不因绘制比例钳制而被改写，前端按dead处理退场。现有`_hud_fraction`把解析或比例计算失败回退为0的吞错分支只是当前实现事实，不是本契约允许把失败解释为合法空盾的语义，也不承诺原样复用整个函数。

所有只读 Amount 数字在 UI 层统一用 `PlayerText.number(native_to_display_text)` 呈现；单位、一位小数及进位边界以[13 全局数字显示](13-art-interaction.md#20-整屏构图与全局ui)为准。此格式仅改变展示文本，原 Amount、比例、报价、支付及领域命令仍使用所属公开端口的原值；不得从缩写文本倒推业务数值。

只读展示查询只映射已接纳事实与展示缓存，不新增`RunState.fail`、初始化/接纳或重复领域校验职责，不在查询中重新验证Amount、几何或生命周期。事实有效性及原有故障处理继续归既有初始化、命令/接纳和战斗推进入口；不得为弥补`_hud_fraction`吞错而在读取路径另建校验或停机链。缺字段或比例计算失败不构成合法空盾，具体实现须保持这一语义且不扩大查询职责；本契约不改现有故障政策。

玩家继续使用`hud_values`，敌舰使用上述具名入口；Battle是前端接触战斗所有者的边界，native仅供Battle内部读取。现有绘制、统计、敌情端口不因“唯一边界”改成一个全能模型。`consume_damage_receipts`仍由BattleView单一消费，新查询不能drain事件；读接口不支付、不保存、不改时钟/随机/目标。

盾外缘形状、完整包络、双条偏移/间距/字号归前端资源与布局；`origin/body_bounds`只提供双条/外缘的世界粗定位，不传窗口像素或固定UI安装框，也不承诺仅靠矩形实现贴轮廓。若具体前端设计需要贴轮廓数据，先明确该设计的最小缺口再另行评审，不在本契约提前增加通用轮廓或包络接口。前端使用统一的世界到界面映射，只投影一次。无人机真实炮口、敌阵坐标或任何共享碰撞几何变更，须分别提案，不能随本接口落实。
