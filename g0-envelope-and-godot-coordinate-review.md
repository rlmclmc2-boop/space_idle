# G0：战场装配包络与Godot坐标边界核对

日期：2026-10-27（UTC）。源码基线：`main@317548d73deab55ba75dfa92d4cc2feadb86781e`。本轮按1440×900普通窗口客户区、1280×800紧凑样本、1600×900宽域样本推进；三者均指物理客户区，不含边框/标题栏，不构成支持范围承诺。

承接[执行机显示快照99b35d3d](https://github.com/rlmclmc2-boop/space_idle/blob/99b35d3dc5448b66e5238590c7e79d585ea0363f/layout-display-input-baseline.md)及[G0建议4a388d81](https://github.com/rlmclmc2-boop/space_idle/blob/4a388d81ddca456b501b9ca9779ed5f02c3624d9/g0-window-display-adaptation-advice.md)。没有启动Godot、游戏或测试，没有移动窗口、修改业务/运行代码/配置。本报告新增静态复算数据和依据；不关闭G9、不批准逻辑几何重做。

## 1. 方法与可确定范围

只读读取当前Excel、舰体/炮台JSON及PNG的alpha>0像素单元外接框。计算结果见同提交的[g0-static-envelope-data.json](g0-static-envelope-data.json)，含输入文件SHA256、五舰结果、16种敌模型边界和逐编队结果；未发布新的generated配置。坐标单位都是逻辑战场单位，不是窗口像素。

- 我舰按 `H=static_height×1.7×playerVisualScale` 和 `D=PNG尺寸×H/alpha框高度` 复算，并保留PNG画布中心相对alpha框的偏移。
- 每种炮台取alpha框四角到真实anchor的最大半径，按 `H/model_span×weapon_scale×visual_scale/pixels_per_model` 缩放。对各真实挂点加该半径圆，再与舰体框取并集。此为所有方向的**保守上界**，覆盖现行朝向的超集，不是逐合法朝向精确扫掠。当前姿态消费链没有按元数据rotation_limit裁剪角度；不能据那个字段缩小安全边界。
- 敌舰按当前±4°扰动和对应display_size适配。取 `F≤min(Aw/(w*cos4°), Ah/(h*cos4°))`，舰体偏心量另加 `(|cx|+|cy|sin4°)F` / `(|cy|+|cx|sin4°)F`。普通/分级炮台均以保守挂点范围加全向半径，覆盖所有挂点与四类普通炮台，另覆盖ranked旋转炮台；因此可能包含该编队没有装备的组合。
- 数据覆盖monGroup表全部2330组，以及异空间40组；其中可能包含当前关卡不引用的主线组，不能把全表上界说成某条可达流程的实际最坏画面。编队身份按现行combat_tier/leader/archetype及legacy映射选择，不按size或终波位置猜阶级。
- PNG框复算是对现有资产的静态界限；实际Godot的BitMap轮廓/凸包及浮点输出仍是运行消费权威。框并集不等于可见面积；保守框相交不证明真实轮廓相交，越界也不直接证明真实裁切。

公式来源：[mount_inputs](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/battle.gd#L142-L146)、[共享舰体/编队几何](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/scripts/ship_geometry_convention.gd)、[炮台投影](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/scripts/approved_weapon_art.gd)、[敌炮台分支](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/battle.gd#L465-L489)。

## 2. 当前572×960内可以静态确定的边界

玩家锚点为(286,520)。下表只含当前可绘制舰体与炮台的保守框，**不含现行敌HP数字/伤害飘字，也不含尚未完整装配的盾外缘、双条、无人机机体或飞行动效**。

| 舰型 | 配置武器/防御槽 | 舰体＋炮台保守框[xmin,ymin,xmax,ymax] | 对世界边界余量：左/上/右/下 |
| --- | --- | --- | --- |
| Frigate | 1/1 | [236.938,453.479,335.062,586.521] | 236.938 / 453.479 / 236.938 / 373.479 |
| Destroyer | 2/1 | [218.711,444.265,353.289,595.735] | 218.711 / 444.265 / 218.711 / 364.265 |
| Cruiser | 3/2 | [186.367,398.947,386.041,626.896] | 186.367 / 398.947 / 185.959 / 333.104 |
| Battleship | 4/2 | [171.720,393.565,402.932,641.108] | 171.720 / 393.565 / 169.068 / 318.892 |
| Heavy_Battleship | 5/3 | [147.848,374.106,423.676,665.894] | 147.848 / 374.106 / 148.324 / 294.106 |

可确定：这部分我方静态装配的保守框在现行世界边界内；Heavy_Battleship的该框约275.828×291.788，而非仅舰体247.996×291.788。不能将表内“对世界余量”当成对敌舰、面板或HUD的净空。

| 敌阵范围 | 成员/锚点事实 | 全表舰体保守并集 | 全表舰体＋炮台保守并集 |
| --- | --- | --- | --- |
| 主线2330组 | 最多15；x=58…514，y=110…350。15艘时每排5艘，x=[58,172,286,400,514]，三排y=[110,270,350]。 | [12.670,32.482,559.330,389.738] | [1.710,-5.032,569.161,389.936] |
| 异空间40组 | 最多8；显式锚点x=106…466，y=115…350。不能拿主线自动编队公式替代。 | [60.670,75.276,511.330,389.738] | [60.670,46.161,511.330,389.936] |

这些并集的四边可能来自不同组，不是一张真实画面。主线保守顶边由组1010触及-5.032；左边组1011、右边组66，底边组1002。异空间顶边组7022、底边组7032，左右组7005。保守框不能证实这些组已实际裁切；这些是优先精化/取证的见证组号。

主线相邻排y间距160和80，同排15艘时锚点间距114；排列实现按成员数量分排、按size/id排序，**未以2×2/3×2占位打包，也不读取display_span来重排**。这与[M1完整占位要求](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/docs/game-design/art/modules/battle.md)尚有实现/验收距离；本报告不授权修改阵型。异空间来自[prepare_wave的显式坐标](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/hyperspace.gd#L876-L934)。

敌阵保守底边389.936与最大我舰保守顶边374.106的纵向区间有15.830重合；这只表示不能从总框推出正净空，不等于同一组中的真实舰体已重叠。必须按具体组、左右位置、真实轮廓和朝向精化，不能把所有画面统一缩小当作消除逻辑重叠的方法。统一外层缩放不改变相对重叠关系。

## 3. 无人机、护盾与已有G9证据的精确缺口

| 项目 | 当前事实/已有证据 | 缺什么；影响哪个阶段 |
| --- | --- | --- |
| 无人机容量与战斗贡献 | 五舰容量1/2/3/4/5；Battle将贡献截到容量，武器ID为drone:id，初始muzzle=(286,520)。[同步几何时无人机只写炮口并continue](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/battle.gd#L420-L432)，不建立其独立绘制姿态。 | 当前没有独立无人机机体/编队包络。不能以“没有绘制”宣布零占用通过；前端须先明确当前渲染接法、视觉锚点、最大五架的展示/动效留白。若移动真实发射点则涉及共享几何，须另审。阻断完整无人机空间定稿与V1通过，不阻断先做外层坐标适配。 |
| 护盾外缘与顶部双条 | BattleView目前绘制舰体、炮台、敌HP数字和伤害数字；BattleHUD显示玩家盾甲。旧enemy_protection_geometry等辅助脚本存在，当前BattleView没有调用它们绘制完整盾外缘/顶部双条。 | 现行装配没有满足M1要求的完整可见组成；必须明确盾外缘形状/间距与双条位置/字号，再形成完整占位。不能把未接线辅助脚本当成当前表现。阻断完整包络冻结及V1通过。 |
| 现行文字覆盖 | Battle.draw_enemy_overlays中敌HP绘制起点为`(actor.x-40, actor.y+max(46,hull_height/2+16))`，字号14、width参数80；BattleView飘字最多48条、寿命0.8秒，按receipt.position叠加上浮，字号16、width参数110。 | 位置/参数可静态确定，字体实际字形框、不同数值文本、动态叠加和面板遮挡净空尚未测量；width参数不是已验收文字占位。将它们显式并入后续覆盖层/净空取证，不能把上表舰体炮台框当完整当前画面框。阻断完整文字遮挡与V1通过。 |
| 炮台/碰撞专项 | [历史资产证据](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/docs/game-design/history/stage6-assets.md)记录五舰共享几何、真实脉冲炮口、敌炮出生与可见舰体接触专项通过。 | 不覆盖全部装配/朝向、盾外缘、双条、最密编队、HUD遮罩净空；不能据专项通过关闭G9。 |
| 最大负载专项 | [历史性能记录](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/docs/game-design/history/stage6-performance.md)为5武器/3防御/4无人机/15敌；源码探针可按当前容量构造，但本轮没有执行。 | 不构成当前5无人机完整画面或性能通过证据，也不提供逐帧包络净空。不能把有探针源码说成新结果。 |
| G9/V1整体 | [open-items G9](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/docs/game-design/art/open-items.md)与[现行验收范围](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/docs/game-design/11-stage6-contract.md)明确仍开放。 | 缺五舰同口径可见面积/层级，完整合法装配扫掠、各阶敌阵及最密合法阵的最小净空，带具体舰型/装备/朝向/编队、边界和HUD/导航遮罩的实机证据；三个物理客户区样本下的完整显示及输入亦未验证。阻断完整画面验收，不把设计尚未完备判为方向不可行。 |

另须区分“飞行特效占用”与舰体占位：当前弹体退休边界为x=-32…604、y=-32…776，而非整个572×960；这些是既有运行规则，不能为UI填空调整。布局裁剪、尾迹和接触效果是否可见需单列取证，不能从静态装配表推断。

## 4. Godot 4.7/4.7.2语义：避免二次缩放

项目启动脚本要求Godot4.7.2；以下核对官方4.7文档和`4.7.2-stable`源码，属于API/源码依据，不是本机运行验证。尚未测量其他DPI或运行时override配置；结论条件必须随候选记录。

| 层 | 已核实语义与实际边界 |
| --- | --- |
| 物理窗口 | Window.size是实际像素尺寸；DisplayServer.window_get_size是不含系统边框的客户区，with_decorations才含外框。Windows后端设置窗口时会加回现有装饰差额。因此1440×900等应作为客户区尺寸，不另乘Windows缩放来“补成”目标物理客户区。[Window](https://docs.godotengine.org/en/4.7/classes/class_window.html#class-window-property-size)、[DisplayServer](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html#class-displayserver-method-window-get-size)、[4.7.2 Windows源码](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/windows/display_server_windows.cpp#L2321-L2365)。 |
| 虚拟画布/内容比例 | content_scale_size是虚拟基准，不设置物理窗口；canvas_items按目标分辨率渲染2D，content_scale_factor还会追加内容倍率。项目未显式设置aspect/scale，项目设置默认keep/1；新建项目模板的expand与Window节点自身默认枚举值不能代替现行项目设置。[ProjectSettings](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-display-window-stretch-aspect)、[Window内容基准](https://docs.godotengine.org/en/4.7/classes/class_window.html#class-window-property-content-scale-size)、[Window源码](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/window.cpp#L1222-L1339)。 |
| 默认设置下的窄内容带 | 若只改物理客户区，仍保留主线572×960、canvas_items、keep、scale=1且无override，按4.7.2取整规则，1440×900和1600×900仅约536×900内容带，左右边距分别约452/532；1280×800约476×800，左右约402。它们是条件静态推导，不是实测。引擎keep黑边不是可供正常场景绘制的空白画布；要做整屏框架，必须显式决定根画布/expand策略，再把572×960仅用于内部战场，不能仅放大物理窗口。 |
| DPI | 当前机器两屏100%只是快照。默认allow_hidpi=true；4.7.2 Windows后端调用系统DPI-aware路径，并不能据此宣布跨屏每显示器DPI适配已验证。4.7方法说明中screen_get_scale在Windows无支持承诺（其他平台返回1），dpi_changed信号也未列Windows；不能把Windows返回1当成100%可靠测量，或只接此信号就声称完成跨DPI适配。更不能以screen_get_dpi/96再乘进已完成的输入映射。[HiDPI说明](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html#hidpi-support)、[screen_get_scale](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html#class-displayserver-method-screen-get-scale)、[dpi_changed](https://docs.godotengine.org/en/4.7/classes/class_window.html#class-window-signal-dpi-changed)、[Windows初始化源码](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/windows/display_server_windows.cpp#L7375-L7377)。 |
| 输入到viewport | 普通窗口输入进入节点时已有引擎的viewport坐标转换；Viewport::_make_input_local对final transform取逆，final transform含stretch和global_canvas。Node._unhandled_input的event.position属于该Node所在viewport，不是桌面物理鼠标位置；Control._gui_input的position已是控件局部坐标。不在业务层重建窗口边距/拉伸转换。[鼠标API](https://docs.godotengine.org/en/4.7/classes/class_inputeventmouse.html#class-inputeventmouse-property-position)、[Window→Viewport链](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/window.cpp#L1873-L1896)、[Viewport逆变换](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/viewport.cpp#L1361-L1373)。 |
| viewport到战场局部 | 对同viewport中的EconomyView，应使用其make_input_local(event)或make_canvas_position_local(event.position)，也可用匹配get_global_transform_with_canvas的逆矩阵；选择一次转换即可。这一步补的是画布/节点局部变换，不再除以物理窗口/虚拟画布比或DPI。若在_gui_input已拿到该控件局部坐标，则按控件到战场的关系转换，不能当viewport事件重算。[CanvasItem API](https://docs.godotengine.org/en/4.7/classes/class_canvasitem.html#class-canvasitem-method-make-input-local)、[实际实现](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/canvas_item.cpp#L1249-L1262)。 |

## 5. 供前端落实的最小边界（建议）

1. 三个样本先记录实际客户区P、根虚拟可见范围U和完整root变换S；不能把P当U写布局，再让引擎缩一次。根内容策略与内部战场适配分开：世界W=572×960，经同一个前端局部变换T进入U，最后由引擎S进入P。布局区R必须在U中定义。若R最初按P预算，先经匹配S逆变换到U；比例不要混用。
2. 共享战场父CanvasItem持有T，BattleView/原生canvas子层和EconomyView跟随；HUD/导航用U布局。事件在引擎转换后已位于viewport坐标，拾取只做匹配的画布/节点局部转换，并筛掉区域外/面板已消费的点击。保持collect_at的世界半径18；视觉缩放后的物理点击半径随S×T变化，不静默改业务半径。
3. 若采用1440×900虚拟界面基准并使用expand/scale=1，1280×800对应约0.888889根内容比例、虚拟范围1440×900；1600×900对应根比例1并扩展横向虚拟范围1600×900。该例只说明消费链，不冻结布局。改变根content_scale_size不会要求改变Battle.view_size或内核战场尺寸；Main当前89/154两处将根基准绑回Battle.view_size，未来前端接入须同时处理初始化和会话重建，避免加载/新会话回退到旧根比例。
4. 精确前端区域与遮罩一旦确定，把上表世界框经同一个S×T投影来检查预算；不按三种物理客户区分别制造三份战场几何。当前不能仅凭所有东西“缩得进去”冻结G9所需的完整装配占位。保持单一damage receipt消费者、后台Session推进、真实炮口与命中几何。

可直接推进的是根画布与局部显示/输入边界设计。完整盾外缘/双条/无人机装配、合法朝向精化、具体编队净空与三样本实机验收仍待证；真实逻辑重叠若被证实，应另提几何/布局问题供审，不能借纯前端适配授权改后端。未知DPI行为列为待验证风险，不冒称已发现输入错位缺陷。

## 6. 追加：可达敌阵的占位归属及三项装配边界

**占位判断：是现行M1空间设计尚未落实的缺口，涉及共享逻辑几何的处理归属；不是仅修旧措辞，也尚无证据表明两份同时有效的玩法规则互相矛盾。** M1仍要求精英2×2/首领居中3×2且包含完整装配；格的实际尺寸、间距与最大预算尚待定。`display_span`虽存在于资产元数据，当前算法不消费它来排位，不能把它当成已执行的领域占位约束。`mon.size`只参与当前排序/视觉兼容映射，不能直接替代阶级占位身份；monGroup旧表头的“10格”亦不能覆盖现行15成员链。

可达性沿当前 `level.xlsx → Campaign._levels/_set_stage/prepare_wave → monGroup → CombatSetup.build_wave → formation_positions` 核实，未使用另一本`level_monGroup_generated.xlsx`的历史路线。220个关卡行引用1970个不同主线组。第2关第6点的**33011**确实有14艇加锚舰：锚舰271019（slot14、anchor、elite，资产display_span=[2,2]）排在(286,110)，同排四艇位于x=58/172/400/514，后两排y=270/350。没有为锚舰跨列/跨排预留位置。同排中心间隔114，按第1节保守舰体半宽100.887与45.330得框间隔下界约-32.217；整组炮台保守顶边-5.032。**这些可达样本使“正净空尚未证明”有具体依据，但仍不证明真实轮廓相交/裁切。** 原第2节1010等全表极值见证未由现行关卡引用；不能拿它们作可达失败证据，33011是相应可达取证入口。

首领另核：异空间beta路线的boss首组**7036**直接配置首领(286,190)、护航(166,350)/(406,350)；ultimate首组**7037**首领(286,210)、护航位置相同，二者确被路线编排引用。首领已居中，不能泛称“所有首领排错”；3×2完整留白与净空则没有自动打包/校验保证。不得为了套主线5×3排列覆盖这些显式坐标。

最小归属：前端可先规定显示区域、遮罩和完整装配留白；**不能仅把某艘敌舰贴图挪开**。actor位置进入内核目标点、轮廓、炮口和飞行计算，重排会改变射程/路径/接触时机。若精化后需改变队形，先给具体可达组、阶级占位映射、格单位和净空方案，再由领域配置/共享Geometry生成唯一位置，Battle同时供计算与绘制消费；这是另审的几何/配置变更，不是本轮纯UI补丁。保持当前位置时，前端仍须报告该空间约束未落实，不能靠缩小整场或删掉M1条款放行。

| 未接线项 | 可由前端补装配的部分 | 确需最小接口/共享链补充的部分 |
| --- | --- | --- |
| 无人机 | `Hyperspace.equipped_ids/warehouse`已有装备身份、品质/武器等事实，可用于资产选择、最大五架的前端留白、预览及展示局部状态；无需把美术参数写入Hyperspace业务规则。 | 现行真实无人机发射点集中在母舰(286,520)。若要独立机体且真炮口一致，缺按drone:id/generation关联的装配锚点/端口事实及Battle共享几何接线；不能画出独立炮口却保留中心出生并称一致。先定前端资产锚点/发射口契约，再以既有geometry/muzzle链承接，改真实出生点须另审；不是增加一个纯UI查询即可完成。 |
| 护盾外缘 | 轮廓形状、偏移、材质、动画、包住舰体/炮台的展示包络归前端；只作视觉外缘不应更改碰撞或减伤规则。玩家启用/强度可消费现有hud_values盾量与比例。 | 敌舰当前enemy_views的缓存view未输出实时shield、max_shield/max_hp；Battle.enemy_intelligence的shield缺省0不能冒充真实盾状态。需由Battle暴露最小只读展示事实（稳定uid、锚点/轮廓或绘制入口、存活与真实盾状态），不能让前端读取私有kernel或从贴图/事件倒推。 |
| 盾甲双条 | 位置/宽高/间距/颜色/文字和随世界锚点投影归前端。玩家当前值/上限/比例已有hud_values，不需新规则或第二份账本；单条归零不能自行标死。 | 敌双条需当前/上限或由Amount安全计算的比例；核心Actor已有hp/max_hp/shield/max_shield，现有公开敌视图仅维护hp/dead等，缺完整显示出口。最小补充是核心→Battle的只读显示字段与实际变化失效，再由Battle提供展示/绘制端口；沿现有actor变化集合更新盾受击/恢复，不建全模块广播、不在读取时推进战斗、不使用全存档快照补UI。 |

接口依据：[Campaign现行读取链](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/campaign.gd#L114-L123)、[编队几何进入actor/武器](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/combat_setup.gd#L89-L201)、[核心Actor安装/视图字段](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/addons/native_battle/src/combat_execution_kernel.h#L1984-L2022)、[enemy_views只读缓存](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/addons/native_battle/src/combat_execution_kernel.h#L2834-L2845)、[Battle.enemy_intelligence](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/battle.gd#L500-L508)。本追加只作现有消费链判断，未实现接口、未改变阵型或启动测试。
