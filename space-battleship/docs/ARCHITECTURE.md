# ARCHITECTURE — 按需定位

高频刷新优化：`game.tick` 将充能扣费标记为 `save_dirty`，由原 5 秒检查点或既有关键节点/退出保存清理，写入失败保留标记。普通弹体在 `fire` 分配运行期 `serial`；`main` 的视觉存活索引及绘制索引仅在单次更新/绘制中持有，已有 visual 直接传递，前后绘制复用位置和尾迹预算。`equipment_tab.refresh_pending` 只消费局部 dirty 与资源快照变化，`equipment_stats` 事件覆盖充能升级和攻击/受击累计，隐藏后显示补齐；排序独立失效，静止暂停不重算详情。快照归页面实例所有，重建即释放。QA `update_processing` 按可见性和 worker 生命周期启停，隐藏时不轮询普通控件。专项 `test_hot_paths.gd`、`test_save_boundaries.gd`；性能探针 `test_hot_path_probe.gd`。

## 目录与入口

相对项目根；核心为Godot/GDScript，GL Compatibility、逻辑视口1440×810。游戏只需已投影数据；配置工具依赖Python/openpyxl/lxml。启动/跨机操作看[README](../README.md)。

| 任务 | 最少入口 |
|---|---|
| 启动/主循环/UI | `project.godot → main.tscn → scripts/main.gd`；`_ready/_process/on_event/build_ui` |
| UI 文案/参数保护 | `UI文案表.bat → tools/ui_text_editor.py/.html → data/ui_text.json`；`scripts/ui_text.gd` 与 `tools/ui_text.py` 读取；独立 `data/ui_text_contract.json` 维护必需参数、配置 ID 显示绑定和说明公式；操作见 `docs/UI_TEXT.md` |
| Windows 单文件发布 | `../build_release.bat → tools/build_release.ps1 → export_presets.cfg`；模板准备 `tools/install_release_template.ps1`；`../test/verify_release.gd` 与 `../test/test_release_failures.ps1`；操作见 README 的 Windows release |
| 领域状态/计算 | `scripts/game.gd`（BattleGame，RefCounted）；搜对应函数，不默认读全文 |
| 数据读取 | `scripts/database.gd`（ShipDatabase，RefCounted）；`equip/enemy_weapon/ratio` |
| 槽位/换舰 | game.gd：`module_entries/module_entry/active_slot_count/slot_entry/equip_slot/unequip_slot/switch_ship/upgrade_slot` |
| 战斗/资源 | game.gd：`tick/targets/fire/tick_projectiles/hit_player/hit_enemy/collect` |
| 宝石/碎片/镶嵌 | game.gd：`load_jewels/settle_jewel_fragments/generate_jewels/combine_jewels/decompose_jewel/socket_jewel/unsocket_jewel`；database.gd：`jewel/jewel_parameter/jewel_effect`保留原表字段并适配func行为 |
| 宝石效果/界面 | game.gd：`jewel_equipment_stat/jewel_critical/jewel_fire/jewel_on_hit/jewel_hit_player/advance_jewel_repair`；main.gd追加宝石页/装备镶嵌按钮，`jewel_panel.gd`仅持有UI选择、按token复用的六列网格控件及图片缓存 |
| 科学家/充能/炉 | game.gd：`scientist_purchase/advance_hightech/advance_charge/advance_furnace` |
| 页签/舰体/数值 | main.gd：`build_equipment_tabs/build_ship_tab/refresh_scientists`；`hightech_slot.gd`原生拖拽、`number_format.gd`显示 |
| 舰船素材/炮口 | `scripts/ship_visuals.gd`：尺寸、源图槽位映射及炮口；`assets/`及其README |
| QA/重启 | main创建根级`config_panel.gd` Window，直接访问current_scene.game；普通重启重载同一进程；`restart_host.gd`执行独立进程大重启 |
| 关卡编辑器 | `level_editor.tscn → scripts/level_editor.gd → tools/level_editor_store.py`；不创建BattleGame，Python定位直接用config_panel静态find_python |
| 配置链路 | `tools/config_workbooks.py`拆分/增量；`import_workbook.py`转换和显式全表CLI；`level_editor_store.py`编辑事务；`inspect_knowledge.py`按范围核对 |
| 测试 | 项目外`../test/`存源码；产物`../test/work/`；路由见下节 |

`data/`是运行投影与缓存；`config_excel/`是当前编辑源；`docs/`只保留领域/定位/状态/决策及人类操作/美术说明。`.godot/.runtime`是缓存与日志，`.userdata`是正式玩家数据，均非默认上下文。

## 运行数据与状态所有权

main持有db/game；game持有db与领域状态，经`event(kind,payload)`通知main。活动流为TRAVEL→COMBAT→TRAVEL/LEVEL_CLEAR；死亡RETREAT→TRAVEL，paused/pending_unlocks额外控制。旧枚举不等于现存页面（U-011）。

UI 文案在 main._ready 显式读取并校验，装备名称和页签在此初始化；QA 场景重启会读取新文案。UIText 只保存只读文案/参数契约和已编译的占位符模式，不是游戏状态或刷新管理器。参数结果由既有 NumberFormat/format_description/gem_formula 生成，再单次替换到文案；完整配置 JSON 不被改写。文案编辑器只写 text，校验成功后保存备份并原子替换；独立契约阻止通过修改“参数”展示列绕过校验。图形元素、颜色、禁用逻辑仍按业务状态决定，宝石错误使用稳定 key 而非错误文字非空性。发布 staging 和 include_filter 均包含两份文案 JSON。

装备展示：`equipment_tab.gd` 将每个模块映射为 Dictionary，以 weapons_N/defence_N 为卡片身份，包含当前装备 key、index、启用状态、等级、主属性与可升级状态。`equipment_card.gd` 共用 235×43 卡片；筛选只切 visible，排序仅 move_child。选中模块右侧通过装备 OptionButton 直接调用 equip_slot/unequip_slot；不另存配置草稿，不再按装备种类聚合等级。隐藏页标记 dirty，显示补齐；slot 事件更新目标投影，共享余额变化仅刷新其他模块可购买状态。`ship_panel.gd` 独立持有候选舰体选择，复用 SHIP_TEXTURES/SHIP_VISUALS 预览和挂点；确认只调用 switch_ship，当前舰体挂点进入对应模块。专项 test_module_ui/test_local_ui。

装备展开：同一 `equipment_tab.gd` 持有 `equipment_view_mode`（compact/expanded）、`details_open` 与两种尺寸下的滚动偏移。默认原 1364×156，展开到 (38,120)、1364×656（逻辑屏高约 81%）；200ms Tween 只改变现有 TabContainer 的位置/尺寸及独立战场暗罩透明度，卡片仍为 235×43，网格由三列变四列。动画期间按 resized 布局，结束停止；反向操作/离开页签杀掉旧 Tween，遮罩与按钮跟随页面可见性。首次展开继承当前滚动偏移，容器布局稳定后恢复偏移；往返分别恢复各模式先前位置，防止扩容后的引擎钳位丢失紧凑模式位置。详情始终复用原图标、标签与按钮，概览只含核心属性/简述/操作，详细信息按钮在右栏内显示 CD、下级属性、类型、弹速/齐射/光束/护盾参数、装配条件、消耗与已有镶嵌效果。Esc 在页面 `_input` 消费，只收起，不进入 main 的暂停分支；从不修改 game.paused 或战斗时钟。`test_module_ui.gd` 验证真实输入、卡片尺寸、可见容量、模式状态及滚动恢复；test_upgrade_ui/test_ship_tab 保留为该专项别名。


装备升级事件按slot走`main.refresh_equipment_cards(slot)`；`refresh_visible_cards`只检查当前可见页，切页立即补齐。资源影响消费按钮，科学家分配影响空闲数/分配按钮及对应进度，科技增益影响对应类别装备；值相同不写控件。MAX仍在点击时枚举当前预算。

`refresh_structure` 刷新模块结构及选中详情，换装复用对应模块卡片；`sync_hightech_slots`复用并移动科技卡，仅新增/移除变化项，拖拽结束后再移动。候选舰变化只更新舰体预览、挂点位置与说明，复用已有按钮。战场返回入口位于 `main.BATTLE_TAB`（现有页签末尾，索引 5），文案 `battle.tab`；空 Control 仅承载选中状态，仍使用原 battle_layer。切页回调关闭 jewel_panel 并调用 layout_charge_page 恢复普通布局，不触及 game。专项 `../test/test_battle_tab.gd`。

`refresh_navigation`原位更新驻守/音效及帮助/解锁可见性；普通state、科学家、科技完成不调用build_ui。build_ui保留作初建/显式重置入口。

导航不遍历ui共同父节点。可见性按明确依赖分组：help_button承载解锁可见性快照（帮助/资源模式/继续），help_close_button独立判断帮助关闭按钮，guard_settings承载普通导航可见性快照（驻守/跃迁/设置/页签容器/音效），advance_button仅跟踪过关按钮显示结果。驻守文字/禁用、音效文字、设置勾选由各自控件/菜单快照限定；同一显示结果不进入属性更新。loop_select快照包含通关列表与当前stage，结构变化仅增减选项及修正受影响项，目标选择独立select，不clear列表；allow_reselect允许同一目标再次跃迁。limit_warp_popup在弹出时按主题行高限制10行，复用PopupMenu自带滚动。快照随控件重建释放；宝石及其他弹窗不参与导航可见性管理。

`create_draw_layers/refresh_draw_layers`分离静态背景、静态边框标题、星空、战场、资源栏和覆盖层；只有战场/星空动画保留必要连续绘制，其余按显示依赖变化重绘。绘制辅助函数使用当前draw_surface，根节点不再逐帧queue_redraw。UI依赖快照存于所属控件的refresh_state元数据，key为各刷新函数显式列出的输入；输入变化失效、控件替换自然释放，仅UI读写，不回写game/profile，隐藏页在显示时补齐。按钮display_level只控制等级文案/费用提示，不缓存购买结果。

| 状态 | 唯一所有者/读取方向 |
|---|---|
| 舰船、装备等级 | `profile.selectedShip`、`profile.loadout[weapons/defence][index]={key,level}`；属性按槽位派生 |
| 玩家剩余冷却 | `BattleGame.cooldowns["weapons_<index>"]`；不使用名称键，不保存 |
| 资源余额 | `profile.resources[id]`；UI只读；`run_resources`语义见D005 |
| 充能 | `profile.charge[name]`的level/count/elapsed/active/started/credit |
| 科技/科学家 | profile的hightechLevels/scientists/scientistAssignments/techPoints/hightechOrder；当前研究速率派生 |
| 当前生命/护盾 | `BattleGame.player.armour/shield`；最大值由已装备槽位及增益派生，不作第二余额 |
| 实体 | game的enemies/projectiles/drops；敌方冷却在各敌实例装备数组，不与玩家槽位混用 |
| 收入/炉 | game.resource_samples保存现实时间窗口（jewel条目复用同一窗口供碎片速率与offlineRates.jewel；分解/离线不回灌）；profile.furnaceIncomePeak持久；区别见D005 |
| 舰体候选 | ship_panel.candidate 仅存候选舰体键；确认经 switch_ship 提交，模块配置始终读取 game；页签/滚动/弹窗由 UI 维护 |
| 宝石持久数据 | profile.jewels、统一数值jewelFragments（旧字典1:1迁移）、loadout每项sockets/attacks/hits；未镶嵌/已镶嵌只有一个所有者；运行token和serial不写存档 |
| 宝石临时战斗状态 | game.jewel_repeats为延时发射、jewel_charged为已触发下次齐射增益、jewel_defence_times为模块受伤计时、jewel_defence_damage为总生命/盾的模块受损分配；reset_player 清理；换装/停用只清理受影响的攻击状态，换舰保留共同启用模块，不保存战斗现场 |

读取与兼容选择理由见[DECISIONS](DECISIONS.md) D004/D005。合法运行状态在创建、加载、重建解锁及明确装备写入边界维护；普通属性/描述/排序读取不得调用ensure_loadout或懒写profile。

宝石替换复用`socket_jewel`，`jewel_socket_error`仅排除被替换目标的同ID检查。运行token在同一BattleGame内跨读档递增，防止旧UI请求命中新宝石；`jewel_kill_drop`在敌实例记录一次性判定标记。替换事件仍携带slot，仅刷新工坊依赖状态和对应装备卡，不重建页面。

一键合成：`game.combine_all_jewels`在临时背包数组、碎片数、serial及独立RNG状态中迭代；`combine_inventory_jewels/can_combine_jewels`与单次合成共用规则，`generate_jewels_into`与普通碎片生成共用补位规则。只在演算成功后暂存待保存profile；已报告save_error恢复原profile且不推进serial/RNG，成功合并回原profile并发出一次jewels_changed。不改装备、战斗属性或存档格式；未报告的底层存档故障仍属U-008。`jewel_panel.combine_all_selected`只提交请求、展示合并结果和短高亮；bulk_summary/bulk_rewards仅为显示文本，在库存事件/选择/打开时失效。

宝石表现入口集中在`jewel_panel.gd`：`inventory_changed`承接既有jewels_changed事件，`pickup_feedback`承接jewel_pickup；选择→对应格子/详情/可用槽位，库存变化→变化token及同ID同级可合成状态，镶嵌→对应槽位/详情与main指定装备卡。只读`preview_socket/stat_comparison`在副本调用既有属性函数。背包无_process轮询；可见时1秒Timer补齐滚动收入窗口及装备历史数值，隐藏即停止。新获得标记/observed_serial仅为面板的已读状态，随库存事件剔除消失token、选择时确认、面板销毁时释放，不参与业务或存档。预建样式、8个复用飞行图标及短Tween承载反馈；关闭清理面板动画，面板/主UI销毁时释放独立反馈层和确认窗。初始化完整构建保留，普通动作不重建页面。

## 充能页面表现

`main.build_charge_tab` 使用 `charge_panel.gd` 构建当前项目内的充能页；选中时将既有页签容器展开，离开后恢复原位置。`charge_cards` 仍引用面板节点索引，业务仍由 `BattleGame` 的 charge_job / charge_resource_rate / charge_required / toggle_charge 提供，不增加持久状态。

- 进度/余额变化：可见页读取配置对应模块，仅更新改变的属性；能源核心按资源独立展示余额、可运行模块每秒费率之和乘当前倍速、resource_minute_total / 60，以及后两者之差。全局暂停时充能消耗为零；净值是滚动平均产出减当前充能负载，不含其他开支，不代表本帧整数扣款。UI 单独保留净值正负号，不能用会夹零的通用 compact 直接格式化负数。只有选中模块的依赖变化才更新右侧详情。
- 点击模块：更新旧/新选择边框和详情，不重建模块；状态由 state_for 单一派生，按钮使用相同状态，预付量与整数支付边界参与判定。
- 配置结构/解锁变化：sync_modules 仅增删发生变化的配置项，复用其他节点；根据数量调整宽度，保留选择与滚动。page_capacity 最多六个槽位，页数包含末尾扩展槽，按钮和页码跟随实际滚动位置；末页保持 ScrollContainer 原生边界。未知系统使用通用图标，现有显示绑定选择攻击/防御图形，不限制系统数量。
- 管线几何：`charge_network.gd` 将核心出口和各仪表 port 的真实全局变换换算到独立线路层，生成核心→共同总线→模块接口的圆角矢量路径。滚动、尺寸或节点位置变化时重算；未变化复用路径。分支绘制和光点共用采样点及累计长度，流向固定由核心至模块，首尾淡入淡出，不用整线闪亮模拟流动。
- 性能边界：main 的正常帧刷新只向 `refresh_sample(delta)` 传入显示时间，游戏 tick 频率不变。页面约 100ms 采样能源与可见节点，选中详情即使离屏也更新；直接交互/显式刷新仍即时执行。仪表在自己的动画时钟内对采样目标做 100ms 插值。visible_keys 与线路几何归 charge_panel 所有，由滚动条、容器排序、尺寸/接口位置及显示事件失效，合并为一次 deferred 更新；进度/余额更新不再调用布局扫描。节点销毁时 Godot 自动断开所属信号，未增加 Timer 或跨页面监听器。
- 绘制隔离：管线结构和仪表外壳/刻度保存在各自静态 CanvasItem，只有布局或对应视觉状态改变才重录绘制命令；独立动态 CanvasItem 继续绘制原光点、圆环和核心。保留原光晕、层数和图形，不新增模糊滤镜或粒子节点。每个仪表仍只有一个持续动画时钟，隐藏/离屏/暂停停止；结构层没有 process。
- 持续动画：`charge_circuit.gd` 只绘制核心及圆形仪表，矩形模块承载层透明。核心半径由 60 增至 78，轻微旋转/呼吸；模块含结构环、刻度及真实比例进度环。选中为细青色外圈分段，运行另有亮进度环/微光，与选择独立。观察真实作业 level/count 增加后，仅显示层保持满环并收束约 240 毫秒，再追随实际比例，不改业务时钟或数据。动画上限 30 Hz，离屏/隐藏/暂停停止，滚回补齐；静态框架不逐帧重绘。几何、作业观察和动画快照归页面/仪表所有，配置或作业变化时失效，释放时清理，不写存档。

验证入口 `../test/test_charge_panel.gd` 覆盖真实点击、五种状态、预付/免费/断料、扩展/移除、滚动/翻页、多分辨率、10/20/30 系统分页、能源统计及负净值、多资源隔离、30 系统刷新耗时、流动/进度绘制上限和暂停零写入/零重绘；配套 `test_local_ui.gd` 与 `test_tab_unlocks.gd`。

性能复测 `../test/test_charge_performance.gd`：隔离运行真实 main/game 帧循环，内存添加 30 个活动作业（加原 3 个系统），测量帧分位数、UI 刷新耗时、RenderingServer CPU/GPU 时间、属性写入和动静态绘制次数；断言进度期间零布局扫描、约 100ms 采样、静态管线/外壳零重绘、自动布局失效及暂停/隐藏停止。性能测量须单独运行，不与其他图形专项并行。

## 存档与时间边界

星空绘制仅依赖star_travel、star_streak与speed；star_streak是main所属星空层的临时视觉过渡值，由未暂停的_process推进，不保存、不参与战斗逻辑。状态事件不直接开关全部星星拖尾，背景/chrome/UI树不参与这段过渡。回归入口为test_battle_transition_ui.gd，包含实际波次结束、进入下一战点、暂停、像素区域对比及分层绘制计数。

- `game.gd:load_progress/save_progress`；SAVE_PATH为`user://progress.json`，version仍为1。先写`.tmp`再rename；失败事件不代表所有故障可恢复（STATUS U-008）。
- 旧levels仅在加载时给首个同名已装槽位优先赋级；缺失/非数值取1，数值转整数并夹取1到配置上限，其他同名槽位保留各自等级；空槽不会被旧等级重装。缺loadout时构造默认布局。
- 保存临时字典从首槽派生兼容levels，未安装派生1；不写回运行profile，不做新旧状态双向同步。hightechVersion=2控制科技旧档迁移，charge缺字段建零级未启用状态。
- 加载顺序：load_progress（含离线资源）→advance_charge→advance_hightech→save_progress→reset_player，随后main._ready调用resume_progress；领域语义见PROJECT。save_progress在存档投影journey中保存stage/distance/groupIndex/state、驻守到达标记、回退末波标记和待确认解锁；死亡回退投影为目的地距离。load_journey校验关卡、节点、距离与状态后暂存在profile，避免初始化离线结算保存覆盖进度；resume_progress消费并移除该临时字段，以start的checkpoint参数恢复，普通start/主动跃迁仍从零开始。运行时stage/distance/group_index保持唯一权威，不持续同步profile副本。敌人实体、弹道与冷却不保存；旧档无journey时沿用原恢复入口。专项为test_journey_resume.gd与test_warp_ui.gd。
- main._process截断delta，再按speed拆子步调用tick；研究/充能用模拟时间，收入窗口用现实时间，周期保存按dt/speed累计。具体截断/子步值查`test_time_steps.gd`，不另维护常量表。

## 数据流与来源定位

原始Excel总表 --显式拆分/同步→ `config_excel/*.xlsx` → import/config tools → `data/game_data.json` → ShipDatabase → BattleGame/UI。直接编辑分表从第二步开始；选择理由见D003，操作查README。

| 分表键 | 投影段/定位键 |
|---|---|
| equipment | equipment[name][]仅保留level=1基础行；database.equip/equipment_growth计算目标级；res_x/cost_x/costMulti_x（兼容cost_multi_x）；para含义按各装备说明 |
| mon / monGroup / level | enemies[id] / groups[id].slots / levels[]及groups；按id定位 |
| res / config | resources[id] / config[name]；科学家参数按名称查，不依赖旧行号 |
| ship / hightech / charge | ship[name] / hightech[name] / charge[name]；分别查槽位/研究点/充能字段 |
| jewel | jewel[id]保留name/func/des/maxLevel/para_1…原字段，image可选且默认按ID映射assets/jewels/<id>.svg；缺manifest条目时发现独立jewel.xlsx，旧总表缺jewel不覆盖已有投影，关卡编辑器同样发现未登记的jewel.xlsx；本次仅投影config.jewelCreat、level.jewelRatio和jewel.image，未重导无关段 |

- hightech.description是UI模板、des是效果说明；charge.des是UI模板、func是功能说明而非可执行代码，不能混用。
- `.split_manifest.json`记录分表和总表对应关系；`source_files`记录投影来源路径；`data/.import_state.json`保存成功导入的源/目标指纹，缓存可重建。defaults保留既有目标补充值，fallbacks文字不是实际算法。
- 装备运行时由一级基础投影按等级计算，不读取旧高等级行、不求Excel公式。普通导入读取缓存值、不负责重算；拆分保留所选OOXML、样式/资源，拒绝跨表公式。编辑器仅处理自身支持的引用/ROUND/四则范围，限制查LEVEL_EDITOR。
- 增量路径无变化不写JSON，变化表才重投影并合并；未知/未改段须保留。CACHE_VERSION、源/目标hash、路径、公式缓存/ZIP、事务顺序均是兼容边界，不能随整理改动。
- Store额外校验编辑ID、敌外观/抗性、武器与掉落引用；可选ship/charge发现、缺表/坏manifest及错误时机在各入口不同。改前读`test_config_input_matrix.py`，不得从一个入口推定其他入口接受范围。
- `atomic_batch`、backup/rollback与并发失败仍有限制（STATUS U-019/U-020）；此图不是数据安全保证。不要默认整读game_data.json，按上表的单段/符号定位。

## 测试路由

本页 → [test/README](../../test/README.md)的最小路由 → 必要时查[TEST_MAP](../../test/TEST_MAP.md) → 1～3个专项。不要默认读取历史test_game作为规则入口；故障现状观察不替代正确规则断言。UI任务除断言还检查实际交互；人类编辑器操作见[LEVEL_EDITOR](LEVEL_EDITOR.md)，美术约束见[ART_GUIDELINES](ART_GUIDELINES.md)。

持续光束：game.gd的lock_long_laser/long_laser_valid/tick_long_laser复用projectiles集合，每挂载点一个持久字典，保存来源/目标/槽实例及命中时钟；tick_projectiles按计划命中时刻结算，离开战斗清理光束。main.gd在既有战场层绘制连接线，复用激光模块图标；不增加节点池、计时器或逐帧UI重建。专项：../test/test_long_laser.gd。

光束反馈：game.long_laser_multiplier供伤害与视觉共用；beam_started/beam_hit事件仅通知main。main.beam_style从当前倍率和命中相位派生束宽/亮度；sync_beam_visuals持有短期端点快照，检测满功率及移除，复用particles绘制小型接触亮核和收缩残光。暂停不推进，所有反馈仅影响battle_layer。

光束para3：lock_long_laser快照charge（空值为-1兼容原cd首击），tick_long_laser按charge+n×cd结算，伤害与视觉均排除蓄力时间；database.enemy_weapon仅对longLaser补para3回退。main战场层直接从elapsed/charge绘制聚光，不添加计时器或控件。

光束双发复用queue_jewel_repeats/advance_jewel_repeats；pending携带主光束引用以取消失效延迟，lock_long_laser按repeated区分主/副并优先分散同槽目标。jewel_attack为普通弹体与光束共用的伤害修饰/暴击/命中效果来源入口，命中及击杀仍经hit_enemy。

本轮组合核对（运行证据见STATUS）：

| 攻击/效果 | 验证范围 |
|---|---|
| 主/副光束 × 双发、CD、蓄力、增伤 | test_long_laser：延迟、独立时钟、倍率、上限、不递归、同目标回退、死亡补发、卸装/断束取消 |
| 副光束 × 暴击、吸铁、干扰 | test_long_laser：追加倍率与暴击/增长叠乘，两条光束命中效果及状态生效 |
| 普通弹体 × 宝石/命中/击杀 | test_jewels与test_projectile_lifecycle：共用入口回归及生命周期；光束仍复用hit_enemy击杀链，未新增击杀规则 |
| 光束 × 蓄能宝石 | 用户明确不清CD；test_long_laser覆盖真实受击触发、不断束持续增伤、独立断束清理、双发叠乘与待发消费；普通武器由test_jewels回归 |
| 防御专用宝石 | 按既有插槽适用规则作用防御装备，不在武器侧重复触发；test_jewels回归 |

未引入独立BUFF/词条系统；现有干扰等状态复用命中链。上述验证不代表未来新增效果自动兼容。

蓄能分发统一由apply_jewel_charge处理：普通武器写cooldowns/jewel_charged；持续光束仅在有效实例写charged_multiplier，不修改elapsed/ticks/charge/cooldowns。当前无光束时待发倍率在lock_long_laser创建主光束时消费；双发队列只带追加倍率，不携带当前光束蓄能，避免新光束继承旧实例状态。

大容量防御精度：jewel_hit_player以player当前总生命/护盾为本次可分配余量，模块capacity−damage仅作相对权重；若巨大容量减法吞掉所有微小余量，按模块容量比例回退。不得把该减法结果当作生命已归零而跳过受伤。继续维护原模块损伤快照供恢复使用，无新增权威状态；test_tenacity_survival覆盖1e24容量/0.25剩余生命与可选隔离存档夹具。

武器表现：game.fire事件附shot、tick_projectiles命中点发projectile_impact，仅通知UI。main.weapon_launch/weapon_impact复用particles的flash/smoke/spark/ring绘制；projectile_visuals每发预分配14点循环尾迹（最多256条），只存显示角度/年龄/炮口，advance_projectile_visuals原位覆盖点。导弹角度平滑不写shot.direction；炮口短闪/火炮模块后坐只影响绘制；光束流动亮点读取elapsed，保留原倍率/命中脉冲。新增粒子受700上限约束；80像素邻域的装饰预算优先裁减烟雾/环/火花，核心闪光满额时置换装饰，不随伤害膨胀。所有动画仅battle_layer，暂停冻结，结束清理引用；无新增Node/Timer/对象池系统。专项test_weapon_fx.gd。

导弹齐射：jewel_fire统一读取player_weapon_offset，忽略导弹调用方传入的位置偏移，普通/宝石追加齐射均使用当前炮口。fire的导弹初始方向对应当前固定挂载朝向（玩家向右、敌方向左），随后沿用既有追踪。missile_visual_spread仅为离开炮口后的显示展开幅度；main.missile_visual_position从出生点零偏移平滑展开，并在目标附近收拢，炮口闪光及尾迹首点不偏移。当前显示层炮台可旋转，逻辑方向仍保持原规则，见turret_visuals说明。

战斗降噪定位：main的BODY_SCALE/FLAME_SCALE/TRAIL_SCALE/IMPACT_SCALE分离显示缩放，draw_battle_particles分离装饰与接触亮核；hit→只更新该目标floats，collect→只合并该资源底部提示，explode→仅生成独立击杀粒子，wave_clear/encounter→中央短提示，设置伤害数字→仅battle_layer重绘。fx_time仅未暂停时推进，用于200ms合并与提示窗口，不写game。game.jewel_attack复用原随机结果返回critical，jewel_fire保存到弹体；光束直接发critical_impact，均不改公共伤害/追加调用链。drop.age仅用于延后显示，实体/位置/拾取时间保持原实现。普通敌生命文字隐藏，BOSS卡保留。测试更新为小灼烧闪光而非已取消的普通命中环。

武器反馈增强：projectile_visuals增加固定14点trail_times，导弹尾迹按0.14秒、火炮按0.065秒年龄渐隐；火炮后坐仅模块纹理8像素/0.13秒。weapon_impact以80ms星形亮核与短火花替代低亮圆点，非范围攻击仍无范围圈；暴击环0.12秒。explode截取敌舰纹理6片，副本保存区域/显示尺寸/旋转，0.52秒消散，烟雾最多0.24秒。beam_style分别返回常态glow与pulse；束身保持舰船下层，命中点在舰体上独立绘制。对比入口test_fx_comparison.gd（run.py隔离）输出同配置8阶段截图与combat-snapshot.json；不读取正式玩家数据。

伤害跳字：main.queue_damage_number/flush_damage_numbers只消费hit事件，floats最多每目标2条，damage_pending为短期显示队列；拥挤时旧条80ms退场，无安全位置的积压300ms过期。damage_text_position在两行/固定左右候选位置检查其他跳字和敌舰包围框，不无限上移。NumberFormat.damage仅用于跳字；damage_history保存最近40次原始事件值供设置详情查看，不作战斗统计权威。set_damage_mode仅清理伤害显示及重绘battle_layer；collect仍用底部固定位置且不漂移。全部模式按伤害类型分组，精简跨类型合并，暴击均独立；game.hit_enemy的可选critical参数仅透传已有弹体/光束判定到hit事件。专项test_damage_numbers.gd覆盖真实持续光束、多发导弹、多目标集火、模式/详情、碰撞/数量、暂停、固定奖励及无关UI身份/静态层。

持续激光蓄能层级：draw_battle在舰体后仅绘制弱瞄准线，舰体前统一绘制敌我主副光束的炮口聚光/亮核/旋转射线，蓄满后切换现有命中点反馈；只读取charge/elapsed。test_long_laser清除发射粒子后检查炮口白色亮核像素，防止蓄能再次被舰体遮挡。

我方显示缩放：project.godot的visuals/player_ship_scale默认1.25，由ship_visuals.player_display_multiplier/player_display_scale读取；原scale_for/player_weapon_offset继续供战斗计算，不随显示倍率变化。main.visual_muzzle把原炮口相对玩家中心的偏移映射到显示倍率；projectile_visuals另存logical_origin，仅把可见出生点/闪光/尾迹首点移到模型炮口并在前160像素内平滑接回实际弹道。持续光束及蓄能读实时显示炮口，敌方保持原坐标。源图module_regions排除透明留白，只影响战舰炮台绘制，不替换装备卡图标；深色衬底与类型强调均位于舰体缩放变换内。弹体/光束宽度/拖尾/命中参数仍独立。专项test_player_visual_scale.gd覆盖五舰型、所有挂点、显示倍率对逻辑零影响及同屏最大舰型布局预览。

炮台旋转：main.turret_visuals按槽索引保存entry引用、类型、angle、target、recoil，只属于显示层，换舰/换装/空槽失效释放；advance_turrets于未暂停_process中、game.tick前推进。只读game.targets作为无目标回退；已锁定主光束优先，fire更新显示目标，导弹同帧多发只取首个目标。shot_mount从事件原炮口匹配槽位，持续光束直接读原mount。turret_muzzle与draw_ship共同用挂点中心+旋转后半炮管长度，weapon_launch保存该帧显示角度/炮口，后坐沿局部X轴；不向shot写姿态。配置visuals/turret_limit_degrees、turret_turn_degrees_per_second；专项test_turret_rotation覆盖状态生命周期、挂点/舰名包络和静态UI。

离膛遮挡修复：draw_projectile_fx的core参数分离显示层，背景pass仅绘制较老尾迹，舰船绘制后foreground pass绘制最近3段拖尾、炮口短闪、尾焰/脉冲和弹体纹理；双方弹体统一路径。连续束身只把低亮halo保留背景，细亮核在前景炮口/命中反馈pass绘制。两pass共用原missile_visual_position，不改任何出生坐标或业务状态。test_muzzle_visibility通过清除闪光/后坐后的图像色差检查验证真实离膛可见性，旧版本3种武器均失败而修复后通过。

光束双发时机：tick_long_laser仅在主光束ticks首次变为1时调用公共queue_jewel_repeats；无新增计时/概率状态，后续周期命中不重试，副光束丢失不补发，新光束独立计数。test_long_laser覆盖首次概率失败后不重试和断束新锁定重新判定；普通弹体齐射入口不变。

模块持久化：`profile.loadout` 保留全部已创建模块，含停用尾部；`module_entries/module_entry` 读取全部，`loadout_entries/slot_entry` 仅返回当前舰体启用范围。读接口不写状态。新存档 `moduleVersion=1`；旧名称 levels 仅在旧档迁移时覆盖首个同名实例，之后完全由模块等级主导。save/load_jewels 扫描全部模块，避免空模块/停用模块宝石丢失。换装更换该 entry 引用以失效旧光束/追加攻击，同时复制等级、sockets、attacks、hits；换舰保留共同模块引用和战斗对象。`capture_refit_health/apply_refit_health` 转换剩余比例，零容量暂存于运行态 refit_health_ratios，真实重开 reset_player 清零为满比例，沿用现有重新进入时生命恢复规则。test_module_refit 为业务主回归。

未解锁舰体：ship_panel 的 silhouette ShaderMaterial 只保留纹理 alpha 并输出纯色；列表缩略图和候选大图共用。refresh 按 ship_unlocked 切换既有控件可见性，锁定候选在隐藏挂点/详情后提前返回；unlock_hint 仅读取 ship.unlock。专项 test_locked_ships。
