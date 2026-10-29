# 装备 `6233dc6e` 合 main：最小正常入口依赖清单

**只读交接，未制作适配、未测试、未合并。** 用户现明确授权将装备界面合入 main；此页覆盖本目录旧提案中“暂缓”的执行结论及过期 `c84c703f` 装备文件版本。远端 `main` 仍为 `e93c221239a10d377b2ca89dd395ebcfa99c9819`，装备源码为 `6233dc6ea25bac9a0dfcbc6a8d7b0673e8f24f06`。当前共享分支 `a0d101cb` 含未审反应堆/星球及未选公共概念，**不能整支合 main**；下表是装备原组制作隔离候选的来源，不是可整批 cherry-pick 的提交列表。

## 结论：可隔离，采用装备原组的轻量正常入口装配

`6233` 自身已有比完整 `shared_host.gd` 更窄的 `main.gd` 接法：把窗口客户区设为 1440×900，原逻辑 572×960 战场放进右侧 632×900 的 `SubViewportContainer`，按 `0.9375` 显示；装备 `EquipmentPanel.new(session)` 以 808×900 根挂在左侧 layer 9。正式 `main.tscn` 启动时即显示装备，其他既有模块继续使用主线原舰桥 layer 10。这个接法不需要接入共享宿主、反应堆/星球新场景、经济新通知、公共 C 概念或新业务端口；战斗逻辑尺寸及输入映射不变。

但源分支 `main.gd` 不是最终可直接合并的完整适配：打开旧舰桥时装备仍在其下方露出，且批量/OptionButton 独占时主线 Space/G 快捷动作未按装备 UI 占用门控。装备组应在**同一个最小 main 适配**中处理旧舰桥显隐、批量遮挡/焦点与 Space/G；限主界面路由/输入，不改任何旧模块内部。若这些必要交互不做，就不能声称正常入口已完整接纳 `6233`。原组固定隔离提交和必要整屏/操作后再交原审，不能借旧图替新组合验收。

## 精确文件和来源

| 路径（均相对 `space-battleship/`） | 取法与当前依据 | 必要性 |
|---|---|---|
| `src/ui/equipment_panel.gd` | **整文件取 `6233`**，blob `23ef3f280eafa4cb7667a6d039735995e58ac400`；不能再取旧 `c84c703f`。 | 已验收的工作台、删记录/最近结果、批量等级刷新。构造只收 `session`；保留内置标题/钱包，不调用 `set_shared_host` 即可用于轻量入口。 |
| `src/systems/equipment.gd` | 装备所属整文件取 `6233`，blob `c29b79a56cef3da2e9f923df7c277b3286df1c7c`（与旧 `94040a18` 同 blob）。 | `slot_facts`、`slot_comparison`、MAX 报价、`comparison_changed`、购买提交状态。 |
| `src/game_session.gd` | **只摘 `6233` 的四个装备方法** `equipment_slot_facts`、`_equipment_comparison_dependencies`、`_notify_equipment_comparison`、`equipment_comparison`，以及 `publish_equipment_refit`、`_publish_research`、`publish_reactor`、`publish_world` 四处比较依赖通知行。源 blob `ccfca9532cdf7f8b53fd08fc876ad44566c34320`，main blob `b4f516e2005d5ed728e40fdcfc3f063489274948`。 | 新面板的事实/比较读取及非钱包因素变更后的失效。**不可整文件取**：同一源文件另含超空间、科研、强化等未授权增量。 |
| `src/main.gd` | 以 `main@e93c2212` 为底，仅参照 `6233` 的 35 增/15 删轻量装配差异；源 blob `4fe92f15a812265e538c662f4caaa7bf60d80af6`。需再加下述显隐/输入适配，形成**新隔离提交**。 | 正式启动 1440 客户区、右战场局部投影、左装备 layer 9、旧装备 VBox 移除但原舰桥与旧其他模块保留。不能取共享分支 `main.gd` 整文件。 |
| `project.godot` | 只取 `6233` 的 `viewport_width=1440`、`viewport_height=900` 两字段，blob `1ed8ff4eadbf925770f197a4bb7c7e34770aab9d`。 | 正常入口实际画布。原 `Session.battle.view_size()` 仍是 572×960，不改战斗几何。 |
| `src/ui/campaign_view.gd` | 为 Space/G 同源门控，参照已审通用差异 `80e5463f` 的可选 `ui_gate: Callable` 注入（main 原 blob `195d561e6c7a83c976b059083f1d0acc301d9d49`）；仅这几行，无需共享壳。 | 独占批量、菜单/文本焦点时，逻辑战场 G 与 main 的 Space 同时拒绝，避免只挡鼠标。 |
| `assets/ui/equipment/hangar/hangar-console.png` 与 `.png.import` | 取 `6233`；两个 blob 分别为 `047321127bfa81410928ba755643b26006709504`、`d340400a404450594e6a85c4fe85b84214317e21`。同目录 `README.md`、`imagegen-prompt-01.txt`、`sources.json` 随资产保存来源。 | 面板唯一新增直接加载的机库贴图；舰体/武器 manifest、字体、护盾/装甲 SVG 均已在 main。不要取同目录旧支架/终端实验资产。 |

**`src/systems/economy.gd` 不需移植。** `6233` 的 Economy blob `26e65198a84e35f2eea29b627397b16db9e95f97` 与 main 逐字相同。面板监听现有 `display_changed`，读取真实 `budget()` 并以预算差异刷新比较；Session 的四处通知负责非钱包依赖。旧提案要求的 `3d763099` `budget_changed` 是另一共享壳路线所需，不能再当本最小装配的必需依赖。

删除“记录/最近结果”只删除玩家展示，不删除交易结果语义：`6233` 面板仍读取 `purchase_receipt.commit_status` 和 `purchases`，用以在批量中区分已接纳、拒绝及未知提交，并刷新当前等级；Owner 的结构化回执、`last_result`、`command_finished` 仍保留。不可沿旧 ce70 文案恢复记录按钮/Popup，也不可因为删展示而裁掉 Owner 回执。

## main 适配须写清的四个点

1. `main.gd` 的 `_show_session` 按 `6233` 轻量差异安装右战场和左装备；旧 `EquipmentPanel.new(七参数)` 从原舰桥删除，确保唯一装备实例。`_apply_settings` 和设置中的伤害模式遍历新 `_battle_viewport`，`_setup_shell_overlay` 仍在逻辑战场视口；Session 替换时沿现有释放流程重建一次。
2. 旧舰桥打开时隐藏左装备（或等效避免两个可交互面板重叠），关闭后恢复当前装备状态；持有者在隐藏前处理批量/OptionButton 独占及焦点。旧 ReactorPanel/PlanetPanel 等仍留主线原页、原构造与业务入口；不拿新组场景覆盖。
3. main 与 CampaignView 共用**只读 UI 占用条件**：装备批量/弹出菜单、旧舰桥/引导/危险确认、可见 UI 焦点应阻断 Space/G；在装备独占时主界面入口不穿透，并保持战场正常状态下原快捷动作。只传 callable，不新增领域命令或自动暂停。这里是待制作接口说明，未宣称 `6233` 原 main 已处理。
4. 左 808 与右 632 的画布只用于装备正常入口；原 viewport 内容的船、炮口、HUD、拾取与伤害唯一消费保持。不要引入 `shared_host.gd`、当前未选 C 概念或 `90a19067/0f8139d9` 整套 `main.gd`，也不把其他旧模块升级为已审新界面。

该清单解除“必须整套共享壳才能装装备”的假依赖，但**目前没有可直接合 main 的隔离适配提交**。本次只读 `main`/`6233`/既有候选 Git 对象，核了远端 main SHA；未 checkout、cherry-pick、改运行代码、运行 Godot、提交到 main 或扩大模块审查。后续由装备原组按此最小范围制作并交原审。
