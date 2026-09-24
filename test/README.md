# 测试目录

星球探索：`test_planet.gd` 检查30关解锁、空闲船员占用、暂停/召回、经验系数逐关取整、船员经验成长、探索计时及1秒下限、六类装备统一倍率；`test_planet_ui.gd` 检查独立页签显隐、完整高度、按钮状态与原生截图。回归船员、统一解锁、持续光束、宝石与局部UI。

船员高科技岗位：`test_crew_scientists.gd` 检查Excel目标/间隔、x1/x10/MAX与手动购买+平均分配同结果、费用/事件/存档、失败不分配、暂停、旧高科技效率岗位清除及偏好存档；`test_crew_ui.gd` 检查岗位名称、真实分配、购买下拉、仅系统页签标记及画面。`test_crew.gd` 检查跨岗位也不能重复占用一个系统目标。回归科学家可购买性、装备、局部UI、解锁、导入和文案。

船员解锁专项：`test_crew_unlock.gd` 验证六个Excel门槛、到达/通关边界、单张匿名剪影、详情隐藏、拒绝锁定分配、逐次解锁通知、控件复用、全部解锁收起及存档兼容；截图在隔离.runtime。相关回归 crew、crew_ui、crew_equipment、crew_import.py、unlock_import.py、unlock_table、ui_text.py。

单级升级细分探针：`python test/run.py test_crew_single_probe.gd` 分开测12模块数据、静止卡片/标记、详情、排序、费用与真实隔离存档。微测量不替代整轮 `test_crew_performance.gd`；不要与其他性能测试同时运行。`test_equipment_growth.gd` 对照旧完整配置投影验证费用优化，`test_local_ui.gd` 验证装备升级不改船员页签标记。

船员优化回归：`test_crew_equipment.gd` 另验证每轮单次保存、空轮不保存、逐件事件保留、MAX压力输入与手动结果一致及费用复用在调用结束释放；`test_local_ui.gd` 覆盖批量更新、控件保留、隐藏页延迟与恢复。

船员性能审计：`python test/run.py test_crew_performance.gd --timeout 300`。36组同步升级场景与4组空闲调度；包含真实隔离存档及原UI事件，输出 `.runtime/crew-performance.json`。每组预热2次、测量10次；含1e100压力输入，不能代替完整战斗帧率。仅测量，不设机器相关耗时断言。结果说明见 [CREW](../space-battleship/docs/CREW.md)。

船员批量升级专项：`test_crew_equipment.gd` 验证无职务限制、1秒全系统调度、1/10/MAX与手动统一接口同结果同费用、10级不降级、停用模块跳过、选项持久化及旧单模块分配迁移。`test_crew_ui.gd` 另含真实下拉点击/键盘选择及选项保持。

船员专项：`test_crew.gd`（Excel成长、动态字段、岗位容量、全部炉效果、科研速率、统一自动升级/资源条件、暂停/低频调度、停用目标、旧档/实际保存与装备预留），`test_crew_ui.gd`（真实页签/船员/分配/解除/返回点击、现有效果、系统页签标记且模块内无标记、隐藏恢复、选项/实例/焦点/滚动及零无关写入/重绘；截图在隔离.runtime），`test_crew_import.py`（分表一致、字段/引用校验、可选发现、增量缓存与旧来源保留）。通过 run.py 隔离执行，Python 导入测试需要 openpyxl/lxml；回归 module_refit、furnace_income、local_ui、ui_text.py。规则与 API 见 [CREW](../space-battleship/docs/CREW.md)。

发布字体专项：`python test/run.py test_release_font.gd`。隔离绘制极细字重、发布常规字重与 Windows 开发字体；验证 TextServer 实际字重为400及文字像素覆盖量，截图写入隔离 `.runtime/font-comparison.png`。正式打包的 `verify_release.gd` 同样检查实际字重，防止配置存在但渲染未应用。

打包迁移专项：`python test/test_release_portability.py`。在 `test/work/` 创建改名且含中文/空格的副本，临时映射未占用盘符，从 Windows 目录调用真实 BAT；注入旧电脑绝对模板路径，验证完整构建、独立启动、单 EXE 输出及源预设不变。结束移除临时盘符。Windows 需允许 `subst`，不使用正式玩家数据。

## 按规则定位（Phase 10）

逐条状态、断言标签和仍缺少的验证见 [TEST_MAP](TEST_MAP.md)。普通规则任务先读下面对应的1～3个专项，不以 `test_game.gd` 作为整套基线。

| 修改内容 | 最小测试入口 |
|---|---|
| Windows 单文件发布 | 根目录 `build_release.bat --no-pause` 完整导出并验证；`powershell -NoProfile -ExecutionPolicy Bypass -File test/test_release_failures.ps1` 验证缺工具/编译/导出/运行失败保护；`verify_release.gd` 由构建器放入独立 release 验证包，不经 run.py，不进入最终 EXE |
| 资源取整 | `test_rule_rounding.gd`；涉及自动生产加 `test_auto_gen_resources.gd` |
| 装备槽位 | `test_state_ownership.gd`；涉及退款加 `test_unequip.gd`，数量限制加 `test_ship_equipment_limit.gd` |
| 装备计算成长 | `test_equipment_growth.gd` / `test_equipment_growth_import.py`；批量购买加 `test_bulk_upgrades.gd` |
| UI局部刷新/绘制 | `test_local_ui.gd`（控件身份、写入/绘制范围、真实点击、隐藏页补齐、局部解锁）；装备用`test_upgrade_ui.gd`（模块阵列、三栏、筛选排序、真实输入、模块升级/自由换装、舰体挂点、200ms展开/Esc、滚动/详情保留、静止零写入与截图）。定向性能用`test_upgrade_ui_probe.gd`经run.py隔离，3轮两种预算，勿并行其他性能测试 |
| UI 文案表 | `test_ui_text.py`（参数保护、只写文字、并发冲突、本机接口、中文硬编码审计）与 `test_ui_text.gd`（默认名称/公式一致、场景重启生效、空错误文字不放行操作）；回归 `test_local_ui.gd`、`test_jewel_ui.gd`；配置工具涉及 `test_config_panel.gd`、`test_level_editor.py`。发布专项 `python test/test_ui_text_release.py` 从工作区根直接运行，自建隔离目录，不经 run.py、不替换正式 release。 |
| 持续锁定光束 | `test_long_laser.gd`（延迟首击、线性增长/封顶、断束重锁、敌我挂载、时间步与画面）；回归`test_projectile_lifecycle.gd`、`test_travel_cooldowns.gd` |
| 坚韧与死亡 | `test_tenacity_survival.gd`：受击期减速恢复、微量回盾后连续溢出致死、不同容量和镶嵌位置、1e24容量下微小剩余生命；可选`res://.runtime/save-fixture.json`仅在隔离副本装载 |
| 护盾溢出 | `test_shield_overflow.gd`：普通/防御宝石路径、抗性、恰好破盾、溢出致死及激光/火炮/导弹/持续光束 |
| 伤害跳字 | `test_damage_numbers.gd`：200ms聚合、暴击、两条上限、三种模式、完整详情、实际光束/导弹/多目标压力与截图；回归`test_weapon_fx.gd`、`test_long_laser.gd`及`test_local_ui.gd` |
| 炮台旋转 | `test_turret_rotation.gd`：独立追踪/转速/暂停/回正/卸装换舰、旋转炮口与主光束、五舰型旋转包络；回归`test_weapon_fx.gd`、`test_long_laser.gd` |
| 我方舰船显示倍率/炮台 | `test_player_visual_scale.gd`：五舰型1.0/1.25对比、全部挂点可见炮口、逻辑出生点不变、边界和多舰布局预览；回归`test_weapon_fx.gd`与`test_long_laser.gd` |
| 离膛遮挡/绘制层级 | `test_muzzle_visibility.gd`：清除闪光和后坐后检查三类离膛弹体像素可见、业务状态不变；回归`test_weapon_fx.gd`与`test_long_laser.gd` |
| 武器表现 | `test_weapon_fx.gd`：三阶段截图、视觉不写战斗状态、转向平滑、固定尾迹、暂停/清理/粒子上限、无关UI保留；回归`test_projectile_lifecycle.gd`与`test_long_laser.gd` |
| 战斗目标 | `test_target_resistance.gd`、`test_projectile_lifecycle.gd`；涉及末敌加 `test_boss_projectile_clear.gd` |
| 战点切换画面 | `test_battle_transition_ui.gd`：真实波次切换、背景像素连续性、星空拖尾渐变/暂停、静态层不重绘、宝石面板不自动打开 |
| 科学家 | `test_scientists.gd`、`test_scientist_affordability.gd`；重建首帧按钮闪动用`test_hightech_flicker.gd` |
| AI 原型建造舱 | `test_hightech_construction.gd`：四科技造型、真实创建/部署/回收/均分、原型完成/高速事件合并、0/99.9%边界、5/12项扩展、禁止拖拽、焦点/滚动保留、隐藏/暂停/屏外停止与静态建筑/FX独立绘制，输出四舱/完成/扩展截图；回归 `test_hightech_slots`（配置增减、旧排序/空位兼容、实际存档）、`test_local_ui`、`test_jewel_furnace_ui`、`test_battle_tab`、`test_hightech_flicker`、`test_ui_text.py`。旧 `test_scientists` 的窄条进度条及旧说明模板断言不是新版 UI 基线，业务费用边界用 `test_scientist_affordability`。 |
| 存档 | `test_save_boundaries.gd`、`test_state_ownership.gd`；节点恢复用 `test_journey_resume.gd`（巡航/战斗/驻守/跨关回退/通关待确认、退出保存和真实 QA 重启）；离线资源加 `test_offline_resources.gd` |
| 宝石 | `test_jewels.gd`（200容量/拾取/合成/分解/镶嵌/10种效果/存档）；`test_jewel_fragments.gd`（旧字典迁移、统一倍率/小数、实际收入、离线幂等/溢出/随机批量）；`test_jewel_center.gd`（满包交换/原位升级/材料保护/停用空模块/存档）；`test_jewel_center_ui.gd`（大页、模块/孔位只读选择、单选自动配料、真实执行/取消、筛选排序、焦点滚动、局部写入/重绘及截图；`test_jewel_ui.gd`为兼容别名）；`test_jewel_import.py`（来源一致、重复ID、分表发现与缓存） |
| 战场返回入口 | `test_battle_tab.gd`（五个功能页顶部真实点击返回、默认首个页签、装备收起、宝石两入口/关闭、帮助显隐、全局 UI、战斗/镜头状态与无关写入/绘制保持）；回归 `test_tab_unlocks.gd`、`test_local_ui.gd` |
| UI解锁 | `test_tab_unlocks.gd`；模块/换舰流加 `test_module_ui.gd` |
| 统一关卡解锁 | `test_unlock_table.gd`（全关卡、多项去重、旧档/混合队列、已获权限保留），`test_unlock_import.py`（来源、唯一/完整/合法性、旧字段不覆盖、增量事务/编辑器），`test_unlock_ui.gd`（表内文案、真实按键逐项确认、无关控件保留与截图）；回归 `test_tab_unlocks`、`test_local_ui`、`test_journey_resume`、`test_charge_panel`、`test_jewels` |
| 一键合成/船员宝石 | `test_jewel_combine_all.gd`（连锁/分组/保护标记/配置上限/碎片补位/异常回滚/单次保存通知/读档）；`test_crew_jewels.gd`（1秒调度、同类替换、原位升级、保护、批量通知、旧档、满包空转/连锁耗时）；`test_jewel_ui.gd`（实际按钮、合并结果、高亮、无操作提示与局部刷新）；共用生成逻辑回归`test_jewel_fragments.gd` |
| 时间步进 | `test_time_steps.gd`；冷却加 `test_travel_cooldowns.gd` |

`test_time_steps.gd` 的局部子类只记录实际tick入参后调用原实现；没有替换算法或新增测试框架。

## 运行与证据

施工连续移动：`test_hightech_construction`增加四种正式美术及通用科技的固定AI身份、进度跳变/前沿切换不改位置、限速飞行/长帧上限、抵达后焊接、暂停/隐藏、分配回收及完工换轮测试；实际出发/途中/抵达截图名为`hightech-workers-*`，输出在隔离`.runtime`。这些截图固定表现层进度，数值栏仍是原业务夹具。回归`test_local_ui`及`HIGHTECH_AUDIT_ONLY_DETAIL=1`的渲染短测。

科研美术最新状态见项目[STATUS](../space-battleship/docs/STATUS.md)及[确认图/提示词](../space-battleship/assets/hightech/README.md)。`test_hightech_construction`覆盖四格图集共享、舱内尺寸、顺序图完整性、全部组件施工落点的实际像素/分区对应、整片蜂窝/整颗晶体，以及七阶段跳变、暂停FX同步、完成无目标和独立能量实际画面变化；保留真实AI操作、12项扩展、原节点/焦点/滚动与无拖拽验证。输出0/15/50/85/96/99/100%阶段与全部完工截图；96%另存单舱图。新增炉收尾只影响真实亮丝、固定阈值差异、同组件施工前沿变化及暂停时落点重绘验证。旧方块/封闭炉腔/正面光学环/菱形生长架及其几何连接测试已随被否定的美术方案退役，业务断言不变。

科研优化结果见 [优化对照](work/hightech-render-optimization.md)：资源与AI依赖分离、约10Hz数值、战场遮挡及零空FX；实体网格合批仅保留作未知科技回退，正式四项已换为共享图集与组件遮罩。`test_hightech_construction`额外覆盖收入不检查部署按钮、采样频率、恢复战场与全部完工截图；审计短模式包含遮挡/冷却零绘制断言。

整页绘制/偶发闪动审计：`test_render_budget.gd`在原生1440×810窗口、60FPS上限运行科研活动/暂停、战斗、充能、宝石，各120帧×2轮，分别记录main/可见UI/绘制依赖/星空/战场CPU、视口渲染CPU/GPU、draw calls、静态内存、纹理/缓冲区字节与节点/资源数量变化。随后关闭星空/FX/建筑分层对照，再独立执行180帧自动完成像素回读，检查11处固定页面像素与建筑单帧亮度变化（不把回读成本算作正常性能）。`RENDER_AUDIT_ROLLOVER_ONLY=1`只运行换轮探针。`RENDER_AUDIT_DATA_DIR`可指向已归档基线的data目录，测试只在隔离res://data覆盖三个JSON并重载文案，避免并行配置修改污染对照；不得用于正式项目。真实输入及性能测试串行运行。回归 `test_hightech_construction`、`test_battle_transition_ui`、`test_weapon_fx`、`test_local_ui`。

科研渲染审计：`python test/run.py test_hightech_render_audit.gd` 使用隔离原生窗口，60 FPS上限、每场景120帧×3轮，对比4/40/120项科技的暂停/闲置/研究/资源变化/隐藏状态。分别输出属性检查/写入、进度/能量材质参数写入、静态背景/美术/FX的CanvasItem绘制和全视口draw calls，并记录首次四项美术分区生成耗时，CPU只计含插桩的科研刷新，不是GPU时间或全游戏FPS；输出 `.runtime/hightech-render-audit.json`。`HIGHTECH_AUDIT_ONLY_DETAIL=1` 仅短测四舱及分层对照。勿与其他性能测试并行。当前发现与口径见 [审计报告](work/hightech-render-audit.md)。

Balance Lab 专项：`test_balance_lab.gd` 验证固定种子四档速度一致、完整一小时自动游玩、扫描与 JSON/CSV 导出及存档隔离；`test_balance_metrics.gd` 对照原战斗实现的四武器/适用宝石、统计伤害/死亡、充能跨级和碎片账本；`test_balance_v2.gd` 验证参数队列、配对五策略、Baseline、时间轴、决策密度及诊断边界；`test_balance_lab_ui.gd` 验证五页签、隐藏页与行复用、Baseline/扫描按钮、F8、原生窗口键盘激活按钮、主游戏冻结恢复、控件身份、自动导出与截图。`test_balance_performance.gd` 默认是 4200 游戏秒的分段性能探针，输出各热点累计耗时及 profile/metrics/RNG 对照指纹（不设跨机器耗时断言）；metrics 专项另覆盖防御恢复临时复用的依赖变化与释放。`test_balance_database.gd` 验证固定实验配置的原投影等价、返回值独立性、容量和显式失效。均经下面的隔离 runner 运行，实验使用说明见 [BALANCE_LAB](../space-battleship/docs/BALANCE_LAB.md)。

遵循[AGENTS](../space-battleship/AGENTS.md)的范围和保护规则。从工作区根执行：

```sh
python test/run.py test_rule_rounding.gd
```

运行器复制项目/配置/总表到`test/work/`，隔离APPDATA、LOCALAPPDATA、Python缓存；仅重定向用户目录不能隔离res://数据。Godot先导入类/素材缓存再跑测试，UI测试需要有图形环境；headless不会自动创建QA。
引擎默认取项目engine目录，可用`--godot`指定；Python需要openpyxl/lxml。Windows日志设置`PYTHONUTF8=1`，避免中文回显失败。运行器在work内启用父目录权限继承，方便查看日志/截图，不给父目录以外授权。
日志/截图/存档只在work，成功后保留证据，清理时仅删已确认的对应隔离目录。UI断言不代替视觉与真实交互核查；确认退出码及失败数，不能只看PASS字样。规则夹具可用明确内存参数，但不能据此宣称正式平衡已验收。

## 其他专项

| 任务 | 入口 |
|---|---|
| 退款/批量/舰船 | test_unequip.gd / test_bulk_upgrades.gd / test_ships.gd |
| 炼铁炉与收入 | test_furnace_income.gd / test_resource_display.gd |
| 宝石熔炼炉 | `test_jewel_furnace.gd`（来源参数、解锁/研究边界、独立周期、历史峰值/排除自身、划过/超时折损自动拾取/暂停、旧档及真实存档）；`test_jewel_furnace_ui.gd`（原生键盘分配/鼠标划过、卡片/tooltip/隐藏恢复、控件保留和独立绘制、截图）；`test_jewel_furnace_import.py`（源行投影一致、绑定与参数校验）。回归 `test_furnace_income.gd`、`test_jewel_fragments.gd`、`test_jewels.gd`、`test_local_ui.gd`、`test_ui_text.gd/.py` |
| 充能页面 | `test_charge_panel.gd`（配置驱动节点、五种状态、真实点击、翻页/扩展、分辨率、隐藏/暂停与局部写入绘制）；`test_local_ui.gd`、`test_tab_unlocks.gd` |
| 充能费率与次数 | test_charge.gd / test_charge_growth.gd |
| 驻守/回退/过关 | test_guard.gd / test_loop_retreat.gd / test_skip_clear.gd；跃迁界面用 test_warp_ui.gd（10 行、滚轮/键盘、当前关卡重复跃迁、控件/滚动保留及截图） |
| 关卡编辑器 | test_level_editor.py / test_level_editor.gd |
| QA与进程重启 | test_config_panel.gd / test_delete_save.gd / test_full_restart.py；普通重启保存失败用 test_restart_save_failure.gd |
| 配置输入与故障 | test_config_input_matrix.py；4入口接受/错误/文件副作用及事务观察 |
| 科学家配置 | test_scientist_config.py |

表内测试都经run.py隔离。矩阵生成INPUT_MATRIX.json（完整结果）与.md（索引），故障现状观察通过不代表事务安全；未决问题统一查[STATUS](../space-battleship/docs/STATUS.md)，尤其U-018/U-019/U-020。test_game及legacy探针不是默认基线，不能恢复旧机制或放宽正确断言。

性能任务另用`python test/test_performance.py --label <证据名>`，由该脚本创建隔离副本并调用phase9_probe.gd，不通过run.py启动探针。默认三轮原始测量与三轮插桩；测量时不要同时跑其他测试。规则与测量门槛查DECISIONS，历史结果由Git/本次重构记录保留。

模块成长重构：`test_module_refit.gd` 检查自由换装、空模块升级、同种装配、停用恢复、宝石/累计/存档、剩余比例及攻击失效边界；`test_module_ui.gd` 检查真实点击、跨页挂点定位、展开/滚动/筛选/选择保持与无变化零写入。`test_upgrade_ui.gd`/`test_ship_tab.gd` 为 UI 专项别名，`test_unequip.gd` 为模块业务专项别名；不必重复运行。旧退款/重开/同种限制断言已按用户确认规则迁移。

Balance Lab 长时间性能复现仍走隔离目录，允许显式延长超时（默认 180 秒不变）：

```powershell
$env:BALANCE_PERF_SECONDS = "10800"
$env:BALANCE_PERF_WALL_SECONDS = "750"
python test/run.py test_balance_performance.gd --timeout 800
```

该探针到达 21 关后在自身 `.runtime/high-stage-fixture.bin` 保存测试用成长状态，不读取玩家存档。将其绝对路径放入 `BALANCE_PERF_FIXTURE`，运行 `python test/run.py test_balance_ui_performance.gd` 可比较原生窗口在 30/60 FPS 下、12/48ms 预算的速度与报告一致性；夹具从同一成长状态重新进入遭遇战，不声称恢复完整战斗现场。使用后可清除本次设置的测试环境变量。

长期性能审计：见 [BALANCE_PERFORMANCE](../space-battleship/docs/BALANCE_PERFORMANCE.md)。test_balance_long_performance.gd 默认真实运行10min/1h/10h/100h，用 --headless --timeout 86400 关闭渲染并允许长计算；可用 BALANCE_LONG_DURATIONS 指定逗号分隔的游戏秒数。test_balance_perf_contract.gd 验证有界决策桶/在线方差/诊断日志，test_balance_lifecycle.gd 验证100次重复启动及100轮批量释放。长基准不设跨机器绝对吞吐断言。

FAST 专项：`test_balance_fast.gd` 验证普通弹命中与特殊弹 fallback/生命周期/宝石组合；`test_balance_fast_accuracy.gd --headless --timeout 3600` 默认 10 seeds × 10min/1h 配对，`summarize_balance_fast.py <隔离.runtime> <test/work输出.json>` 生成完整误差表。后期正弹速压力用 `BALANCE_FIXTURE` + `test_balance_fast_performance.gd --headless --timeout 1200`；均通过 run.py 隔离，勿并行其他性能测试。模式选择/局部控件复用沿用 `test_balance_lab_ui.gd`。详细边界见 [BALANCE_PERFORMANCE](../space-battleship/docs/BALANCE_PERFORMANCE.md)。
