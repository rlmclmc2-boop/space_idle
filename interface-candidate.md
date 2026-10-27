# UI 连接契约候选：先连接，后布局

依据唯一入口 `space-battleship/docs/game-design/README.md`；只读核对当前实现。这里是交接证据，不覆盖文档线程的拆分成果。功能基线为 `50ed7cdaf98243a36fadb1be30dbfc7b4022e6a4`；`480bcce9` 的布局试验已冻结，不是本线程当前接口方案。下表“现有”均对应源文件公开端口；“缺口/建议”尚未自动授权实施。

## 已定边界

- 模块拥有规则、Amount、费用、容量、解锁、提交和发布；前端只读取展示事实、提交稳定对象 ID 与候选输入、显示结果。禁止在前端复制成长、报价、伤害、研究速度、随机结果或存档事务。
- 跨模块操作使用现有 GameSession 协调方法或注入 callable；普通模块操作保持现有模块直调。不是新增通用 service、全量 DTO、全能中间层或消息总线。
- 变化通知只使受影响对象/选项失效，在可见显示帧合并读取；隐藏模块不做无用场景刷新。实时战斗继续走同一个 native/GPU 链。
- `ok/reason` 是业务成败事实；`message` 为当前上下文文案。对象、费用、余额、当前效果从成功后的同一模块查询。草稿、展开、焦点、滚动、选中和待确认 UI 记录属于前端；确认不能绕过原业务拒绝或幂等保护。
- 展示快照按只读消费。不能把 UI 的局部缓存当成新的业务真相；Amount 不经 float 转换。只把方法实际保证的副本/只读性作为保证，不推定所有 Dictionary 都深只读。

## 逐模块现有连接与最小缺口

| 模块 / 前端文件 | 现有状态读取 | 现有操作 / 结果入口 | 变化通知 / 刷新 | 前端本地状态与缺口 |
|---|---|---|---|---|
| 战斗/航程：battle_view、battle_hud、campaign_view、economy_view | Battle 的 `hud_values/statistics/attribute_details/presentation_clock/consume_damage_receipts`；Campaign `status_text/progress_facts`；Economy `balance_rows/drop_markers/budget` | 现有 native 表现绑定与绘制；`toggle_guard`、`session.set_pause`、`collect_at` 后调用注入的 refresh_growth | Campaign status/progress，Economy display_changed；实时表现按 native 帧消费 | 展示变换、伤害数字、HUD 展开属前端。拾取须将屏幕点逆变换回逻辑战场；不能改命中几何。此坐标适配属于纯前端接入责任；功能分支未更改战场显示变换。 |
| 舰体：fleet_panel | Campaign `ship_options/ship_facts`，注入 `battle.hull_presentation` | `change_ship` + `session.commit_ship_refit`，返回原结果 | ship_changed、progress_changed | 候选舰与预览属前端。缺口：开放门槛没有完整结构化展示字段；建议补在现有 ship_options 行，由后端返回条件，不让 UI 读 Excel 重建解锁。 |
| 装备：equipment_panel | `presentation_slots/panel_slots/panel_equipment/equipment_comparison/price_text`，注入 equipment_presentation_inputs 和 affordable | `buy_levels/buy_max_levels/buy_all_levels/equip_slot`，注入 payment、publish_equipment_levels、publish_equipment_refit | slots_changed(ids)、loadout_changed、options_changed | 当前槽、候选、唯一编辑器和冷却行缓存属前端。缺口：批量/MAX 的本次总价/数量预览；若补端口须复用系统现有报价求值，不能前端乘价或复制 MAX 算法。 |
| 反应炉：reactor_panel | `panel_options/presentation_model`，注入 reactor_inputs；allocation_preview 输出候选金额 | `purchase/distribute/adjust_allocation/allocate_text`，注入 payment、publish_reactor | choices_changed、presentation_changed | 选中设备、分配草稿、开合属前端。手动/免费/有效/最终增益由同一 presentation_model 提供。资产锚点契约等待文档候选；本轮不改 reactor_stage 或设备。 |
| 科研：research_panel | `panel_model/choices/presentation_model`，注入 research_presentation_inputs 与真实暂停/人员事实 | `select/set_investment_text/set_automatic`，原结果拒绝非法输入 | choices_changed、investment_changed；可见场景按现有节奏读进度 | 每资源草稿、自动比例草稿、列表/终端展开属前端。缺口：应明确未应用状态、暂停后的预计时间口径、岗位续研事实；这些由独立前端线程消费现有字段实现。进度/速度仍复用研究系统，不在 UI 推进。 |
| 强化：enhancement_panel | `presentation_model`，注入 enhancement_inputs/affordable | `purchase/set_branch/move_forward`，注入 publish_enhancement | presentation_changed，Economy display_changed 使预算展示失效 | 展开卡和路径候选属前端。缺口：当前有效数值及 A/B 的具体增量；建议扩展现有模块展示输出，保持效果求值在 Enhancement。 |
| 船员：crew_panel、assignment_controls | `member_options/status_rows/job_options/assignment_count`；任务选项来自 Planet/Galaxy 的 assignment_options | `session.coordinate_assignment`，输入 member ID、kind、target 和原任务参数 | members_changed(ids)、options_changed；任务模块各自 availability/assignment_options_changed | 当前成员、派遣候选、列表滚动属前端。目标人数/容量/进度应由目标模块的公开端口提供，再按 kind/target 关联；不能越过端口读私有任务状态。 |
| 星球：planet_panel | `planet_options/status_rows/building_options/visual_snapshot/assignment_options`；Crew 的实际 assignment_count | `set_automatic/claim_build`，注入 coordinate_planet_cancel、publish_planet_claim、coordinate_assignment | status_changed(ids)、buildings_changed(ids)、availability_changed、Crew members_changed | 选中星球/设施、地图视角、详情与终端开合属前端。owned 只消费后端已建成快照；ready 与领取分开。后续布局改造不改变施工/取消协议。 |
| 星系：galaxy_panel | `status_rows/assignment_options/visual_snapshot/node_presentation(key,id)`，上下文实际区域人数 | 派遣通过 coordinate_assignment；探索、施工与升级继续由 Galaxy 推进 | status_changed(keys)、availability_changed；本轮新增 Crew members_changed 使当前详情刷新；可见详情每 250ms 只读所选 node | map_key、selected_slot、pan/zoom、详情开合属前端。本轮不为普通升级添加全模块广播，不扫描所有区域。仍待真实发展阶段/完整升级实操覆盖。 |
| 超空间：hyperspace_panel | routes、online_status、manual_receipt、warehouse、module_growth、filter_configuration、legend_collection、player_catalog；Economy budget；本轮只读 `forge_display_limits(id)` | Session 的 `start_hyperspace_manual/start_hyperspace_single/start_hyperspace_auto/claim_hyperspace/equip_hyperspace_drones/set_hyperspace_hangings/dismantle_hyperspace_drone/exchange_hyperspace_materials/save_hyperspace_preset/apply_hyperspace_preset/preview_hyperspace_forge/forge`；模块现有 favorite/filter/legend/release_sealed/organize | 当前没有领域变化信号，界面仍每秒读取并保持选中；不是已完成的通知契约 | 仓库筛选与选择、编队草稿、改造 fingerprint/source/operation_id/已完成状态属前端。原事务确认与幂等保留。缺口：将来可对仓库对象和挑战状态各补最小通知，但本轮不重写所有后端为统一事件层。 |
| 档案/通知/设置：archive_panel、notifications_panel、main | Battle enemy_intelligence/statistics；tutorial.completed；Notifications entries/unread；PlayerSettings 与 SaveFiles 原接口 | Notifications `mark_seen/mark_read`；主程序原导入、新游戏、重铸预览/确认/取消，设置保存与存档协调 | Notifications changed；保存 poll/状态；本轮统一反馈重显 | 导入来源、确认摘要、路径输入、展开和错误显示属前端。持久预览独立于六秒吐司，失效/取消清除。候选 Session、文件备份、发布与恢复仍沿用原事务实现。 |

## 前端实际消费的最小字段截面

这些是现有公开返回值中已被页面使用的字段，供前端按对象连接；不是要求建立另一份全量 DTO。未列字段仍以对应模块实现为准，不能凭本表添加业务字段。

| 公开查询 | 当前消费者所需字段 |
|---|---|
| Reactor.presentation_model(inputs) | `level/capacity/remaining/load`，`modules[]` 的 `id/name/enabled/allocation/free/effective/factor/ratio/load`。金额和因子按模块给出的展示值使用；设备身份用 id，不用数组下标当身份。 |
| Research.panel_model() / presentation_model(...) | panel 的 `investment[resource]/auto_invest/ratio/options`；presentation 的 `speed/remaining/rows`，行内 `id/name/level/active/available/work/required/progress/effect_summary/effect`。`remaining` 的暂停口径由前端写清，不能让零速度看起来还在倒计时。 |
| Galaxy.node_presentation(region,id) | `name/state/level/effect/bonus/explored/reachable/explore_remaining/construction_remaining/upgrade_remaining`；实际人数由 Crew 的区域岗位事实提供。前端用相同 region/id 关联，不能自行推导升级完成时间或推进工程量。 |
| Hyperspace.warehouse() | `main/overflow/equipped/favorites/sealed/presets/reforge_count/retention_capacity`；drone 的稳定 `id/weapon/origin_quality/level/legendary/ultimate/omen/affixes/ultimate_affix/legendary_effect/hangings/hanging_slots`。普通/究极词缀使用 `key/tier/value/locked`，传说效果使用 `effect_id/parameters`。形态标志与字段当前是否生效要分别展示。 |
| Hyperspace.forge_display_limits(id) | `affix_limit/hanging_limit/reroll_ranges[]`；范围行 `kind/key/minimum/maximum`，普通词缀另含 tier。只为展示当前合法范围，不返回未来随机结果；成功改造后仍查询真实对象。 |

操作结果的稳定分支是实际 `ok/reason`。费用预览使用原报价返回值或原 preview；显示成功后的级数/属性/余额时重新读取对应展示查询，而不发明所有命令共有的 `new_level/balance` 等字段。多个模块目前返回附加字段不同，这不是增加统一中间层的理由。

## 结果与通知的约束候选

1. 页面动作传入稳定 ID 与候选值；业务拒绝必须保留草稿并返回领域 reason。不得用“已更新控件”代替提交成功。
2. 成功后只刷新对应对象、预算和既有贡献发布；UI 显示实际结果，不推测“加一级”等未经返回事实。需要前后对照时保存只读的提交前展示，并查询提交后事实。
3. 危险预览独立持久展示，确认使用原绑定输入。来源改变、目标消失、取消、会话替换使其失效。普通吐司可以收回，不得收回仍有效的确认依据。
4. A1–A7 的修复、`forge_display_limits` 只读性与局部刷新已经提交为功能候选；表中其余缺口是设计输入，未批量实现。

## 资产接口只属于前端

- 模块状态先映射为前端的设备身份、运行/停机、进度和选中；贴图、模型、材质、锚点、可见边界、点击区和布局槽位随后消费这些字段。资产不得接收经济对象、修改 Session 或推进时间。
- 代表 AI 工厂继续消费 `ai_tech_factory_art.set_display(technology_id,level,running,progress)` 和 `set_obscured`；宽窗画面与小窗观看区是同一资产的显示变换，不产生另一套研究状态。
- 后续替换清单应由前端资产契约给出：身份与路径、源画布/模型边界、可见主体、枢轴/设备底座、管口/挂点、允许裁切区域、点击区、文字安全区、状态图层与导出约定。动态金额和进度不能烘焙进图。
- 反应炉核心出口—主管—设备入口必须使用同一前端锚点关系。当前旧设备未获认可，契约待文档线程提供后再接入，不从历史截图恢复旧业务代码。

## 前端引用与当前分工

本文件是双方共用的单一接口候选，引用时固定本证据分支的提交SHA。前端线程据此安排纯前端结构、模块主题与资产槽位；本线程不继续并行设计布局。涉及新增状态字段或命令端口的缺口先回到对应模块确认最小交换数据，不把前端资产坐标加入后端领域对象。原文档拆分仍由原线程维护，后续正式收录由父线程统一把关。
