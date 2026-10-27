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

只读展示查询只映射已接纳事实与展示缓存，不新增`RunState.fail`、初始化/接纳或重复领域校验职责，不在查询中重新验证Amount、几何或生命周期。事实有效性及原有故障处理继续归既有初始化、命令/接纳和战斗推进入口；不得为弥补`_hud_fraction`吞错而在读取路径另建校验或停机链。缺字段或比例计算失败不构成合法空盾，具体实现须保持这一语义且不扩大查询职责；本契约不改现有故障政策。

玩家继续使用`hud_values`，敌舰使用上述具名入口；Battle是前端接触战斗所有者的边界，native仅供Battle内部读取。现有绘制、统计、敌情端口不因“唯一边界”改成一个全能模型。`consume_damage_receipts`仍由BattleView单一消费，新查询不能drain事件；读接口不支付、不保存、不改时钟/随机/目标。

盾外缘形状、完整包络、双条偏移/间距/字号归前端资源与布局；`origin/body_bounds`只提供双条/外缘的世界粗定位，不传窗口像素或固定UI安装框，也不承诺仅靠矩形实现贴轮廓。若具体前端设计需要贴轮廓数据，先明确该设计的最小缺口再另行评审，不在本契约提前增加通用轮廓或包络接口。前端使用统一的世界到界面映射，只投影一次。无人机真实炮口、敌阵坐标或任何共享碰撞几何变更，须分别提案，不能随本接口落实。

## 8. 已审待实施：成员、设施与选中节点的最小只读事实

**状态：已审待实施；不作为主线已有方法。** 本节只约定当前成员、当前设施和当前节点事实。审查依据与未覆盖项另见[核对记录](../verification/frontend-contract-audit/colony-readonly-proposal.md)。比例/预算意图、整组原子调配、动态战斗效果和未来效果预测不在本节范围。

### 8.1 共同读取与身份边界

- 方法仅投影已接纳事实和必要的只读缓存；不调用推进、派遣、领取、接纳、支付、RNG或保存，不借读取新增RunState故障/重复领域校验职责。候选或命令完成后才可见的字段不得提前冒充实际值。
- 对外数组、行及嵌套数组/字典均为脱离所有者的快照或递归只读值。Amount以既有规范文本输出，显示比例为有限float且仅用于绘制；不经float重建Amount、经验门槛、贡献或费用。没有适用值用下文约定的null/空字段，不以0伪装未知。
- Crew成员id沿用配置String；设施身份是`(planet_id, id)`，planet_id沿用主线的规范十进制String、id沿用实际设施定义键；节点身份是`(region_id, id)`，id为当前公开region.nodes的String键。不得使用显示名、列表位置或演示中的1–30编号替换实际键，也不新增跨模块通用ID编码。
- 会话替换/恢复或模型重建后，装配处清除旧选择绑定与缓存；不存在/不可见对象从当前结果消失时，前端清除旧详情并停止向旧对象发命令。本节不增加保存字段或承诺跨会话展示缓存连续。
- 保留`Planet.visual_snapshot`的星体/探索时钟、`Galaxy.visual_snapshot`的地图/父连接、`Crew.galaxy_assignments`的区域人数及现有准入接口。位置、头像映射、模型family、设施屏幕锚点、控件草稿和视角属于前端资源/本地状态，不进入本节输出。

### 8.2 Crew：成员事实

拟增`Crew.member_facts(ids: Array = []) -> Array`。空ids按现有成员选项顺序返回当前可用成员；显式ids只查询这些配置成员，未知id不生成行。显式查询已知未开放成员时，只返回`id/name/available=false/reason="CrewLocked"`，不伪造其可用人物状态。该接口不负责选出“下一个解锁成员”或新增开放门槛算法。

| 必需字段（可用成员行） | 类型、单位与来源 | 消费边界 |
|---|---|---|
| `id/name/available/reason` | String/String/bool/String；成员配置身份、原可用性缓存；可用行reason为空 | 名称是纯配置名，不从member_options的格式化名称拆等级。available不是任意目标派遣已获准。 |
| `level/experience_enabled` | int/bool；实际等级及既有`experience_enabled()`事实 | 等级不加1或套演示等级；经验功能未开放不展示虚构进度。 |
| `experience/experience_required/experience_fraction` | 经验点数的Amount文本；下一等级所需Amount文本或null；有限[0,1]或null | experience为已扣除已升等级费用后的实际余量；required复用现有单级经验求值，fraction由Crew经Amount生成。功能未开放或现有等级范围已无下一等级时，required/fraction为null，不新增等级上限规则。 |
| `kind/target/mode` | String/String/String；现有唯一占用记录 | kind沿用空闲空串、system_job、planet_explore、planet_build、galaxy、hyperspace；target保持现行含义，mode沿用1/10/max。展示不拆中文岗位串，不将一份成员复制为多个占用。 |
| `reservation_reason` | String；无保留为空，在线任务保留沿用`HyperspaceCrewReserved` | 只提示普通派遣/释放受限；停止/领取仍走对应在线任务入口，目标合法性与容量仍由既有准入和命令确认。 |

成员事实不承诺按单人等级计算岗位的聚合增益、未来岗位收益或动态战斗乘数。已有成员/岗位选项与派遣命令保持原入口。

### 8.3 Planet：设施事实

拟增`Planet.facility_facts(planet_id: String, explorers: Dictionary, builders: Dictionary) -> Array`。未知或未开放星球返回空数组；可用星球仅返回其实际适用设施，包含locked/building/ready/built。explorers/builders由装配处在当前Session的可见显示帧同步新读`Crew.step_assignments()`并即读即传，不复用固定步开头缓存的people；它们是同名只读临时视图：按星球键与现有施工目标键映射成员id数组，形状与现有Planet推进输入一致。视图不得自报人数，Planet不留存这些人员视图或另建占用账本。

| 必需字段 | 类型、单位与来源 | 消费边界 |
|---|---|---|
| `planet_id/id/name/type/state` | String；现有星球、设施定义及真实状态枚举 | built表示已领取，不输出另一个owned领域状态；设施资产由实际id/type关联，不按四个演示槽位补不存在设施。 |
| `work/required_work/unlock_exploration` | int；已累计的探索完成次数/所需次数/开放所需探索次数 | 复用设施work、build_explore、unlock_explore；不是游戏秒或未来完成时间。跨门槛的那次探索是否计入施工仍服从现有推进规则。 |
| `work_fraction` | 有限[0,1]float；由Planet根据现有有效计数生成 | 只供条形显示，不由条长回写工程量；不重新解释施工规则。 |
| `extra_crew_required/builders_present/explorers_present` | int；配置额外施工人数及临时人员视图中该实际目标人数 | 额外人数为0不表示无需探索；字段不是派遣许可，继续用现有assignment_capacity及Session协调命令。 |
| `pause_reason` | String；仅building行按既有推进前提投影：`ExplorationNotRunning`、`NoExplorer`、`MissingBuilders`或空串，按此顺序取首项 | 仅为设施不能随探索完成而推进的原因；其他状态为空。全局暂停/倍速沿原上下文，不混入设施状态或自建暂停。 |
| `claim_allowed/claim_reason` | bool/String；复用当前星球可用性、ready状态及原命令准入条件的只读判断；允许时reason为空 | 不执行_claim_build或预先接纳；仍须由claim_build按提交时事实判定，不增加统一错误/回滚政策。 |
| `source_factor` | 已领取equipment/refinery设施的当前来源倍率Amount文本；其他类型或尚未领取为null | 沿已有设施贡献来源求值/缓存投影，仅是该设施当前来源倍率，不是装备或掉落的最终值。shipyard/auto_explore不伪造数值倍率；不承诺领取后预测或重铸许可。 |

实际探索者与时钟继续按原人员事实及`Planet.visual_snapshot`消费，不复制探索时钟。主线`visual_snapshot`没有automatic字段；本分支实现候选的最小增补见[第10节](#10-实现候选超空间只读预览与星球自动设置)，未合main。该输出只读现有设置，不把关闭自动与立即取消合并成新动作。

### 8.4 Galaxy：选中节点事实

拟增`Galaxy.node_facts(region_id: String, node_id: String, counts: Dictionary) -> Dictionary`。未知/不可用区域或不存在节点返回空字典。counts由装配处在当前Session的可见显示帧同步新读`Crew.galaxy_assignments()`并即读即传，不复用固定步开头缓存的people；它仅转交该区域人数映射，与现有Galaxy推进输入一致，不由视图按人物图标计数或写回。地图形状/连接与人员总数继续消费原接口，本方法只补选中节点的语义截面。

| 必需字段 | 类型、单位与来源 | 消费边界 |
|---|---|---|
| `region_id/id/state/explored/reachable` | String/String/String/bool/bool；实际键、empty/exploring/constructing/active状态、揭示事实及既有可达性求值 | reachable不表示可选中即能启动工程，也不要求前端重生成蓝图或推导可达性。 |
| `building_id/name/level/upgrading/target_level` | String/String/int/bool/int或null；已揭示设施身份、当前等级、现有升级集合成员资格及正在施工/升级的实际目标等级 | 未explored时building_id/name为空、target_level为null，不泄露已抽取但未揭示的类型；level保持实际值。正在施工目标为1，正在升级为当前+1，否则target_level为null，不将演示目标等级当新升级命令。 |
| `explore_remaining/explore_required` | float；探索工程量 | required复用初始化分配给该节点的准确工程量，含既有末节点余量口径；不重新生成蓝图/RNG。 |
| `construction_remaining/construction_required` | float；在现有施工前提满足时消耗的游戏秒 | required沿用现有construction_time；无人/全局暂停时不推导现实倒计时。 |
| `upgrade_remaining/upgrade_required` | float或null；升级工程量，非资源费用、非直接剩余秒数 | 未在升级集合中时均为null；required复用本次已启动升级对应等级的既有工作量求值，不重新选升级目标。 |
| `progress_fraction` | 有限[0,1]float或null；当前exploring/constructing/upgrading阶段的已完成比例 | 无进行中阶段时为null；所需量与比例由Galaxy沿原初始化/阶段启动求值生成，不由UI把工程量除人数计算ETA。 |
| `progress_block_reason` | String；进行中阶段且该区域无实际人员时为`NoGalaxyCrew`，否则为空 | 全局暂停仍用原上下文；不添加领域暂停状态或新的工作循环。 |
| `effect_id/contribution` | 已揭示设施的原effect_type/String；本节点当前已生效来源贡献的Amount文本或null | 未揭示时effect_id为空、contribution为null；已揭示但未建成的当前贡献为合法0。值是原来源账本中的无量纲增量，不是全局/区域合计或最终倍率，不能由UI加1、套等级/收益公式或据此声称未来效果。 |

当前来源贡献沿原贡献求值/缓存读取；不在该查询中推进、完成或领取工程，不从私有来源账本向UI透传整本数据。本节不增加节点操作、未来贡献预览或真实炮口/碰撞几何接口。

### 8.5 失效通知与独立落地边界

- Crew沿`members_changed(ids)`使对应成员事实失效，沿`options_changed`更新可用成员/功能状态；经验变化、真实占用/在线保留与释放须在原接纳完成后覆盖对应id。查询不得发这些信号。
- Planet沿`status_changed(ids)/buildings_changed(ids)/assignment_options_changed(ids)/availability_changed`使对应星球事实失效；automatic-only变化若影响既有展示，也须沿原status_changed覆盖，不能靠重建全页面补缺失通知。设施视图直接订阅Crew成员/选项变化，只重读当前可见星球并注入最新人员事实，不新增Session全局通知路由。
- Galaxy沿`status_changed(region_keys)/availability_changed`使选中节点事实失效；施工与升级余量实际变化均须覆盖所在区域，不能只通知升级完成。视图直接订阅Crew成员/选项变化并重读当前选中区域的人数与节点，不全图重建或扩大原人数接口。
- 三项均在可见显示帧合并失效读取；隐藏视图停止无用投影，业务照常推进，重开读最新完整事实。Amount文本、经验门槛、静态设施/节点定义与未变快照只随对应事实变化重建；不因窗口尺寸或显示帧反复求幂/求值。
- 每项可单独评审/实现；依赖的人员输入复用已有只读视图，不增加相互持有的模块对象或新业务协调。未选定的比例/预算、整组原子提交、未来效果/动态战斗效果继续待定，不能以本节授权运行实现或整批G2验收。
## 9. 已审设计：反应炉整组草稿与科研预算的Amount安全预览

**状态：设计已审；[运行实现候选](../verification/amount-preview-implementation.md)未合主线、待双审，不作为主线已有方法。** 只补当前已定工作点需要的只读换算/比较；玩法及接纳仍按[03第2–3节](03-progression.md#2-反应炉)和本页第5节。固定请求、源码核对及持续0%的差异见[审查记录](../verification/amount-safe-preview-contract.md)。本节选定Reactor最小具名整组金额入口及Research原单资源入口的归属；不引入通用事务层、保存字段、随机现金流预测或未选UI。

### 9.1 单位与共同读取边界

- 比例输入为整数基点`0..10000`，10000表示100%。Amount金额、容量、速率、工程量、倍率及任意时长以原规范文本输出；业务复用原Amount求值。比例先在Amount域除10000，再乘基准并floor，不能先把大额转float/Number/BigInt或用控件位置重算。有限float只用于基点控件/进度条，不重建数量。
- 预览只读已接纳状态与同一次同步新读的来源；不调用命令、prepare/accept、推进、扣款、抽样或保存，不制造RunState故障。现行_capacity会写容量缓存，_required_work会写required_work；纯预览不得直接对所有者真状态调用它们。须提取无副作用求值或在脱离所有者的数据（含会写入的嵌套缓存）上求值，不借读取填写业务字段/缓存。返回行及嵌套数据均脱离所有者或递归只读。
- 结果分开`current`（已接纳）、`target`（本草稿条件下）、`source`（外部必要的公开结果事实）；`can_apply/reason`只说明本次检查，不承诺下一次提交必成。未知值用null及具体原因，不补0/×1。Amount短文本由提供方格式化，canonical全文保留用于精确提交；UI不从短文本还原值。
- 净收入不向非负Amount塞负数：用`direction=surplus/deficit/balanced`与非负`amount`文本表示差额。持续时间用Amount的`div`求游戏秒，可供提供方格式化；`to_ratio`被限制在[0,1]，仅能作显示比例或既有有界分段系数，不能作为秒数。

### 9.2 Reactor：整组分配预览

拟增`Reactor.allocation_plan_preview(draft: Dictionary, inputs: Dictionary) -> Dictionary`。inputs由装配具名callable即时注入现有`Session.reactor_inputs()`的当下值，不要求UI构造或认识内部组成。draft仅有三个具名读取分支，不是通用命令容器：

| draft | 精确含义 |
|---|---|
| `kind="shares", shares_bp={module_id: int}` | 每项占**总手动容量C**，不是剩余容量、有效量或含免费量的比例；键必须恰为当前开放设备，全部显式给出，允许0。每项`floor(C×bp/10000)`，未分配部分保留。 |
| `kind="amounts", amount_texts={module_id: String}` | 同一整组草稿的精确金额入口，仍须给全体开放设备；按原金额解析及floor生成整数目标，不在UI求和/钳制。 |
| `kind="equal"` | 沿既有distribute的纯求值：只含开放设备，整数商均分、余数按配置顺序；沿原Amount对极大个位余数的可表示性口径。 |

未知/锁定ID、缺项、非整数/越界基点、基点合计>10000或目标Amount合计>C均返回具名拒绝；不静默补旧值、归一化、重排或替玩家钳到预算。超额检查以Amount实际求值结果再核一次。请求0%/清零时合法目标为0，免费量仍按原规则存在。

最小成功输出：`source`只给外部必要的容量、开放设备ID及配置顺序等公开结果，可复用`current`对应值，不重复暴露输入分解；`current/target`各给`capacity/allocated/remaining`，设备行给`id/manual/free/effective/factor`的Amount文本。容量输入因子、免费输入比例及人员/算法等内部组成不透给UI作比较或管理失效。C来自原_capacity；free的实际Amount读数仍展示且不占手动容量，effective及factor复用原_evaluate，不能把免费比例当最终伤害比例。target是同快照的整组效果比较，不承诺完整战斗收益。比例条可另给有限显示比例，C为0时比例为0，不产生NaN。

**选定的整组提交：** 拟增所有者内最小具名金额入口`Reactor.apply_allocation_plan(amount_texts: Dictionary, inputs: Dictionary, publish: Callable) -> Dictionary`；装配负责即时提供inputs/publish，UI只提交已显示并确认的全套canonical金额目标。比例草稿只用于预览生成目标，命令不接收基点、不按新容量重算金额。映射键必须恰为提交时开放设备ID集合，含0值项；金额须为规范非负整数Amount，不重取整改变确认值。

所有者按提交时容量/开放集合一次校验完整映射与合计，不能容纳或集合变化即普通拒绝，不补项、不按设备钳制；复用原候选求值后仍须核对全部手动值等于确认金额。容量改变但仍能容纳、集合未变时保留确认金额并允许接纳，不引入容量快照锁。通过后形成一个所属模块候选，一次求值、接纳及既有发布；普通拒绝不写入任何本组目标，无逐设备部分成功，原fault仍按第5节停机，不声称可回滚native故障。

成功后当前真实分配/免费/有效量及效果替换旧比较；不把旧预览的倍率当承诺。现有allocate_text仍供单设备动作，新整组确认不让UI管理先减后增、多次发布或差异重试。均分保持确认后**一次distribute**，明确按提交时状态均分；预览的容量/效果不锁住提交时容量，实际回执优先。

### 9.3 Research：单工作点预算预览

拟增`Research.budget_preview(request: Dictionary, inputs: Dictionary) -> Dictionary`。request带当前`research_id`和以下一种意图；ID须与当前已接纳研究一致，查询不选择/续选项目。inputs由装配在当前Session显示帧从拟增最小公开`Session.research_preview_inputs()`即读即传：Economy当前钱包、`income_rates(..., research.income_window(), "investment")`的收入率及游戏时钟/窗口终点、原研究外部速度因子和实际科研岗位事实；外部速度只提供聚合因子供Research消费，UI通过注入的具名预览callable调用，不读取`Session._research_speed`或拆分人员/算法组成来求值或管理失效。不读取UI钱包、墙钟peak或production_base冒充投入收入。

| request | 本次只读目标及既有写入口 |
|---|---|
| `kind="once_ratio", basis_points` | 铁/铀共同近期收入比例。每资源`floor(income_rate×bp/10000)`，0%为0，低收入取整到0也保留0；生成两个金额草稿，不改已生效投入。 |
| `kind="once_amounts", amount_texts={"1": String,"2": String}` | 精确编辑或已生成而保留的本次金额草稿，沿set_investment_text的解析/floor口径；单字段非法给该资源原因，保留文本，相关目标估算未知，不伪造0。 |
| `kind="following_sample", enabled: bool, basis_points` | 给出目标开关/比例及原自动准入。enabled=true时仅展示按**本次收入样本**计算的周期目标`max(1,floor(income_rate×ratio))`；enabled=false只预览关闭设置，周期目标null并标AutomaticDisabled。设置仍调用既有set_automatic，不直接改金额；样本不是已生效或锁定下一周期的投入。 |

收入窗口沿现行规则（当前60游戏秒）：合格已入账actual样本除完整窗口长度，含investment口径接受的galaxy_yield；不是只除已有采样时长、钱包占比或未来收入预测。**保留现有分别接纳路径：** 本次金额仍按当前逐资源动作分别set_investment_text接纳；一项成功不因另一项失败回滚。成功后重读current及比较，未应用资源草稿保留。比例换算/预览由Research拥有，不因共同预算控件就新增没有实际消费者的批量金额入口；持续设置仍独立调用set_automatic。

**持续0%不改现行准入。** set_automatic仍检查原minimum_ratio（关闭时也检查ratio）；当前配置下0%不能提交，following_sample须给`can_apply=false/reason=InvalidResearchRatio`，不能输出“合法下一周期至少1”冒充已支持。若另获准放宽下限，才另审其0%下max(1,...)语义；本提案不改配置。关闭持续跟随使用已接纳的合法ratio调用set_automatic(false,ratio)，仅关自动，不清当前投入。本次0%及手动0投入继续合法。

最小输出如下，均以本次快照为条件，不是新业务状态。科研将比较目标分为`immediate_draft`与`following_sample`两个互斥块，后者另含目标enabled/ratio；不得把following_sample的金额放入“应用后立即生效投入”：

| 字段 | 口径 |
|---|---|
| `current.research_id/level/work/required/remaining_work` | 原已接纳项目/等级及Amount工程量；剩余为原所需量减已做量。复用原求值，不因读查询修改存档required_work。无当前项目时相关值null并给原因，不自动选最短。 |
| `current.investment/automatic_enabled/automatic_ratio/minimum_ratio` | 已生效的每游戏秒投入及原自动设置；与目标、局部模式和比例草稿分别显示。 |
| `resources[1/2].income_rate/balance/current_rate/draft_rate/following_sample_rate/net_current/net_draft/net_sample` | 收入、钱包、当前/本次草稿/持续样本每游戏秒投入及有方向的净收支。仅本请求对应的比较块有值，其余null；合法目标为canonical整数Amount。持续关闭或无合法目标时样本金额null，当前投入始终保留。 |
| `resources[1/2].stock_duration_current/stock_duration_draft/stock_duration_sample` | **假设此后无收入且无其他支出**，钱包/每秒投入所得游戏秒，不是按净收入计算的破产预测或研究完成时间。率为0标not_spending且时长null；余额为0且率>0时为有限0秒；不伪造无穷float。 |
| `current/immediate_draft/following_sample.speed_now` | 本次快照瞬时工作量/游戏秒，按当下余额和投入是否可支付复用原AI/人员/算法与投入求值；没钱失去对应付费因子，基础研究仍继续。率1的因子仍可能为1，不把有扣费一律标成有增速。暂停上下文单列，不改此游戏时钟口径。 |
| `current/immediate_draft/following_sample.completion_estimate` | 条件明确的估算：冻结本次等级/速率/外部因子，假设正投入资源持续足额可付至本级完成，独立复用原求值得到`funded_speed`（工作量/游戏秒的Amount）并由剩余工作量除该速度求Amount游戏秒，绝不拿缺钱时的speed_now相除；同时给假设、funded_speed、各资源所需资金、当前余额能否覆盖。不能当实际ETA；资金不覆盖时仍明确条件未满足，不预测后续随机入账。不可求时null及原因。 |
| `completion_effects` | 当前选中科技完成本级的原效果id及当前→下一级值/摘要，沿原Research效果求值和本次peak事实；不是投入本身的收益、整套战斗最终值或未来随机倍率。 |
| `automatic_refresh` | 沿原refresh_elapsed/automatic_due给距原刷新边界的非负游戏秒、是否已到期及自动关闭/无实际岗位等阻断事实。设置不重置原周期；可能已经到期、等待岗位或下一固定步，不承诺开启后一定再等60秒。 |

速度/估时须抽取原科研求值或对脱离所有者的数据求值；不在UI重写log/支付积分，不用调用advance来推进真状态，不将短缺一概当停工。库存独撑时长与有条件完成估时分别命名/展示，不以一个“remaining”同时指两者。输入/工作/支付条件一变，旧估算失效；不承诺未来项目、收入或实际现实完成时刻。

### 9.4 草稿、来源变化与失效

本次/持续是前端局部工作模式，分别记忆比例草稿，共用一个可见控件；点击已选模式/切模式不提交、不覆盖两个本次金额草稿或已生效设置。持续模式只更新自己的比例及样本预计值。主动拖动本次比例才重生成金额；被动来源刷新或切模式保留已生成/精确编辑的canonical金额，按once_amounts重取比较。Reactor已显示的canonical金额目标保留；容量/开放/效果来源变化时，按amounts重读可容纳性与效果，不被动按原比例改金额。主动修改比例才重新生成目标。确认后仍提交该金额映射，不保留旧容量的效果结论。

影响容量、免费量、开放模块、已接纳分配或科研钱包/窗口/项目/work/投入/周期/速度/效果的变化，由相应所有者管理预览失效或在可见时重读。对UI只给容量、开放设备、当前/目标业务读数及必要研究状态；不公开容量输入因子、人员/算法/peak等内部组成让UI比较。无需全局revision/fingerprint或容量快照锁；命令按当前事实校验所确认的金额，成功实际回执替换旧效果。

现有choices_changed/investment_changed、Economy显示变化、Crew成员/选项及实际贡献提供方事实可使读模型失效；它们不能冒称已覆盖所有时钟/收入窗口/研究进度与容量变化。实施时只在所有者补必要覆盖或在可见显示帧重读时钟相关事实，隐藏停无用投影、重开取最新；不读私有账本，不新增Session全局通知层。静态定义、所需工程量与未变效果按其真实来源复用，不因滑杆拖动/窗口尺寸反复求幂。

## 10. 实现候选：超空间只读预览与星球自动设置

优先三项方向已双审通过；本分支运行候选待实现双审，未合main。基线`cd4169ccbb9cf94b58e29ac6583ff682465a9df2`，仅补现行规则下的读取，未实施同提案其余清单。固定源码/定向证据见[实现记录](../verification/readonly-preview-implementation.md)。

| 出口与消费者 | 最小输出与语义 |
|---|---|
| Hyperspace `routes()` → M9路线行 | 保留route/weapon/cleared，加`best_time: float或null`，只指当前最高已过层有效最佳游戏秒；无记录为null，不把更低层最佳、在线10秒下限或现实倍速后的秒数替代它。 |
| Session `hyperspace_idle_preview(route: String, automatic: bool, crew_id: String="")` → M9单次/自动确认 | 成功回`ok/route/level/automatic/duration`，duration是现行完整游戏时长；单次`crew=null`，自动`crew={id,level,luck}`取现行Session实际来源的开始快照。拒绝保留原reason，不输出伪造时长/人员目标；不返回receipt/run_id/RNG或奖励。输入不收客户端等级、幸运、容量。 |
| Hyperspace `preview_filter_import(text: String)` → M9导入前审阅 | 成功回`ok=true/candidate`，candidate是脱离当前规则的规范v2五字段version/enabled/mode/action/conditions；枚举ID目录复用player_catalog的weapons/qualities/affixes/legends四类，minimum_level是数值条件。失败沿原`InvalidFilterShare/InvalidFilter`及规范化准入。 |
| Planet `visual_snapshot(id)` → M7自动设置 | 在现有快照加`automatic: bool`，读取已接纳的继续探索设置；running/时钟独立。未知或未开放仍返回空快照。setter只在成功且设置实际改变后沿既有status_changed通知，不新增通知类别。 |

Session预览与两个开始命令共用准备链，保留拒绝顺序：单次为RunState→开放→prepare_idle；自动为RunState→AutoRunning→开放→Crew准入→prepare_idle。prepare_idle继续负责UnknownRoute、在线任务占用、最佳时间和原时长等判断；预览不调用reserve/accept、不推进随机/任务/序列、不发通知。合法恢复/装配已校验保留一致性，不新造占用模拟器；预览不锁定资源，开始仍按最新状态重新准备，只有开始自动才保留船员。

过滤命令与预览共用原解析/规范化及纯校验，set_filter直接输入仍保留原严格类型准入。预览不改当前规则，返回值可本地编辑而不污染所有者；确认仍调用import_filter原串并重新解析校验，不能提交客户端candidate绕过原准入。UI编辑分享串、切换来源、取消或成功后清对应旧确认；不为此添加全局revision、过滤影响扫描或仓库处理动作。Planet关闭自动仍只改变后续继续设置，不取消正在进行的探索。

## 11. 实现候选：装备比较、强化摘要与成交回执

设计`0a3a5eb10fa259e3bf1a20d8480a67fc9bbe56d8`已双审通过；本分支运行候选待实现双审、未合main。仅本节读取与回执边界，未搬入b7bb旧缓存/提前通知；历史来源核对留在[提案](../verification/equipment-enhancement-readonly-contract-proposal.md)，固定源码及原始证据见[实现记录](../verification/equipment-enhancement-readonly-implementation.md)。

| 入口/消费者 | 最小读取契约 |
|---|---|
| Session `equipment_slot_facts()` → M2槽卡 | Equipment.slot_facts按已接纳全部保留槽给id/category/index/equipment_id、paid/effective_level、dormant、switch_ready_at/cooldown_remaining。空槽与休眠独立，未知有效等级为null。冷却只作用换装，不给购级加新禁令。 |
| Session `equipment_comparison(slot_id,candidate_id,count=1,maximum=false)` → M2比较台/固定报价区 | 薄装配实际世界/AI/反应炉及预算，Equipment.slot_comparison只读输出`scope=charged_base`、current/upgrade/candidate、quote、affordable/payment_reason、switch_admission、dormant。current为现装，upgrade按本次quote实际count，candidate沿当前付费级；不组合候选换装+购级。行给装备/等级、主值规范Amount文本或null、status/reason及有单位配置特性；不输出拼接中文当数据。 |
| Equipment `quote_slot(slot_id,n)` / `quote_max_levels(slot_id,inputs,can_pay)` → M2数量/费用 | 确定数量复用原_quote_levels；MAX薄包装原_quote_affordable_levels。保留count/costs/extreme与原reason，costs为resource id→原Amount。单槽+10完整报价不缩成可购2；MAX候选报价错误/不可支付作搜索边界，0统一NoChange，原离散极限保持。不新增整组预览，不把独立MAX相加成批量总价。 |
| Session `enhancement_presentation()` → M5等级行/六卡 | Enhancement.presentation_model在真实bonus/开放/armours上纯调用_effective_level/_describe/_combat，输出scope=enhancement_static、paid/bonus/effective、available/reason、两组实际顺位及effects。行给id/category/position/threshold/active/reason，节点index/threshold/choice/open/function_active/reason，summary含合成A/B静态参数与生效规则。不是native临时/历史乘数或未来收益。 |
| Session `enhancement_branch_details(effect,node)` → M5选择前详情 | Enhancement.branch_details对所选节点0–2给门槛/选择/open、A/B options；无论未选/未开放均给稳定rule_id及必要parameters（value/unit）。command_allowed沿原_choose，function_available/function_reason独立；repeat-B2旧选择可保存且原命令可接纳，但功能不生效。不把选项规则冒充当前合成结果。 |
| Session `enhancement_purchase_preview(count)` → M5买1/最多10固定区 | Enhancement.purchase_preview复用原_quote_purchase，保留ok/reason、request_count、purchasable_count、costs/extreme与first_level_costs。最多10可能实际2；NoChange给可购0，其他错误的数量未知，不伪造0。首级所需与实际可成交总费分开，不新增强化MAX。 |

静态比较止于成长/进化/科研/供能；当前实战值另复用Battle.attribute_details，不拿当前native最终值对比候选charged_base。switch_admission仅复用原单槽换装准入，不承诺最终无人机/Higgs组合许可，实际提交仍沿Session原链。查询只读已接纳事实；_charged_base仅给脱离slot，强化不调用会写_pending_output的evaluate，不设可写展示缓存或临时接纳。

强化summary给完整已生效A/B静态投影：熟练/适应静态合成因子及规则、连发含A的概率/伤害/延迟/额外目标、暴击原始率和B3效果触发率分开、记忆含A及当前装甲B3的恢复/上限、延期未强制清除概率和B2/B3随机/强制清除及来袭倍率分开。生效规则及节点选项均用稳定rule_id、参数和game_seconds/count/ratio单位供前端本地化，不让UI补公式；每盾充能等只给既有规则参数，不伪造未提供的累计实值。未定历史动态乘数、未来收益继续排除。

实际执行回执附在原命令结果`purchase_receipt`，不改变原ok/reason或部分成功政策。装备成功提交给`commit_status=accepted`、逐槽purchases[{slot_id,count,spent}]和逐资源合计spent；单槽/批量捕获本次执行quote，不靠钱包差/通知后重读反推。buy_all_levels即使返回后续failure、ok=false，已经成功发布的槽仍给accepted回执。无发布为not_submitted，普通发布拒绝为rejected且无确认成交；提交后fault为fault_unknown、spent=null，不声称回滚。强化购买同样给commit_status、实际count/spent。早期原准入/报价/支付拒绝可无回执，不表示曾提交；没有成功接纳的候选成本不得当实际支出。回执是上次成交，不是下一报价。

报价/比较/选项不锁资源，确认按最新所有者状态重验。装备沿原slots_changed/loadout_changed/options_changed及预算事实刷新；强化采用可见时同步重读，覆盖purchase/改序/分支及外部bonus/armours经accept_output变动，不新增presentation_changed或事件框架。新增强化查询用独立只读输入，经Equipment.accepted_armours复用计数助手，只读已接纳槽；不随_pending_slots变化。原enhancement_inputs/equipped_armours供命令准备的候选语义保持，不要求查询调用方避开装备pending阶段。Session整批接纳结束再刷新；不在模块接纳中提前发信号。当前对象消失清旧详情，输入变化清对应旧报价，保留未提交UI草稿。
