# 测试入口

选测与停止规则见 [TEST](../space-battleship/docs/TEST.md)。本页保留可复用命令入口。

## 选测

按变化从下表选相关专项；同一行是候选入口。

| 修改范围 | 按需选择的入口 |
|---|---|
| 星球加成弹窗 / 自动探索默认 | `test_planet_bonus_dialog.gd` 检查本星球已生效加成、倍率实时更新、真实点击、默认开启和手动关闭存读档 |
| 伤害、取整与弹体 | `test_rule_rounding.gd`、`test_target_resistance.gd`、`test_projectile_lifecycle.gd`；命中回调中的删除/重排/清场新增用 `test_projectile_iteration.gd --headless`；持续光束用 `test_long_laser.gd`，溢出/坚韧用 `test_shield_overflow.gd` / `test_tenacity_survival.gd` |
| 推进、驻守与跃迁 | `test_guard.gd`、`test_loop_retreat.gd`、`test_skip_clear.gd`；末敌清弹用 `test_boss_projectile_clear.gd`，冷却用 `test_travel_cooldowns.gd`，跃迁界面用 `test_warp_ui.gd` |
| 换装、换舰与成长 | `test_module_refit.gd`、`test_equipment_growth.gd`、`test_bulk_upgrades.gd`；状态归属用 `test_state_ownership.gd`，界面用 `test_module_ui.gd` |
| 战舰静态预览 | `test_ship_preview.gd --headless` 检查五舰实际模型来源、真实槽位映射、候选/当前/锁定、空槽/无人机/停用、显式启用与局部复用；图形运行捕获五舰和特殊状态。运行隔离工程须包含 `dev`/`addons`，步骤见 [预览资产说明](../space-battleship/assets/ui/ships/README.md)。 |
| UI 刷新、导航与弹层 | `test_performance_ui.gd` 检查船员局部更新、隐藏恢复、焦点/草稿/滚动、装备控件复用与 HUD 绘制依赖；`test_workspace_shell.gd`、`test_overlay_layout.gd`；按实际变化选页面专项。旧 `test_local_ui.gd` 依赖已删除的科研管理按钮，暂不作为验收入口。 |
| 属性缓存与失效 | `test_stat_cache.gd --headless` 对照缓存/直接计算的战斗、RNG、换装、升级、星球激活/探索/重铸；仅在隔离用户目录存在存档时读取其副本，否则使用内存夹具。 |
| 战场表现 | `test_weapon_fx.gd`、`test_turret_rotation.gd`、`test_player_visual_scale.gd`、`test_muzzle_visibility.gd`、`test_damage_numbers.gd`、`test_battle_transition_ui.gd`；含长模拟的 `test_portrait_presentation.gd` 仅按 `full` 选择 |
| 船员 | `test_crew.gd`；等级改造用 `test_crew_levels.gd` / `test_crew_levels_ui.gd`；装备/科研/宝石/反应炉岗位分别用 `test_crew_equipment.gd` / `test_crew_scientists.gd` / `test_crew_jewels.gd` / `test_crew_reactor.gd`；解锁用 `test_crew_unlock.gd`，界面用 `test_crew_ui.gd` |
| 星系殖民 | `test_galaxy.gd --headless` 覆盖配置门槛+星球条件解锁、预生成连通蓝图与占地走廊、近层随机施工、零船员暂停、派遣批处理、并行升级、效果、防递归和存档迁移；`test_galaxy_ui.gd` 覆盖紧凑船员弹层的重复开/关闭/取消/空员/派遣召回、全景占地/缩放/拖动/点选、分阶段错峰交通、暂停、隐藏3D停绘与在线批处理；`test_galaxy_assets.gd` 检查六类五级GLB、独立核心、顶点着色、占地和缺模型回退；`test_galaxy_config.py` 检查三表及废弃字段。图形运行可用 `GALAXY_RENDER_SAMPLE=1` 输出五秒软件渲染样本；`GALAXY_RECORD_SECONDS=10` 在断言通过后从真实正常游戏帧缓冲录下半满建设测试阶段及墙钟时间戳，帧目录在隔离工程旁。仅短小规则夹具，不做时间校准模拟。 |
| 星球探索 / 建筑 / 重铸 | `test_planet_conquest_progress.gd`（征服共享经验、配置起始关、历史倍率、解锁提示记忆及旧档迁移）/ `test_planet.gd` / `test_planet_buildings.gd`（迁移、适用规则、自动探索、重铸、大数）/ `test_planet_ui.gd`；新增天体配置、独立存档、真实点击与五种动态外观用 `test_planet_celestials.gd`；球面自转与隐藏暂停用 `test_planet_rotation.gd`（20 秒图形检查）；永久奖励用 `test_planet_buffs.gd` / `test_planet_buff_ui.gd`；配置导入用 `test_planet_build_config.py` ；Blender 模型合并、材质/面数预算、动画节点与透明图标用 `test_orbital_blender_assets.gd`；探索日志、共享三维绘制与自转用 `test_planet_orbit_acceptance.gd` |
| 科研与当前大厅 | 费用/可购买性用 `test_scientist_affordability.gd`；速率、船员、大数与模拟器一致性用 `test_research_rate_snapshot.gd --headless`；大厅交互用 `test_hightech_construction.gd`，科研效果/参数强调、AI 控件、锁定信息和详情滚动用 `test_research_chrome.gd --headless`，配置工位用 `test_hightech_slots.gd`；当前工程的隔离副本须包含 `dev`/`addons`（同战舰预览） |
| 炉产出与资源显示 | `test_furnace_income.gd`、`test_enhancement_furnace.gd`、`test_auto_gen_resources.gd`、`test_resource_display.gd` |
| 反应炉 | `test_reactor.gd`；页面用 `test_reactor_ui.gd`，能源分配交互用 `test_reactor_allocation_ui.gd`；依赖刷新、隐藏恢复、焦点和暂停用 `test_reactor_refresh.gd` |
| 全局装备强化 | `test_enhancements.gd` 检查共享顺序/实际装备门槛/全局事件/费用/MAX/分支；`test_enhancement_branches.gd` 检查36选项、状态/组合/实际恢复/混合抗性；`test_enhancement_branch_attacks.gd` 检查四武器、规范攻击计数、单次连锁与有界连发；`test_deferred_enhancements.gd` 检查延迟队列、全局清除和时序；`test_neutral_memory_protection.gd` 检查无抗性临时保护、原始伤害溢出和延迟交互；`test_enhancement_save.gd` 检查旧档清理/余额/新档/重铸；`test_enhancement_furnace.gd` 检查碎片生产不递归；`test_enhance_config.py` 校验唯一配置表和非法输入。旧宝石背包/合成/镶嵌专项已被替代，不作新系统验收入口。 |
| 解锁 | `test_unlock_table.gd` / `test_unlock_ui.gd`；页签显隐用 `test_tab_unlocks.gd` |
| 时间、超时空与离线 | `test_time_steps.gd`、`test_offline_resources.gd`；页面用 `test_chrono_ui.gd`，启动结算弹窗用 `test_chrono_login.gd` |
| 存档与重启 | `test_save_policy.gd --headless` 检查真实时间定时/手动触发、间隔、业务内存提交、故障保护及备份恢复；去掉 `--headless` 检查设置界面。`test_jewel_combine_all.gd --headless` 检查合成事务，`test_journey_resume.gd --headless` 检查手动存档及不写盘的退出/重启。旧帧合并、即时写盘和异步候选夹具只描述旧机制，不作为当前保存验收入口；第二轮历史证据见 [报告](../space-battleship/PERFORMANCE_OPTIMIZATION_2.md)。 |
| 音乐与开关偏好 | `test_bgm.gd` |
| 文案 | `test_ui_text.py`；涉及运行时文字行为时用 `test_ui_text.gd` |
| 配置导入 | 按所改分表选择 `test_crew_import.py`、`test_jewel_import.py`、`test_unlock_import.py`、`test_equipment_growth_import.py`、`test_jewel_furnace_import.py`、`test_reactor_config.py`、`test_scientist_config.py` 或 `test_offline_config.py` |
| 配置工具与编辑器 | `test_config_workbooks.py`、`test_level_editor.py` / `test_level_editor.gd`、`test_config_panel.gd`；输入/事务边界用 `test_config_input_matrix.py` |
| Balance Lab | 按变化选 `test_balance_metrics.gd`、`test_balance_v2.gd`、`test_balance_database.gd`、`test_balance_lab_ui.gd`；模拟及 FAST 专项先查 [实验说明](../space-battleship/docs/BALANCE_LAB.md) 与 [性能协议](../space-battleship/docs/BALANCE_PERFORMANCE.md) |
| 敌方舰队生成与标签 | `test_enemy_fleet_formation.gd --headless` 检查八类阵型、奇数核心、结构分数/阈值、去重、数量/强度与重放；`test_enemy_fleet_simulator.gd --headless` 覆盖旧基础分析（含固定数值夹具）；`test_enemy_fleet_ui.gd` 检查游戏 F9。独立工具布局预览由 `test_battle_lab_standalone.gd` 检查。原生光标不可用时，UI 夹具使用内嵌窗口路由鼠标事件。 |
| 我方测试组合与配对 | `test_player_loadout_generator.gd --headless` 检查原规则合法性、四类覆盖、seed/JSON 复现、属性投影、去重和配对加载；共用 `test_enemy_fleet_ui.gd` 检查双页独立更新、武器/标签筛选、配对预览与清空。 |
| 批量战斗 | `test_fleet_battle_runner.gd --headless` 检查交叉配对、seed/JSON 复现、错误续跑、超时/停止、伤害与 HP、四类武器 FAST/EXACT、汇总输出与隔离；`test_enemy_fleet_ui.gd` 覆盖范围选择、执行和局部更新。千场性能属于 full：在已有隔离目录运行该 Godot 脚本并传入 `-- --stress`，保留该目录的 APPDATA/LOCALAPPDATA 隔离设置。 |
| 分层抽样与动态加测 | `test_fleet_battle_sampling.gd --headless` 检查 5000×5000 抽样池的有界候选、去相似、标签覆盖、优先级、各加测理由、稳定停测、手动重点与预算/复现/落盘。三页交互共用 `test_enemy_fleet_ui.gd`，包括重点标记和抽样统计。 |
| 战斗结果分析 | `test_fleet_result_analyzer.gd --headless` 检查按样本加权、敌我标签、条件武器分析、区分度/候选、低样本和时间波动降级、旧文件兼容、重复记录拒绝与六文件导出。`test_enemy_fleet_ui.gd` 覆盖第四页读取当前批次、排序筛选、关联配对和不重跑战斗。 |
| 分析页定向复测 | `test_fleet_batch_retest.gd --headless` 检查低样本配对预算、只跑指定配对、原批次保留、合并统计及方差、分析重读；`test_battle_lab_standalone.gd` 检查同页启动复测并自动刷新。 |
| 关卡设计卡片 | 共用 `test_fleet_result_analyzer.gd` 验证设计分类、低样本不排名、强弱不重复；`test_enemy_fleet_ui.gd` 检查默认卡片/总览、中文标签、控件复用、滚动后详情点击以及原统计视图保留。 |
| 独立战斗模拟工具 | 用 `tools/build_result_analyzer.py --output ../test/work/battle-lab-standalone` 构建隔离包；APPDATA/LOCALAPPDATA 指向包内 `.build-user/roaming`、`.build-user/local`。用包内 `runtime/analyzer.exe --path 包目录 --script 测试绝对路径` 运行 `test_fleet_battle_runner.gd --headless` 验证原规则，`test_fleet_level_generator.gd --headless` 验证初筛、私有成长补测和原关卡结构，再运行 `test_battle_lab_standalone.gd` 验证五页生成→战斗→分析→自动关卡。 |
| 战斗模拟速度 | 在独立包中运行 `test_fleet_battle_speed.gd`（需窗口），用相同 100 场分别测 8 ms 和独立工具的帧预算；打印墙钟时间/帧数并核对逐场结果。`test_fleet_battle_runner.gd` 检查无科研批次与原路径的结果/RNG 一致。 |

需定位具体规则断言时再查 [TEST_MAP](TEST_MAP.md)，不要将其当作执行清单。未列出的脚本仅在有明确相关需求、核对当前断言后使用；`test_game.gd` 和 legacy 探针不是默认基线。旧科研窄条/旧返回入口的 UI 夹具不用于当前大厅验收，当前入口见上表。

## 运行

从工作区根目录执行一个专项：

```powershell
$env:PYTHONUTF8 = "1"
python test/run.py test_rule_rounding.gd
```

- `run.py` 在 `test/work/` 创建项目与配置副本，并隔离用户目录和 Python 缓存。不得用正式玩家存档复现；仅改用户目录不能隔离 `res://` 数据。
- Godot 测试先导入素材；导入时间不算业务测试耗时。默认每个进程超时 180 秒，必要时显式指定 `--timeout`；`--godot` 可指定引擎。Python 导入专项需要 `openpyxl/lxml`；命令不可用时用已安装的 Python 可执行文件绝对路径替换 `python`。
- UI 专项需要图形环境；`--headless` 仅用于适用的逻辑/模拟专项。真实输入及性能测量串行运行。
- 核对退出码、失败断言及日志；UI 改动核对受影响画面与真实交互。产物仅在 `test/work/`。核对后删除本次运行中无用的隔离目录和临时数据；失败排查或交接所需证据先保留。不要清理仍在运行或与本次测试无关的目录。

## 性能与发布（按需）

以下不是日常回归清单；仅在相应性能任务、重大重构、明确要求或打包前选用。

| 目的 | 入口 |
|---|---|
| 船员升级测量 | `python test/run.py test_crew_performance.gd --timeout 300`；定位单级热点才用 `test_crew_single_probe.gd` |
| UI/科研渲染测量 | 经 `run.py` 选择 `test_upgrade_ui_probe.gd`、`test_hightech_render_audit.gd` 或 `test_render_budget.gd` |
| 整体性能 | `python test/test_performance.py --label <证据名>`；脚本自建隔离副本，不单独运行内部探针 |
| 当前存档帧耗时 | `python test/saved_game_perf.py --label <证据名>` 复制开发存档及工程，测量已解锁页面；`--snapshot <先前的input-save.json>` 保持前后同一输入，`--fps 60` 验证限帧表现，`--speed 2` 测倍速。`--instrument` 只定位热点，不用于最终帧率比较；`--reuse <该脚本生成的隔离目录>` 复用素材导入。 |
| 第二轮历史保存阶段与尾帧 | `saved_game_tail.py` / `tail_save_candidate.py` / `verify_tail_candidate.py` 依赖旧触发和异步接口，只用于对应冻结副本；不要对当前定时/手动机制安装旧候选。历史证据和分析入口见 [报告](../space-battleship/PERFORMANCE_OPTIMIZATION_2.md)。 |
| Balance Lab 长模拟/压力 | 按 [性能协议](../space-battleship/docs/BALANCE_PERFORMANCE.md) 选择场景、夹具与超时；FAST 是玩法模式名，不等于日常 `fast` 层 |
| Windows 单 EXE | `build_release.bat --no-pause`；构建器自动运行 `verify_release.gd`，后者不经 `run.py`、不进入最终 EXE |
| 构建失败保护 | `powershell -NoProfile -ExecutionPolicy Bypass -File test/test_release_failures.ps1` |
| 跨路径迁移 / 发布文案 | `python test/test_release_portability.py` / `python test/test_ui_text_release.py`；从工作区根直接运行，自建隔离目录，不经 `run.py`。迁移测试需 Windows `subst` |
| 发布字体 | `python test/run.py test_release_font.gd` |

现有缺口与故障统一见 [STATUS](../space-battleship/docs/STATUS.md)。内存夹具通过不代表正式数值平衡验收，故障观察通过不代表事务安全。
