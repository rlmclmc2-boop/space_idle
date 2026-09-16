# ARCHITECTURE — 按需定位

## 目录与入口

相对项目根；核心为Godot/GDScript，GL Compatibility、逻辑视口1440×810。游戏只需已投影数据；配置工具依赖Python/openpyxl/lxml。启动/跨机操作看[README](../README.md)。

| 任务 | 最少入口 |
|---|---|
| 启动/主循环/UI | `project.godot → main.tscn → scripts/main.gd`；`_ready/_process/on_event/build_ui` |
| 领域状态/计算 | `scripts/game.gd`（BattleGame，RefCounted）；搜对应函数，不默认读全文 |
| 数据读取 | `scripts/database.gd`（ShipDatabase，RefCounted）；`equip/enemy_weapon/ratio` |
| 槽位/换舰 | game.gd：`slot_entry/equip_slot/unequip_slot/switch_ship/upgrade_slot` |
| 战斗/资源 | game.gd：`tick/targets/fire/tick_projectiles/hit_player/hit_enemy/collect` |
| 宝石/碎片/镶嵌 | game.gd：`load_jewels/pickup_jewel_fragment/combine_jewels/decompose_jewel/socket_jewel/unsocket_jewel`；database.gd：`jewel/jewel_parameter/jewel_effect`保留原表字段并适配func行为 |
| 宝石效果/界面 | game.gd：`jewel_equipment_stat/jewel_critical/jewel_fire/jewel_on_hit/jewel_hit_player/advance_jewel_repair`；main.gd追加宝石页/装备镶嵌按钮，`jewel_panel.gd`仅持有UI选择与固定格控件 |
| 科学家/充能/炉 | game.gd：`scientist_purchase/advance_hightech/advance_charge/advance_furnace` |
| 页签/草稿/数值 | main.gd：`build_equipment_tabs/build_ship_tab/refresh_scientists`；`hightech_slot.gd`原生拖拽、`number_format.gd`显示 |
| 舰船素材/炮口 | `scripts/ship_visuals.gd`：尺寸、源图槽位映射及炮口；`assets/`及其README |
| QA/重启 | main创建根级`config_panel.gd` Window，直接访问current_scene.game；普通重启重载同一进程；`restart_host.gd`执行独立进程大重启 |
| 关卡编辑器 | `level_editor.tscn → scripts/level_editor.gd → tools/level_editor_store.py`；不创建BattleGame，Python定位直接用config_panel静态find_python |
| 配置链路 | `tools/config_workbooks.py`拆分/增量；`import_workbook.py`转换和显式全表CLI；`level_editor_store.py`编辑事务；`inspect_knowledge.py`按范围核对 |
| 测试 | 项目外`../test/`存源码；产物`../test/work/`；路由见下节 |

`data/`是运行投影与缓存；`config_excel/`是当前编辑源；`docs/`只保留领域/定位/状态/决策及人类操作/美术说明。`.godot/.runtime`是缓存与日志，`.userdata`是正式玩家数据，均非默认上下文。

## 运行数据与状态所有权

main持有db/game；game持有db与领域状态，经`event(kind,payload)`通知main。活动流为TRAVEL→COMBAT→TRAVEL/LEVEL_CLEAR；死亡RETREAT→TRAVEL，paused/pending_unlocks额外控制。旧枚举不等于现存页面（U-011）。

装备升级事件按slot走`main.refresh_equipment_cards(slot)`；`refresh_visible_cards`只检查当前可见页，切页立即补齐。资源影响消费按钮，科学家分配影响空闲数/分配按钮及对应进度，科技增益影响对应类别装备；值相同不写控件。MAX仍在点击时枚举当前预算。

`refresh_structure`只替换装备类型/数量变化的槽卡；`sync_hightech_slots`复用并移动科技卡，仅新增/移除变化项，拖拽结束后再移动。战舰草稿编辑保留选择器，候选舰变化只重建候选槽区。`refresh_navigation`原位更新驻守/音效及帮助/解锁可见性；普通state、科学家、科技完成不调用build_ui。build_ui保留作初建/显式重置入口。

导航不遍历ui共同父节点。可见性按明确依赖分组：help_button承载解锁可见性快照（帮助/资源模式/继续），help_close_button独立判断帮助关闭按钮，guard_settings承载普通导航可见性快照（驻守/跃迁/设置/页签容器/音效），advance_button仅跟踪过关按钮显示结果。驻守文字/禁用、音效文字、设置勾选由各自控件/菜单快照限定；同一显示结果不进入属性更新。loop_select快照只包含通关列表，结构变化仅增减选项及修正受影响项，目标选择独立select，不clear列表。快照随控件重建释放；宝石及其他弹窗不参与导航可见性管理。

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
| 收入/炉 | game.resource_samples保存现实时间窗口；profile.furnaceIncomePeak持久；区别见D005 |
| UI草稿 | main.ship_candidate/ship_candidate_loadout；确认才经switch_ship提交；页签/滚动/弹窗由main维护 |
| 宝石持久数据 | profile.jewels、jewelFragments、loadout每项sockets/attacks/hits；未镶嵌/已镶嵌只有一个所有者；运行token和serial不写存档 |
| 宝石临时战斗状态 | game.jewel_repeats为延时发射、jewel_charged为已触发下次齐射增益、jewel_defence_times为模块受伤计时、jewel_defence_damage为总生命/盾的模块受损分配；reset_player/换舰清理，不保存战斗现场 |

读取与兼容选择理由见[DECISIONS](DECISIONS.md) D004/D005。合法运行状态在创建、加载、重建解锁及明确装备写入边界维护；普通属性/描述/排序读取不得调用ensure_loadout或懒写profile。

## 存档与时间边界

- `game.gd:load_progress/save_progress`；SAVE_PATH为`user://progress.json`，version仍为1。先写`.tmp`再rename；失败事件不代表所有故障可恢复（STATUS U-008）。
- 旧levels仅在加载时给首个同名已装槽位优先赋级；缺失/非数值取1，数值转整数并夹取1到配置上限，其他同名槽位保留各自等级；空槽不会被旧等级重装。缺loadout时构造默认布局。
- 保存临时字典从首槽派生兼容levels，未安装派生1；不写回运行profile，不做新旧状态双向同步。hightechVersion=2控制科技旧档迁移，charge缺字段建零级未启用状态。
- 加载顺序：load_progress（含离线资源）→advance_charge→advance_hightech→save_progress→reset_player；领域语义见PROJECT。驻守位置/选择持久，实体、当前距离、弹道与冷却不作为恢复现场保存。
- main._process截断delta，再按speed拆子步调用tick；研究/充能用模拟时间，收入窗口用现实时间，周期保存按dt/speed累计。具体截断/子步值查`test_time_steps.gd`，不另维护常量表。

## 数据流与来源定位

原始Excel总表 --显式拆分/同步→ `config_excel/*.xlsx` → import/config tools → `data/game_data.json` → ShipDatabase → BattleGame/UI。直接编辑分表从第二步开始；选择理由见D003，操作查README。

| 分表键 | 投影段/定位键 |
|---|---|
| equipment | equipment[name][]仅保留level=1基础行；database.equip/equipment_growth计算目标级；res_x/cost_x/costMulti_x（兼容cost_multi_x）；para含义按各装备说明 |
| mon / monGroup / level | enemies[id] / groups[id].slots / levels[]及groups；按id定位 |
| res / config | resources[id] / config[name]；科学家参数按名称查，不依赖旧行号 |
| ship / hightech / charge | ship[name] / hightech[name] / charge[name]；分别查槽位/研究点/充能字段 |
| jewel | jewel[id]保留name/func/des/maxLevel/para_1…原字段；缺manifest条目时发现独立jewel.xlsx，旧总表缺jewel不覆盖已有投影；仅本次config/jewel段按分表投影，其余段保持原值 |

- hightech.description是UI模板、des是效果说明；charge.des是UI模板、func是功能说明而非可执行代码，不能混用。
- `.split_manifest.json`记录分表和总表对应关系；`source_files`记录投影来源路径；`data/.import_state.json`保存成功导入的源/目标指纹，缓存可重建。defaults保留既有目标补充值，fallbacks文字不是实际算法。
- 装备运行时由一级基础投影按等级计算，不读取旧高等级行、不求Excel公式。普通导入读取缓存值、不负责重算；拆分保留所选OOXML、样式/资源，拒绝跨表公式。编辑器仅处理自身支持的引用/ROUND/四则范围，限制查LEVEL_EDITOR。
- 增量路径无变化不写JSON，变化表才重投影并合并；未知/未改段须保留。CACHE_VERSION、源/目标hash、路径、公式缓存/ZIP、事务顺序均是兼容边界，不能随整理改动。
- Store额外校验编辑ID、敌外观/抗性、武器与掉落引用；可选ship/charge发现、缺表/坏manifest及错误时机在各入口不同。改前读`test_config_input_matrix.py`，不得从一个入口推定其他入口接受范围。
- `atomic_batch`、backup/rollback与并发失败仍有限制（STATUS U-019/U-020）；此图不是数据安全保证。不要默认整读game_data.json，按上表的单段/符号定位。

## 测试路由

本页 → [test/README](../../test/README.md)的最小路由 → 必要时查[TEST_MAP](../../test/TEST_MAP.md) → 1～3个专项。不要默认读取历史test_game作为规则入口；故障现状观察不替代正确规则断言。UI任务除断言还检查实际交互；人类编辑器操作见[LEVEL_EDITOR](LEVEL_EDITOR.md)，美术约束见[ART_GUIDELINES](ART_GUIDELINES.md)。
