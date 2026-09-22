# STATUS

## CURRENT

### 启动资源导入

- DONE：日常启动跳过资源导入，资源更新使用现有QA「大重启」。首次启动或缺少脚本类缓存/导入目录时仍自动导入，避免无法进入QA。
- CHANGED：仅修改工作区启动.cmd的导入条件及README操作说明；QA保存、导入与新进程启动链路不变，未操作正式玩家存档。
- VERIFY：隔离test_full_restart.py通过，覆盖忙碌保护、新进程执行更新代码、进度/当前节点/QA设置保留；启动脚本分支与diff检查通过。证据：../../test/work/test_full_restart-kt4_jt3k/test.log。
- NEXT：双击启动.cmd直接进入游戏；新增或替换资源后，在QA点击「大重启」。缓存存在但损坏、或代码无法启动时，需通过Godot编辑器重新导入修复。

### 船员系统

- DONE：六名无固定职务船员，依次通关10、20、25、30、35、40关解锁。第一名解锁前隐藏整个船员页签；开放后正常显示已解锁成员，未解锁部分仅一张通用剪影及下一门槛，不显示姓名/等级/效果/提示详情，全部解锁后收起剪影。
- CHANGED：crew.xlsx保留前三个crewId并新增crew_04～crew_06，unlock.xlsx新增6条type=crew、mode=cleared；crew.unlockId引用门槛，沿现有导入/通关通知/存档。main按至少一名crew.unlocked显示页签，crew_panel复用匿名预告与已有行，crew.badge不泄露锁定旧档成员。新增剪影SVG及crew.unlock_at文案。其他Excel记录、原样式/冻结位置及其他JSON段未改；导出库的非目标格式变化通过仅移植授权单元格到原包消除，未用旧总表覆盖。
- VERIFY：464项通过：解锁专项52、船员56、全装备49、船员UI30、通用解锁245、页签17、船员导入4、解锁导入5、文案6。覆盖到达/通关边界、逐次通知、首人前页签隐藏、只显示下一剪影、全部解锁、禁止锁定分配、旧档等级经验保留、新成员初始化与存档往返、真实UI交互/隐藏恢复/静止零写入。首轮发现详情刷新重复切换选项显隐，修复后原零写入断言通过；旧解锁总数断言按新增6条更新为25。仅引擎既有证书诊断。
- EVIDENCE：../../test/work/crew-unlock-final.log、crew-unlock-core.log、crew-unlock-equipment.log、crew-unlock-crew-ui-final.log、crew-unlock-gates-final.log、crew-unlock-tabs.log、crew-unlock-import.log、crew-unlock-gates-import.log、crew-unlock-text.log。已查看无页签/第一名与下一剪影画面，最新截图在 ../../test/work/test_crew_unlock-c8gz1tp4/space-battleship/.runtime/；Excel对照与预览在 ../../test/work/crew-unlock/。
- NEXT：重启开发版生效，正式玩家存档未操作，未导出EXE。原经验仅API、装备仅预留、每1游戏秒全装备1/10/MAX规则不变；既有批次存档/UI/费用优化及其测量见 [CREW](CREW.md)，本轮未重新测性能。

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

- DONE：按最新要求取消独立「合成/分解」模式，宝石页只保留镶嵌主界面，顶部「一键合成」直接处理背包。保留已有宝石美术及其他任务修改。
- CHANGED：删除模式切换、单颗合成和分解控件/弹窗及其界面回调；一键合成继续调用原combine_all_jewels，不受搜索/仅可镶嵌筛选限制。结果在右栏原地显示，选择模块/孔位/宝石恢复镶嵌详情。合成结果期间隐藏镶嵌操作，避免结果展示和操作目标混淆。合成成本、已装宝石升级、底层分解接口及正式数值/存档未改。
- VERIFY：中心UI64、一键合成49、局部UI79，共192项通过。覆盖真实按钮无需选材料、跨筛选合成、连锁结果、保护/满级/已装宝石保留、重复无材料不扣除、满包替换、焦点/滚动、隐藏恢复、控件复用及零无关写入/重绘。已查看主界面与合成结果实际截图；仅引擎既有证书诊断。
- EVIDENCE：[单页界面](../../test/work/test_jewel_ui-dg8vvhbw/space-battleship/.runtime/jewel-direct-tab.png)、[原地合成结果](../../test/work/test_jewel_ui-dg8vvhbw/space-battleship/.runtime/jewel-center-combine.png)、[UI日志](../../test/work/jewel-simple-test_jewel_ui.gd.log)、[批量合成](../../test/work/jewel-simple-test_jewel_combine_all.gd.log)、[局部刷新](../../test/work/jewel-simple-test_local_ui.gd.log)。既有U-025不在本轮修改范围。
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
