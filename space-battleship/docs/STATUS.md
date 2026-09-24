# STATUS

## CURRENT

### 星球探索

- DONE：第7页签改为左侧星球列表、中央大沙盘、右侧星球与探索信息、底部设施栏。新增透明星球贴图、缓慢表面/云带运动、大气辉光、三层前后轨道、低频运输与碎片、探索扫描及完成脉冲。六类设施视觉可从可选数据挂载，底部对应卡片联动轨道高亮；当前正式数据没有已拥有设施，底栏明确显示空状态，六类模型仍是程序绘制占位。
- CHANGED：`planet_panel.gd` 只重排现有页签内控件并增加列表/设施视觉卡片，`planet_visual.gd` 单独绘制动态沙盘，`main.gd` 仅转交已有完成事件的实际经验。新增 `assets/ui/planet-globe.png` 和UI文案绑定；探索/经验/装备公式、解锁、正式数值配置和玩家存档不变。可选视觉字段为星球行的 `visual`（颜色、贴图）及 `visualFacilities`（数组或 Excel JSON 文本），正式表未新增字段。隐藏页停止动画，可见时最多约24Hz重绘。
- VERIFY：隔离星球业务30项、星球页签32项、局部UI79项、文案Python 6项通过；已查看原生1440×810待命与六类设施夹具画面。设施夹具只在隔离测试注入，不写正式配置或存档。
- EVIDENCE：`../../test/work/test_planet_ui-779j0m5g/space-battleship/.runtime/planet-tab.png`、`planet-six-facilities.png`；文案 `../../test/work/test_ui_text-aklc5081`。
- NEXT：真实设施拥有数据和设施玩法尚不存在；未来接入时传 `id/type/owned/orbit/phase/level/status` 至视觉字段。不同星球可配 `visual.texture/surfaceColor/atmosphereColor`。当前设施仍需独立模型贴图。
- DONE：通关30关开放独立星球页签；空闲船员可开始/召回探索。首颗星球基础时间100秒、基础经验100；完成后探索度加1，时间按基础时间平方除以基础时间加探索度，最低1秒。经验取星球基础经验乘最高关系数，30关1、之后每关乘1.2并保留两位小数；船员升级经验从100起每级增20%。装备最终数值统一乘 `(1+0.1)^(探索度^0.5)`，指数在config配置。
- CHANGED：新增planet分表、投影、存档、探索结算与独立页签；扩展level、crew、config及unlock分表，武器/防御装备共用最终数值入口；新增UI文案绑定。探索中的船员行和详情显示星球、倒计时与完成经验，详情可跳至星球页或召回，暂时隐藏岗位分配控件。暂停不推进，离线不补探索。
- VERIFY：配置增量导入通过；隔离星球业务30项、星球页签18项、船员58项、船员UI46项、统一解锁246项、持续光束83项、宝石111项、局部UI79项、文案6项、船员导入4项、解锁导入5项通过。船员页探索倒计时仅写该船员行与选中详情，静止采样零写入，召回后恢复待命；已查看原生1440×810两页画面，按钮完整可见。六类装备数值入口均覆盖；四类武器继续复用原宝石/暴击/BUFF/命中结算，未增加特殊攻击分支。旧 `test_config_workbooks.py` 的10项旧总表夹具缺unlock表，仍报相同的既有验证错误；本轮真实分表增量导入和对应专项通过。正式玩家存档未操作。
- EVIDENCE：`../../test/work/crew-exploration-ui.log`、`crew-exploration-test_crew_ui.gd.log`、`crew-exploration-test_local_ui.gd.log`、`crew-exploration-test_planet.gd.log`、`crew-exploration-text.log`；[船员页实图](../../test/work/test_planet_ui-l3gtgcs3/space-battleship/.runtime/crew-exploring.png)。原验证日志：`../../test/work/planet-save-final.log`、`planet-ui-interaction.log`、`planet-crew-run.log`、`planet-crew-ui-window.log`、`planet-unlock-final.log`、`planet-long-laser-window.log`、`planet-jewels.log`、`planet-local-ui.log`、`planet-text-run.log`、`planet-import-test-utf8.log`、`planet-unlock-import-final.log`；[星球页实图](../../test/work/test_planet_ui-fegwvqil/space-battleship/.runtime/planet-tab.png)。
- NEXT：重启开发版查看；未导出EXE。

### 自动飞行铀表现

- DONE：自动飞行铀改为分面晶体、柔光环、脉动亮核、尾迹与常显资源名；按用户反馈，将晶体和光圈线性尺寸再缩至上一版的1/4，资源名保持可读。鼠标靠近仍显示数量。
- CHANGED：仅main的战场资源绘制分支；生成、移动、拾取、产量、存档与其他资源外观不变。连续动画仍由既有battle_layer绘制，隐藏与暂停沿用原调度。
- VERIFY：隔离资源生成/拾取6项、资源显示9项、局部UI79项通过；缩小后资源显示9项再次通过，已查看原生1440×810战场截图。diff检查通过。
- EVIDENCE：../../test/work/uranium-mechanics-test.log、uranium-visual-quarter.log、uranium-local-ui.log；[实图](../../test/work/test_resource_display-3db0ppgf/space-battleship/uranium-flight.png)。
- NEXT：重启开发版查看；未导出正式EXE，正式玩家存档未操作。

### 启动资源导入

- DONE：修复新增资源后从启动.cmd进入游戏时，资源尚未导入而使界面构建中断的问题。日常无新增资源仍跳过导入。
- CHANGED：启动脚本在已有全局类/导入缓存之外，检查assets中的图片、声音、字体是否存在对应`.import`描述；发现缺失即运行既有Godot导入流程。替换已有资源仍使用QA「大重启」更新。游戏逻辑、正式玩家存档未改。
- VERIFY：用户录屏显示点击宝石后页签选中但仍停留底部空页；同一启动进程日志首先报`crew_locked.svg`无资源加载器，随后`crew_panel.gd`编译失败，导致`build_equipment_tabs`在连接宝石页回调前中断。当前项目46个资源中仅该新增SVG缺少`.import`。隔离测试导入后宝石页UI65项、顶部页签50项通过；启动条件及diff已检查。用户现场重启待验证。
- EVIDENCE：现场日志 `.userdata/roaming/Godot/app_userdata/太空战舰 · 深空远征/logs/godot2026-09-23T17.27.04.log`；用户录屏 `C:/Users/Administrator/Videos/Captures/太空战舰 · 深空远征 (DEBUG) 2026-09-23 17-27-20.mp4`；隔离测试 `../../test/work/jewel-reopen-ui-final.log`、`../../test/work/jewel-reopen-tabs.log`。
- NEXT：关闭当前游戏窗口，再运行工作区启动.cmd。启动会自动导入缺失的新资源；若导入失败检查`.runtime/startup-import.log`。

### 船员系统

- DONE：六名船员按通关10、20、25、30、35、40关解锁；首人前隐藏页签，之后只预告下一名匿名剪影。装备岗位每秒按1/10/MAX尝试升级全部启用模块；高科技岗位每秒按×1/×10/MAX购买AI，成功后平均分配；宝石岗位每秒自动合成背包宝石，并为已镶嵌宝石换入同类型更高级宝石或按原配方原位升级。研究效率与宝石熔炼速度岗位不再配置。已分配标记只在相应系统页签显示单个👤，无人数和模块内标记。
- CHANGED：四个岗位maxCrew均为1；宝石岗位注册 jewel+AUTO_COMBINE，旧smelting_speed存档分配迁移到 jewel_auto+jewels，等级/经验保留。无合成材料时仅线性扫描背包，不进入完整合成/保存/UI事件；有材料时复用原规则。一键合成连锁每轮批量结算，避免每个配方重扫整包；多孔位替换合并一次保存/事件，并只刷新变化装备卡片。BalanceGame 覆写同步可选通知参数。Excel interval/baseValue 控制检查周期，文案从 ui_text 获取。其他船员动态数据、解锁与装备用途不变。
- VERIFY：本轮宝石船员20、船员58、船员UI46、宝石一键合成49、宝石规则111、宝石中心23、宝石UI68、局部UI79、船员导入4、文案6、Balance Metrics 78、换装51、长激光83项，共676项通过。200格满背包固定点每30次：原完整检查约56～58ms，船员轻检约32～33ms，均无保存/通知；97次连锁合成原测15.35ms，分组批量结算后重复测约4.76～7.84ms；十模块换宝石约2.14ms且只保存/通知一次（同步耗时，非整帧FPS）。已查看宝石页签真实截图。宝石等级仍走统一 jewel_effects/战斗结算，不增加独立攻击路径；十类宝石效果、四类武器、长激光、换装与防御宝石回归通过。攻击类型×效果适用矩阵见 CREW。
- EVIDENCE：../../test/work/test_crew_jewels-qp29j4xn/test.log、test_crew_ui-7wondlm2/test.log、test_jewel_combine_all-s44vnu1n/test.log、test_jewels-ze0c6b0b/test.log、test_jewel_center-0zhrizng/test.log、test_jewel_center_ui-pdg5ya44/test.log、test_local_ui-hc5_u2dp/test.log、test_crew_import-rv4h37in/test.log、test_ui_text-zkxiav44/test.log、test_balance_metrics-iz8wopic/test.log、test_module_refit-3cspu5sq/test.log、test_long_laser-qe1wzvl1/test.log；[宝石页签](../../test/work/test_crew_ui-7wondlm2/space-battleship/.runtime/crew-jewel-tab-badge.png)。
- NEXT：重启开发版生效，正式玩家存档未操作，未导出EXE。经验现由星球探索发放，船员装备仍仅预留。旧test_scientists.gd仍引用旧科研UI控件，需单独迁移。

### 充能换轮衔接

- DONE：取消完成后强制保持100%与倒退收缩。下一轮立即显示真实进度，重置旧插值起点；完成提示改为独立外圈160ms淡出，不阻塞进度或百分比。充能、升级、资源结算、存档与100ms UI采样/30Hz绘制频率不变。
- CHANGED：仅charge_circuit的完成提示与进度插值关系；页面专项更新对应显示断言，新增test_charge_rollover覆盖同级次数增长、升级归零、连续100ms采样穿过提示结束、高速连续换轮和暂停。
- VERIFY：旧版换轮专项14项中9项失败，修复后14项全部通过；隔离充能页面84项通过，退出码均0。已检查真实换轮截图，节点和详情百分比一致，未再停留100%。局部diff检查通过；页面日志保留并行船员功能缺少crew.*文案和引擎证书诊断，未修改这些功能。
- EVIDENCE：../../test/work/charge-rollover-before.log；../../test/work/test_charge_rollover-kahnt7gr/test.log；../../test/work/test_charge_panel-4sqc0sc0/test.log；../../test/work/test_charge_panel-4sqc0sc0/space-battleship/charge-round-complete.png。
- NEXT：重启当前开发版验收；未重新导出正式EXE。

### 顶部返回战场

- DONE：原底部「战场」空页签改为界面顶部「返回战场」按钮；默认选中首个功能页「装备」。返回关闭宝石面板、收起装备大页，恢复战场与底部装备区。
- CHANGED：main 的 return_to_battle 共用返回路径，按钮在宝石覆盖页显示时移至顶部导航右侧；宝石页关闭/Esc也返回首个页签，装备镶嵌入口自身关闭仍保留原布局。移除空页签后修正宝石拾取反馈目标索引与直接受影响测试入口。只调整导航和页面布局，复用控件，战斗/镜头/正式配置/存档不变。
- VERIFY：顶部返回50、解锁17、局部UI68、宝石中心UI69，共204项通过；覆盖五页真实点击、装备展开后返回、宝石两入口、关闭、帮助显隐、隐藏恢复、控件身份、无关属性写入与静态层绘制。已查看1440×810返回后和宝石页顶部入口画面。文案目录886行校验通过；完整文案Python测试5项通过、1项因并行新增 crew_system.gd 缺少 crew.module_target 文案失败，未修改该功能。引擎证书和已有弹窗焦点诊断仍见日志。
- EVIDENCE：[返回画面](../../test/work/test_battle_tab-73ym2j24/space-battleship/.runtime/battle-return.png)、[宝石页入口](../../test/work/test_battle_tab-73ym2j24/space-battleship/.runtime/battle-return-jewels.png)、[返回检查](../../test/work/top-return-battle.log)、[解锁](../../test/work/top-return-unlocks.log)、[局部刷新](../../test/work/top-return-local.log)、[宝石中心](../../test/work/top-return-jewels.log)、[文案检查](../../test/work/top-return-text.log)。
- NEXT：重启开发版查看；未重新打包正式EXE。并行船员功能补齐文案后再跑完整文案检查。

### 宝石中心

- DONE：按高科技页参考图收窄宝石工坊纵向范围，页面从y127到y775（1340×648），顶部标题/资源/「返回战场」整排保持原位。宝石页签导航移至y96，底部不压住音效按钮。
- CHANGED：jewel_panel直接子控件按原740px纵向基准缩放布局，静态workshop-frame允许适配新尺寸；模块/孔位按钮缩短，文本和宝石图不整体缩小。main仅调整宝石页导航区域、背景遮挡和通用返回按钮位置。滚动列表保留，宝石业务、数值、存档不变；此前资源导入修复见上方。
- VERIFY：宝石UI68、顶部页签50项通过；覆盖真实打开/返回、边界、画框与底栏、孔位/背包/详情、合成结果、隐藏恢复及无关控件不重建/不额外写入。已查看1440×810主画面和10颗宝石的滚动截图，顶部原布局与音效按钮均清楚可见。
- EVIDENCE：[缩小后的宝石页](../../test/work/test_jewel_ui-x5f1xcl5/space-battleship/.runtime/jewel-direct-tab.png)、[完整背包](../../test/work/test_jewel_ui-x5f1xcl5/space-battleship/.runtime/jewel-premium-collection.png)、[宝石UI](../../test/work/jewel-compact-delivery-ui.log)、[页签回归](../../test/work/jewel-compact-delivery-tabs.log)。
- NEXT：重启开发版查看；未重新打包正式EXE。

### AI 施工连续移动

- DONE：修复施工前沿切换时AI跟随落点瞬移，以及人数变化改变留任单元位置。保留现有建筑美术和真实施工落点；科研数值、速度、完成规则不变。
- CHANGED：仅hightech_construction表现层增加每舱固定三个位置/目标/到位计时。进度更新立即停掉旧焊接，从原位置限速飞往新目标，接近减速、稳定后焊接；完成验收保留悬停，下一轮连续出发。通用未来科技也固定身份。移动复用原24Hz采样、暂停/隐藏冻结，长帧最多推进100ms移动，不新增节点或独立刷新循环。
- VERIFY：隔离建造185、局部UI79、渲染短测6，共270项通过。新增四项正式科技及通用回退的65项运动检查，覆盖换点/同组件前沿、增减AI、限速/长帧、到位开焊、暂停/隐藏、完工换轮；原控件身份、无关绘制与实际交互检查保留。暂停120帧FX/静态层绘制、材质参数及UI属性写入均0。已核对出发、途中、抵达实际画面；本轮未做新的CPU/GPU前后性能结论。
- EVIDENCE：../../test/work/hightech-worker-motion.log、hightech-worker-local.log、hightech-worker-audit.log；[途中画面](../../test/work/test_hightech_construction-ycttl6sa/space-battleship/.runtime/hightech-workers-travelling.png)、[抵达画面](../../test/work/test_hightech_construction-ycttl6sa/space-battleship/.runtime/hightech-workers-arrived.png)。运动画面固定显示进度作视觉夹具，业务数值不随表现探针修改。
- NEXT：重启开发版查看；未重新导出EXE，正式玩家存档未操作。整页偶发闪动的未复现限制仍见下一节。

### 绘制开销与偶发闪动

- DONE：完成整页绘制/资源审计，优化星空提交与小弹体纹理；复现并平滑科研完成时的建筑亮度跳变。用户所述“正常放置时页面偶发闪几下”未稳定复现为整页白/黑闪，不能宣称全部解决。保留已确认的高科技素材、自然施工缺口与落点、数值/规则/正式配置/玩家存档及其他并行修改。
- CHANGED：main的200个星点合为单次ArrayMesh绘制，starfield shader以显式参数驱动原运动/拖尾/暂停，网格首绘生成、随场景释放。建造completion_state从原显示进度200ms淡入验收，再于末尾400ms衔接当前真实进度，保留1.25秒总提示与2.75秒冷却；仅短暂可见过渡按帧写材质参数，保持阶段不重复写，普通FX/能量仍24Hz、隐藏/暂停冻结。三张飞行弹体仅导入最长边256，原PNG、显示尺寸和其他美术不变。已有crew_system的equipment_member推断编译错误只补显式bool，未改船员行为。
- VERIFY：最终完整审计22、建造120、战斗切换13、武器特效43、局部UI68，共266项通过；已检查真实武器画面。10个稳态窗口（五种页面×2，每次120帧）节点/资源数增量均0，静态内存约86～89MiB。原生输入测试串行。另180帧真实完成事件/图像回读，建筑单帧平均亮度差峰值0.157927降至0.021090（约86.6%），11处固定页面像素无异常改变；短测不代表偶发整页问题和长时资源泄漏已排除。
- VERIFY：相同业务脚本和三个JSON基线（仅在隔离副本恢复，避免并行船员配置修改污染），星空CPU指令约1.6～1.7ms降至0.010ms，独立绘制200～400次降至1次。科研活动整页绘制均值548.6降至260.8、GPU0.749降至0.479ms；总纹理峰值170.79降至147.24MiB，减少23.56MiB。五页完整CPU/GPU/绘制/内存指标及限制见报告；不将绘制次数直接换算FPS。
- EVIDENCE：[完整前后报告](../../test/work/render-budget-comparison.md)、[最终同输入JSON](../../test/work/test_render_budget-kops4hyg/space-battleship/.runtime/render-budget.json)、[实际武器画面](../../test/work/test_weapon_fx-xnbf4ov_/space-battleship/.runtime/weapons-flight.png)。回归日志：../../test/work/render-final-test_hightech_construction.gd.log、render-final-test_battle_transition_ui.gd.log、render-final-test_weapon_fx.gd.log、render-final-test_local_ui.gd.log。原高科技美术来源见[提示词](../assets/hightech/README.md)，自然缺口和初始化成本的上轮证据保留在hightech-organic-final-ui.log / hightech-organic-audit.log。
- NEXT：QA点击一次「大重启」重新导入纹理；普通启动已跳过导入。未重新导出EXE。偶发整页闪动仍需实际触发证据；已保留test_render_budget复测入口及分离回读探针。其他任务未决项不变。

## BALANCE LAB PERFORMANCE

- DONE：复现并优化 Balance Lab 20+ 关不足 10x。BALANCED/seed12345/3h 自然推进到 22 关；核心重复配置投影/宝石效果读取增加耗时，原生窗口固定 12ms 工作预算又限制吞吐。本轮仅改变 Lab 的派生结果复用和工作片预算，未降低固定步长精度或修改正式数值/玩法/存档。
- CHANGED：新增 `balance_database.gd`，每轮私有固定配置复用原 ShipDatabase 投影（装备/敌武器行各最多256项，向调用者返回独立副本）；`balance_game.gd` 只在一次 tick 内按模块对象身份复用宝石效果并返回独立攻击副本。换装/升级/宝石变化与 tick 退出清空；动态命中次数、科研和充能增益仍实时计算。`balance_runner.gd` 将 100x/1000x 预算改为48ms，1x/10x仍12ms。
- VERIFY：配置投影85、metrics63、V2 64、UI27、Lab42项通过，共281项；Lab回归含四档速度确定性与一小时新局。原生窗口21关真实成长夹具，30/60 FPS下12/48ms各重复两次：旧预算6.35～9.93x，新预算13.90～17.87x，8份报告完全一致；单次process峰值约54～64ms，不将48ms目标声称为绝对输入延迟上限。夹具重新进入遭遇战，非完整运行现场恢复。
- VERIFY：相同配置文件、同种子10800游戏秒自然新局，36个检查点 profile/metrics/RNG 指纹完全一致，最终22关；总耗时366.126→273.570秒，最后900游戏秒52.563→40.663秒，均含诊断计时开销。证据 `../../test/work/balance-high-performance.json`、`balance-high-before.log`、`balance-high-after.log`、`balance-high-native.log`、`high-test_balance_database.gd.log`、`high-test_balance_metrics.gd.log`、`balance-high-v2.log`、`balance-high-ui-controls.log`、`balance-high-core.log`。
- CHANGED：性能探针支持测试环境变量延长时长，隔离 runner新增显式 --timeout（默认180秒不变）；新增原生窗口工作预算对照探针。操作与缓存生命周期同步 [BALANCE_LAB](BALANCE_LAB.md)、ARCHITECTURE、测试入口；原有正式 level.xlsx/game_data.json 修改保留。
- NEXT：重启 Debug 游戏后生效。当前实证覆盖自然22关和21关窗口夹具，不承诺所有后续关卡固定倍率。此前数值复盘/扫描建议见 [balance_history](balance_history.md)，本轮不改数值。

## BALANCE LAB IMPLEMENTATION

- DONE：在第一版基础上完成 Balance Lab 第二版：真实字段批量扫描与分指标敏感度、独立 JSON Baseline/条件核对、限量时间轴与事件、配对五策略、具体证据分级诊断、决策密度及五页签。未修改正式数值、正常战斗规则或玩家存档。
- CHANGED：新增 balance_timeline/balance_baseline/balance_analyzer/balance_views；扩展原七个 Lab 模块及文案目录/契约，保留原 tick、经济、装备、宝石、充能接口。表格控件和行复用，只刷新脏的当前页。原第一版 main/game/Debug 入口改动保留。说明见 [BALANCE_LAB](BALANCE_LAB.md)。
- VERIFY：第二版专项 64、UI 专项 25、原 Lab 42、metrics 35、文案 Python 6 项通过；共 172 项。包括配对种子、随机策略跨速度/任务顺序一致、真实字段覆盖、基线往返/条件不符、诊断证据、决策去重、长模拟采样上限、隐藏页恢复与无额外表格写入。已检查五页截图 `../../test/work/test_balance_lab_ui-rf2ebpnd/space-battleship/.runtime/`；按钮通过原生窗口键盘激活，未声称鼠标注入通过。日志 `../../test/work/balance-v2-full.log`、`balance-v2-ui-verified.log`、`balance-v2-regression.log`、`balance-v2-metrics.log`、`balance-v2-text.log`。
- VERIFY：一小时真实新局 BALANCED 约 51.8 秒计算时间，最终第 8 关；四种武器伤害占比：持续激光 35.8%、炮 32.5%、导弹 19.8%、激光 11.9%。报告 `../../test/work/balance_lab/balance_2026-09-21T17-38-01_64297446.json`。这只是单种子样本，不是平衡结论；未解锁/未尝试与低贡献已分开提示。
- NEXT：当前需求完成。敏感度为端点弹性，不覆盖非单调内部峰值；同种子不同策略不保证战斗随机调用顺序相同。基线对比使用匹配实验集合的聚合均值；极端数值、真实玩家策略与诊断阈值仍需结合报告判断。既有 U-024 保留，不改无关旧断言。

## DONE

- 已具备自动战斗、驻守/跃迁、资源与离线结算、独立模块成长/自由换装与换舰、科学家研究、充能和炼铁炉。
- 已具备宝石/碎片/合成/分解/镶嵌与战斗效果；游戏UI、QA、关卡编辑器、分表投影及专项测试；装备等级/玩家冷却以槽位为权威，读取无隐式写入。

## KNOWN ISSUES

以下仅记录未解决事项；证据不等于设计批准，不能在其他任务中顺便修复。脚本简名位于scripts/，测试简名位于../test/，其余路径相对项目。

| ID | 问题与必要入口 |
|---|---|
| U-001 | 实验配置晋升与长期可迁移来源指纹协议未定；`tools/config_workbooks.py`。 |
| U-005 | 拾取/回退/换关默认时长、弹速换算、初始资源、保损/自动推进等实现补充尚未全部获策划确认；JSON.defaults、game.gd。 |
| U-006 | 最小/零伤害、跨盾取整、一级行抗性、同优先级索敌与拾取半径的设计适用范围待定；`game.gd:reduced_damage/hit_player`。 |
| U-007 | 资源/装备扩展与不同导入入口引用/重复ID校验未完整对齐；仍有五类装备、资源ID1/2及config参数映射限制，`tools/import_workbook.py`。 |
| U-008 | 非连续cleared、坏档/多实例共享档等风险未解决；`game.gd:load_progress/save_progress`。普通QA重启已拦截save_error，但不代表存档所有写入故障均可检测或恢复。 |
| U-009 | 品质、独立能源/建造/探索、独立关卡AI及全局结局未设计；范围问题，不自动创建模块。 |
| U-010 | Windows x64 单 EXE、固定版本模板与一键验证已完成；另一台干净 Windows 真机验收、其他平台导出及 CI 未完成；[操作说明](../README.md)。 |
| U-011 | 旧State/leave仍有消费者；敌方导弹未被编队引用且不套玩家齐射机制；`game.gd`、TEST_MAP，先核用途。 |
| U-012 | 总览!D17倍率示例2与线性1.9歧义仍在；`database.gd:ratio`，不得擅改舍入时机。 |
| U-013 | 内存规则夹具/满级通关不能证明真实初始数值成长平衡；[TEST_MAP](../../test/TEST_MAP.md)。 |
| U-017 | test_game仍混有旧安装/循环/配置假设，不能作整套规则基线；[测试入口](../../test/README.md)。 |
| U-018 | 旧总表缺techPointGet等当前字段，部分总表测试仍失败；`test_config_input_matrix.py`，不得猜默认值。 |
| U-019 | 提交后回滚自身失败可能留下半提交，Store备份也可能被清理；`atomic_batch`与输入矩阵故障观察。 |
| U-020 | incremental导入不复核并发目标/manifest，可能覆盖外部目标修改；Store.save拒绝但validate无最终复核；输入矩阵。 |
| U-023 | 旧 test_charge.gd 的解锁、敌实体和保存夹具及卡片接口未适配当前项目，在 UI 段之前即失败/超时；当前页面回归改走 test_charge_panel/test_local_ui/test_tab_unlocks。证据 test/work/test_charge-av25f3xw/test.log；迁移旧综合测试时不可修改游戏规则迁就断言。 |
| U-024 | test_charge_growth.gd 的“Description accepts para7 using existing compact formatter”仍修改 row.des，但 charge_description 已使用独立 UI 文案绑定；20 项中仅此文案断言失败。隔离副本恢复旧 charge_required 后同样失败，证据 test/work/test_charge_growth-vpewbtvh/baseline-charge.log；不为此恢复旧描述入口或改动正式文案。 |
| U-025 | test_ui_text.gd 的“formula display unchanged 超时空炼铁炉/1、/10、/100”与当前独立UI文案不一致；107项中这3项失败。隔离撤销宝石中心全部本轮改动后仍同样失败；[对照](../../test/work/jewel-text-baseline-result.log)。不在宝石任务修改炉规则或放宽断言。 |

## NEXT

- 配置事务/并发与存档故障需独立任务；规则歧义交策划裁决，不自动修复。
- 跨平台发布、已测性能热点与 U-024 旧文案测试迁移按需求另立任务，不在 Balance Lab 中改动正常规则。
