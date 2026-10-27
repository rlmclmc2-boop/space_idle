# G0：普通窗口与战场显示适配建议

日期：2026-10-27（UTC）。状态：只读建议候选，供完整前端规划定稿选择；没有确定目标窗口、最小支持尺寸、最终布局或视觉通过结论，没有改运行代码或启动测试。

前置依据：[窗口、显示与输入边界快照（99b35d3d）](https://github.com/rlmclmc2-boop/space_idle/blob/99b35d3dc5448b66e5238590c7e79d585ea0363f/layout-display-input-baseline.md)。本报告源码核对基线为 `main@317548d73deab55ba75dfa92d4cc2feadb86781e`；相较前置依据的 `96b1e82a`，仅增加07复查方法，运行代码未变。当前执行机测量不代表目标设备或验收尺寸。

## 1. 已核实事实与推导边界

- 执行机主屏 1920×1080、工作区 1920×1040；副屏 1920×1200、工作区 1920×1160；均100%配置缩放。未测得游戏客户区、外框或每窗口DPI行为，也没有为本报告补开游戏。
- 现行初始视口及整体 `content_scale_size` 基准为572×960；该战场宽高同时进入数值内核，不能直接改成桌面窗口宽高来完成纯显示适配。
- 下表只是按主屏工作区减去候选客户区所得的几何余量，不是已测得的窗口装饰余量，也不保证布局、字号、点击或资产品质通过。普通窗口是否完整落入工作区，仍需日后按实测外框确认。

## 2. 普通窗口客户区候选（建议，待选择）

| 客户区候选 | 在当前主屏工作区的宽/高总余量 | 用途建议与待确认项 |
| --- | --- | --- |
| 1440×900 | 480 / 140 | 可优先比较的普通窗口设计基准；给任务栏、装饰及桌面保留一定预算，需由完整布局证明信息密度可接受。不是冻结的默认窗口。 |
| 1600×900 | 320 / 140 | 同高、更多横向空间的候选；供需要更多并行信息的布局比较，不据此固定左右分屏。 |
| 1280×800 | 640 / 240 | 较紧凑的桌面宽屏候选；只有完整交付能保持可读和可操作后，才可列为支持下界。当前不能承诺支持。 |

表内客户区尺寸按当前100%缩放下的像素预算比较，不含标题栏和边框。1920×1080客户区不能由本机1920×1080显示器推出可行的普通窗口目标。全屏不作为上述候选的前提。

建议将三种比例分开约定：Windows配置缩放、界面内容/字号策略、战场世界到显示区域的变换。100%是本机事实，其他DPI档位是待确定的支持范围；不得把物理分辨率直接当作所有DPI环境可用的界面逻辑尺寸，也不得重复叠乘DPI补偿。

若先保留逻辑战场572×960完整可见，给定界面画布中的战场区域 `R=(x,y,w,h)`，建议使用等比完整容纳：

`s=min(w/572, h/960)`；`o=(x+(w-572*s)/2, y+(h-960*s)/2)`；`p_ui=o+s*p_world`。

仅为预算示例：`s=0.75` 时战场为429×720，`s=0.8`时为457.6×768，`s=0.875`时为500.5×840。它们都不是已通过的战场尺寸；伤害数字、敌方血量、舰体和点击可辨性仍待验证。不要为凑整像素独立缩放X/Y或改变世界几何。

建议第一轮用完整容纳保留战场内容，空余区域由整体构图和背景延展处理；若选择裁切、相机移动或其他可视策略，需明确可见内容与交互边界，单列评审，不能静默裁掉可命中/可拾取区域。这里不决定战场在整屏的位置，也不要求固定模块尺寸。

## 3. 现行消费链：必须覆盖的表现与输入

以下源链接固定到317548d7。表中“适配归属”是建议；现行代码路径是事实。仅核查当前实际使用路径，不把原生头文件中未挂接的辅助方法当作第二套运行表现。

| 路径/内容 | 现行生产与消费事实 | 最小适配归属建议 |
| --- | --- | --- |
| 世界几何、瞄准、炮口、碰撞 | [`Battle::_sync_geometry`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/battle.gd#L407-L458) 从同一舰体/武器姿态生成轮廓、位置与炮口，并提交内核。 | 保持世界坐标；纯显示适配不改该数据、飞行参数、场地边界或配置。 |
| 舰体、敌方血量、武器美术、伤害数字 | [`BattleView::_draw`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/ui/battle_view.gd#L38-L52) 在BattleView的canvas上调用Battle绘制并绘制receipt.position处数字。 | BattleView随统一战场展示父节点变换；敌血量/伤害数字现为世界局部绘制，若以后需固定屏幕字号，必须显式投影锚点后移到前端覆盖层，不能遗漏或重复变换。 |
| 原生retained普通弹、敌弹、尾迹、导弹本体/烟迹/点火等 | [`configure_presentation`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/battle.gd#L186-L207) 绑定BattleView的canvas；[`prepare_retained/draw_retained`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/addons/native_battle/src/combat_retained_presentation.h#L65-L142) 将三角面和MultiMesh写入该canvas，导弹走同canvas的 `flight(f,offset)`。 | 跟随同一父canvas变换，保留原生零拷贝/缓存消费方式。现行offset为零，不再逐项叠加布局offset，避免与父变换重复应用。 |
| 原生光束及连锁段 | [`advance_retained`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/addons/native_battle/src/combat_retained_presentation.h#L29-L35) 提供真实起终点与连锁段，draw_retained通过callback送到[`BattleView::_collect_beams/_upload_beams`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/ui/battle_view.gd#L92-L107)，子MultiMeshInstance2D承载。 | 保持端点为世界坐标，子节点继承战场变换，不能只变舰体或只变beam起点。 |
| 原生发射/命中接触效果 | [`advance_presentation`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/battle.gd#L197-L210) 从事件位置/方向记录效果；[`draw_contacts`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/addons/native_battle/src/combat_presentation.h#L260-L277) 将MultiMesh写入BattleView子contact_layer canvas。 | contact_layer和BattleView处于同一变换树；不得单独重算目标或把逻辑事件位置改成屏幕坐标。 |
| GPU shader局部几何 | [`retained_flights`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/shaders/retained_flights.gdshader)、[`retained_beams`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/shaders/retained_beams.gdshader)、[`gpu_contacts`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/shaders/gpu_contacts.gdshader) 改局部VERTEX；没有skip_vertex_transform、手写屏幕位置或SCREEN_UV取样路径。 | 静态核查支持优先尝试父canvas统一变换；不据此声称所有渲染器、裁剪及缩放视觉已运行通过。 |
| 战场背景、星点、航行/超空间场景 | [`BattleScenery`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/ui/battle_scenery.gd) 从battle.view_size建面；开场采样含960常量；[`starfield.gdshader:45,54`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/scripts/starfield.gdshader#L45-L54) 含572/960及990循环范围。 | 原逻辑场景先随战场父节点；若整体场景需铺满宽屏，由前端独立处理扩展背景区域/采样参数，不能只扩大mesh就视为已完成背景适配，也不改变战斗几何。 |
| 掉落物显示与拾取 | [`EconomyView`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/ui/economy_view.gd#L13-L21) 从drop_markers绘制世界位置，当前直接将event.position传入[`collect_at`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/systems/economy.gd#L157-L162)，逻辑半径18。 | EconomyView与战场同变换；输入端先筛选显示区/有效交互区、避免被面板消费的点击穿透，再从事件所属viewport坐标逆变换到世界坐标。保持逻辑半径18，当前不授权改为固定物理像素命中半径。 |
| 战斗HUD、状态文本、导航与面板 | [`main.gd:154–168`](https://github.com/rlmclmc2-boop/space_idle/blob/317548d73deab55ba75dfa92d4cc2feadb86781e/space-battleship/src/main.gd#L154-L168) 将BattleScenery、BattleView、CampaignView、EconomyView放主根，BattleHUD另在CanvasLayer。CampaignView文字位置固定。 | 状态/导航作为界面坐标布局，不应全部无差别挂入战场缩放；CampaignView的G键操作也不需要坐标投影。HUD继续读事实，不新增receipt消费者。 |

## 4. 最小职责与交换信息（建议）

- **前端壳层/布局装配处**：决定客户区策略、界面画布及战场区域R，建立一个共享的战场展示父节点；计算该节点的等比变换、裁剪与输入有效区域。窗口resize只更新这些前端局部状态；不写入Session/存档/战场配置，不新增全能中间层。
- **BattleView与其原生canvas/子节点**：消费世界坐标的原有表现数据，在同一展示树绘制。保留现有内核绑定、时钟、批次和单一事件消费；UI布局不逐弹查询或复制运动状态。
- **EconomyView输入边界**：把事件viewport坐标转成掉落物绘制所用的世界局部坐标，再调用既有Economy.collect_at。应从event.position所属viewport出发，使用匹配的实际画布/节点逆变换，不能只手算扣除一个边距；引擎已转换的内容拉伸或DPI比例不能再反算一次。若用SubViewport，应明确事件转发及坐标所属viewport，避免先经容器转换又重复反算。优先同viewport变换树，只有实际裁剪/渲染需求才比较SubViewport方案。
- **背景前端与界面覆盖层**：分别处理宽屏构图、背景采样和屏幕字号；若需要投影世界锚点，复用同一个正向变换，不维护第二份映射公式。可用的最小前端信息为逻辑view_size、战场区域R及实际正/逆变换；它们不是新的后端业务接口。
- **Battle、Economy、Session**：继续拥有既有计算、拾取判定和帧推进；此次纯显示适配无需新增后端布局状态或改计算端口。Session.frame不因面板/区域显隐停摆，BattleView仍单独消费damage receipts。可视节点重建须考虑原生canvas RID重新绑定和旧presentation释放，不能让缓存继续引用已销毁的canvas。

## 5. G0需要在规划中明确的选择与后续验证

规划应明确：选用哪个客户区基准、是否支持缩窗及其下界、其他DPI档位范围；战场完整容纳还是另有可见策略；背景覆盖范围；各层变换/裁剪/输入归属，以及面板遮挡下的拾取行为。现阶段不能靠本机工作区或示例倍率替代这些决定。

以上为可行性与接口归属建议，不是新发现的已证实运行缺陷。随后实现与验收需覆盖全部现行表现（含连锁光束、导弹烟迹、接触效果、数字/血量）、同一世界点显示与拾取一致、面板点击不穿透、resize后坐标一致、背景覆盖及文字可读性、战斗推进/事件单一消费、节点重建后canvas绑定。该验证清单仅说明未来证据需求，本轮没有执行或添加测试。
