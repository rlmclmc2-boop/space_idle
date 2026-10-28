# 中央反应堆 Godot 实施检查点（尚未完整交付）

**当前交付状态：Godot实机视觉不合格，退回打磨。** `59dd464d`原设计仍有效，用户指出的是设计稿与实物品质差距过大，并未要求重新选择设计方向或审批设计稿。`e77b572b`/r16仅作业务、鼠标交互和同源锚点几何的历史验证记录，不是当前可交付画面。保留已验证Reactor/Economy接口和绑定，继续授权反应堆内部真实Godot品质提升。共享外框及导航归整体界面线程。

## 真实Godot内部品质打磨（新候选，待视觉复核）

在不改`src/main.gd`、Reactor/Economy计算或正确同源锚点的范围内，`src/ui/reactor_stage.gd`接入两张新原生无字三/四设备安装图（来源和SHA见[资产记录](../../assets/ui/reactor/centered-v1/README.md)）：空孔变为武器放大器、盾面、炼铁腔与条件开放后的凝聚晶体，中央玻璃球有可见体积；卸掉旧四块厚矩形控制台和底部长壳。`working_fields.gdshader`的核心层只叠运动亮丝，不再以不透明色团遮住玻璃球；零负载时局部内腔压暗。四设备短读数与滑杆转到较浅的深青托架，下沿按容量/已配/剩余、象牙色购级和次级操作分区。侧部是程序绘制的结构纹理，机器本体仍以同一0.6比例投影，没有拉伸补宽。

[三设备零负载整屏](evidence/reactor-quality-r4-three-zero.png)、[三设备已接纳负载](evidence/reactor-quality-r4-three-active.png)、[四设备运行帧A](evidence/reactor-quality-r4-four-active-t0.png)、[帧B](evidence/reactor-quality-r4-four-active-t1.png)由同一Godot4.7.2/Xorg:99/native Session的[驱动](evidence/reactor-quality-r4-driver.gd.txt)和[日志](evidence/reactor-quality-r4.log.txt)固定。夹具仍通过Campaign公开接口临时授予反应堆/凝聚开放，四设备均分确认及购级预算按原驱动执行；不是凝聚自然开放或自然收入证据。日志记录四设备`load>0`、可见35帧局部更新315次、隐藏35帧局部更新0次，场景入口`--check-only`通过。Mesa llvmpipe帧时不证明目标硬件性能。静态原图仍保留识别光，零负载遮罩只使内腔变暗；两侧结构带、局部托架密度、顶端与共享导航的整屏关系仍须根线程/独审及用户核对，**本候选未宣称V3视觉通过**。

## 内部比例修正概念（待审，未接入Godot）

按`59dd464d`认可的材质/光照/对比/排版品质及用户对`r16`的退回意见，先制作[左模块内部概念图](evidence/reactor-interior-concept-r17.png)：原生1189×1323，宽高比对应808×900模块；原件为`/workspace/generated_images/exec-2d4da60e-46d4-4359-bf0b-3e2ca9e288b1.png`，SHA256 `4148d6f808e265e6aecbf2d7cdc1d145a99994294eb144dd04bf815be834cb65`，Git副本未裁切/拼贴/后加字。图中核心有立体涡流，四设备可辨工作体、四短接及四滑杆同屏，底部读数与主控重新分区；设备壳与控制托架仍偏密，滑杆拇指的图示比例、中文字及真实操作净空须复核。它**只是内部比例及局部素材参考，不替代`59dd464d`有效设计，也不是完整整屏、可直接复用的Godot贴图或V3通过证据**；背景与设备等比尺寸不同，不能靠拉伸整张机器图补边。早两次内部生成图仍有厚框/大矩形或越过左侧约808宽的构图问题，未列候选。可继续局部效果核对并直接打磨既有Godot实机，不等待重新确认设计方向。

共享宿主、导航、资源栏、模块边界已移交整体界面线程`01a18207-893a-750e-9898-48786a8c40c7`（源线程`01a1746b-882a-7722-8c55-e9b8be8c2000`），本组仅以Git交接反应堆内部设计。`51e704c8`注册点、`4c26b2e4`的`kind/target`以及`e5cbbb33`的x410/498/586导航位置是现有实现/布局假设，左808×900与右632×900仍待整体界面协调；本轮没有再修改`src/main.gd`。

## 统一锚点视觉修订（整体视觉已退回）

`167c3154`的整屏被退回：1024×1536底板曾非等比拉至808×900，前景设备又独立等比定位，产生两套错位壳和开放圆盖。新候选使用一张完整1024×1536底板承载圆座、四条短主管及同投影的四台空白控制台；三设备版本在同一源图位置封闭右下支路并去掉该控制台。Godot仅用统一`scale=0.6`、`origin=(96.8,20)`布置源图的机械部分；五个工作层、导管流动层及文字/滑杆均由同一源图座标转换。左右剩余97px为深青侧留白。未改变已接入的Reactor/Economy计算和局部失效。`e77b572b`的同源锚点改善了机械接合，但用户已退回整体观感：厚壳、巨框和贴边布局让结构压过核心及设备工作效果，不能据几何改善宣称V3画面通过。

四设备原图`/workspace/generated_images/exec-cfdbee3f-f2ae-44e6-8c51-2f18cf97754a.png`对应`assets/ui/reactor/centered-v1/mounting-plate-r2.png`，SHA256为`4fe7153eb3b0fcc5739d40d6fc3c4f03f3f61c0ca5965fd60ef41e235fcb189d`；三设备原图`exec-7f4487d6-284a-4310-9bfb-b46a145b1cc3.png`对应`mounting-plate-three-r2.png`，SHA256为`95655914c16dfce3d0d6b9e9c150360965475d362aa243a771d32d6be1b489b0`。两张均是原生不透明图，无后处理或游戏文字。[三设备整屏](evidence/reactor-visual-r16-three-active.png)、[四设备运行帧A](evidence/reactor-visual-r16-four-active-t0.png)、[帧B](evidence/reactor-visual-r16-four-active-t1.png)及[真实Session日志](evidence/reactor-visual-r16.log.txt)仅为已退回版本的历史业务/几何证据，不能作为当前视觉交付；开放仍经公开Campaign接口临时授予。

最新控件位置再由[同Session真实鼠标驱动](evidence/reactor-mouse-r16-driver.gd.txt)核对，日志记录拖动2267→0、鼠标确认成功、临时注入预算后购级2→3；[草稿](evidence/reactor-mouse-preview-r16.png)、[确认](evidence/reactor-mouse-applied-r16.png)、[购级](evidence/reactor-mouse-purchased-r16.png)为对应整屏。该鼠标检查不代表全控件或视觉独审通过。

另以独立临时存档、没有开放键注入的[第一关进度驱动](evidence/reactor-natural-stage1-driver.gd.txt)运行真实Godot/native战斗，[日志](evidence/reactor-natural-stage1.log.txt)记录初始`available=false/cleared_stages={}`到真实结算后`available=true/cleared_stages={1:true}`；[反应堆整屏](evidence/reactor-natural-stage1.png)是同一Session的开放页，外观属`167c3154`的r13版本，并非上方`e77b572b`的r16候选。驱动调用`session._step(1/60)`加速推进游戏时间，战斗与结算仍依真实规则；这证明第一关规则开放路径，不代表人工等待的自然时长或r16全零实屏。凝聚第15关自然开放、星球征服后的非零免费量UI、硬件性能仍未通过本候选验证；Mesa llvmpipe帧时不可外推至目标硬件。

非零免费量的领域路径已沿[现有星球重铸探针](../../../foundation/tests/_stage6_reforge_live_probe.gd)的门槛夹具定向核对：[驱动](evidence/reactor-free-after-reforge-driver.gd.txt)用Campaign公开`accept_reforge`先打开第5关门槛，再以真实人员派遣、星球探索/船坞建造及公开`claim_build`完成第一星球重铸准入，调用`Session.prepare_reforge("1")`得到征服后的候选Session。[日志](evidence/reactor-free-after-reforge.log.txt)记录`reactor_inputs().free_charge`从0.0到0.1，`Reactor.presentation_model()`三设备均`has_free=true`，每台`free=10`、`effective=10`、`load=0.1`。该驱动沿既有探针使用内部时间推进缩短等待，门槛也由夹具设置；它证明合法重铸候选的公开输入/展示出口，不是自然通关至重铸或完整主界面免费量显示证据。

## 视觉修订候选（待根线程与原独审复核）

在`2d6625a3`的真实流程上，已将四方位设备安装到同一舰载承托面：暖白/深青的浅层机壳和埋入式短主管替换纯底漂浮装配。四设备底板原件为`/workspace/generated_images/exec-c067f060-c42f-4f4b-b977-6355e88f2e62.png`，三设备封闭右下支路原件为`exec-c9d19e58-760b-475d-8b69-495f44825858.png`；分别复制为`assets/ui/reactor/centered-v1/mounting-plate.png`和`mounting-plate-three.png`，未后处理原图。两图均1024×1536。前者SHA256为`d5a31243657887cb8d1de9ae08a5c5f1bdc28794d5f3c1191f8f7c6267138228`，后者为`25407fd991c8b7773319cb8f36ee28fd7777cc9f50a96054817abeb7e1b51724`。

同一真实Godot4.7.2/native Session流程的[三设备整屏](evidence/reactor-visual-r13-three-active.png)、[四设备运行帧A](evidence/reactor-visual-r13-four-active-t0.png)、[帧B](evidence/reactor-visual-r13-four-active-t1.png)和[日志](evidence/reactor-visual-r13.log.txt)用于复核安装面、封闭支路、四个插座、控制面和体积核心。局部工作shader随已接纳负载与真实游戏时钟更新；三/四设备截图仍为公开Campaign接口临时开放，不是自然进度证据。这是视觉候选及实屏材料，不在此宣称V3视觉通过。

另以[真实鼠标驱动](evidence/reactor-mouse-driver.gd.txt)向真实主Viewport派发鼠标移动、按下和松开：在[草稿整屏](evidence/reactor-mouse-preview.png)中拖武器滑杆使shares从2267到0且预览可确认；鼠标点击确认后得到[接纳整屏](evidence/reactor-mouse-applied.png)；通过公开经济API临时注入预算后，鼠标点击购级，等级2→3并得到[购级整屏](evidence/reactor-mouse-purchased.png)。[运行日志](evidence/reactor-mouse-run.log.txt)记录这些结果。该预算不是自然收入。鼠标流程只证明这三个控件在本版的命中和业务触发，不能替代其余控件或视觉独审。

用户已认可中央核心＋四向短接，授权真实实现。规范入口为[游戏设计 README](../../game-design/README.md)，本轮决定见[M3/V3](../../game-design/art/modules/reactor.md)。当前在`/workspace/space_idle`的`implement/reactor-centered-godot`分支实施；未合main。此前`bd38d881`压缩交接中的“宿主未固定”“新素材未编译”等状态已由下列提交和验证取代。

## 当前固定状态（2026-10-28）

| 提交 | 已固定内容 | 验证边界 |
|---|---|---|
| `51e704c8` | 基于装备宿主`94040a18`，在真实main挂载左808×900装备/反应堆切换、右632等比战场；接真实Session的开放、暂停与game_time，以及经济变化通知。 | Godot4.7.2入口编译、native真Session启动和Xorg:99整屏已检查；正常新局反应堆未开放，整屏截图不算反应堆验收。 |
| `6f45bed5` | 反应堆Control、四向装配层、独立工作shader、新透明支座与导入设置；四滑杆、均分、整组预览/确认、还原和购级绑定。 | Godot编译和受控夹具装配渲染通过；夹具不证明真实领域数据、自然开放、最终接头质量或动态性能。 |
| `4c26b2e4` | 共享左模块注册点改为`_register_left_module(layer,id,title,scene,unlock_kind,unlock_target)`；按现行开放配置，反应堆使用`feature:reactor`，星球首入口使用`planet:1`。 | Godot4.7.2入口编译与`git diff --check`通过；星球页面由其所属任务独立提供。 |
| `170849dd` | 按`3d14ded8`方案适配消费者：当前模型与购级报价分读、局部变化通知、显式running与paused、未知禁用、被动shares草稿保留已生成canonical金额。 | 当时仅完成受控夹具；下述`3d763099`和真实Session流程已取代该阶段性限制。 |
| `e5cbbb33` | 顶栏唯一模块导航移至x410/498/586，按钮80宽、间距8；末项止于x666。 | 装备副标题布局框止于x404，留6px；现有“舰桥面板”按钮始于x678，留12px。星球页尚未合入本分支，第三按钮只完成坐标净空，未作三页实屏验收。 |
| `3d763099` | 定向接入已审核的所有者展示出口`26832431`，不引入其分支其他变更。 | 字段和信号已由真实Session流程核对；第一关自然开放已由本页新证据补验，第15关凝聚自然开放仍待验收。 |
| `65ab683e` | 同值整组确认后从已持有的当前快照退出草稿显示态，避免依赖净变化通知；优化大数显示与购级标签。 | 真实同值确认显示和模型读取计数已核；不增加领域全读。 |

上述提交均已推送至`origin/implement/reactor-centered-godot`。本组修改了`src/main.gd`的最小挂载，未重写装备Control、玩法后端计算或native源码。新资产原件为`/workspace/generated_images/exec-eb6483c5-434b-49b2-8739-96feb6601fc6.png`，已按原图复制为`assets/ui/reactor/centered-v1/supports.png`。导入产生的大量其他未追踪`.import/.uid`未整批入Git。

**共享宿主移交整体界面线程：** 本组`src/main.gd`当前固定在上述`51e704c8`的左模块挂载、`4c26b2e4`的`_register_left_module(layer,id,title,scene,unlock_kind,unlock_target)`开放接口，以及`e5cbbb33`的导航坐标；没有待交接的`main.gd`或全局规范未提交改动。现行桌面尺寸假设为1440×900，其中左808×900、右战场632×900。导航x410/498/586、各宽80的局部净空曾通过，但旧“舰桥面板”样式与导航不统一，顶部标签压近设备，左右留纯色空带；这些是整体界面线程的待决冲突，不是M3本组继续修改的范围。整体线程可从本分支固定提交读取挂载接口，反应堆内部Control及真实业务绑定仍由本组维护。

## 接口依赖与验收边界

固定`09af963c`已有`allocation_plan_preview`和`apply_allocation_plan`。其后已将审核通过的所有者实现`26832431`定向引入本分支（本分支提交`3d763099`）：Reactor提供只读`presentation_model()`、`purchase_preview(can_pay)`及局部`presentation_changed`，Economy提供`budget_changed`。前端缺出口时显示“供能状态暂不可用”，不读取`_state/_parameters/_factors`、不解析Amount，也不伪造游戏数据。

本Control通过`bind_presentation(reader, context)`接只读展示与`{game_time,paused,running}`，另通过`bind_purchase_quote(reader)`只读+1报价。消费者需要等级、容量/剩余、购级报价、开放设备ID及手动占比/数量、免费量、有效量、最终增益和实际有效负载；已按方案分开场景与报价失效。整组确认提交预览中的全套canonical金额目标；均分确认调用一次`distribute`。普通拒绝应零写入、保留完整草稿；开放集合变化使旧预览失效。所有者提供有限显示比例，前端不重做均分Amount计算。

已在Godot4.7.2、Xorg:99和真实native Session的同一进程中运行[真实流程驱动](evidence/live-flow-driver.gd.txt)，输出[日志](evidence/live-flow-r8.log.txt)及[整屏截图组](evidence/reactor-flow-four-active-t0.png)。该驱动通过公开Campaign存取与Reactor刷新临时授予`feature:reactor`和`reactor_module:condensation`，并通过公开经济API注入购级预算；这组截图**不是自然进度开放或自然收入的证据**。真实Session的领域展示出口、整组预览/接纳和拒绝均为实际调用，截图未使用夹具模型。第一关自然开放已由本页新证据单独验证；第15关凝聚自然开放与非零免费量UI仍待实测。

| 真实流程 | 证据与结果 |
|---|---|
| 初始三设备、零负载、凝聚隐藏 | [三设备整屏](evidence/reactor-flow-three-zero.png)，日志`INITIAL 3 load=0`。 |
| 均分预览、一次整组确认 | [草稿预览](evidence/reactor-flow-equal-preview.png)→[实际三设备负载](evidence/reactor-flow-three-active.png)，接纳后`load=1`。草稿不驱动实体实际负载。 |
| 同值确认无所有者净变化通知 | [同值草稿](evidence/reactor-flow-same-preview.png)→[确认后当前状态](evidence/reactor-flow-same-confirm.png)；模型读取`2→2`，底栏从“草稿分配”恢复为“可调容量”。 |
| 超容量预览拒绝、保留草稿 | [拒绝画面](evidence/reactor-flow-over-capacity.png)，`ReactorPlanOverCapacity`且确认禁用，未对该超容量计划发起提交。所有者零写入断言由其定向测试覆盖。 |
| 预算失效与购级 | [可购画面](evidence/reactor-flow-affordable.png)→[购级后](evidence/reactor-flow-purchased.png)；钱包变化只重取报价`1→2`，模型读取`3→3`，等级`1→2`。 |
| 用户暂停、隐藏、重开 | [暂停画面](evidence/reactor-flow-paused.png)与[重开画面](evidence/reactor-flow-four-reopen.png)；暂停场更新`98→98`而滑杆仍可编辑，隐藏场更新`0/35帧`。 |
| 四设备实际运行 | [四设备开放](evidence/reactor-flow-four-open.png)、[运行帧A](evidence/reactor-flow-four-active-t0.png)、[运行帧B](evidence/reactor-flow-four-active-t1.png)；四个实际`row.load`均大于零，核心与四模块使用各自工作动画。 |

该llvmpipe环境下35个可见帧约1002ms、35个隐藏帧约1016ms；仅可证明隐藏时本Control的场更新计数为零，不据此声称整体帧耗降低或硬件性能通过。用户标注的[上方接头原图](../../ui-redesign-plan/reactor-image-design/references/user-marked-upper-connections.png)已实际查看。真实整屏能看见四路短接和设备插座，装配代码的接合路径、流光端口也共享坐标；上两路轴向插入和遮挡的近景品质仍待明确复核，不能仅凭线碰边、截图像素变化或夹具判最终通过。

已有[旧夹具截图](evidence/visual-fixture-only.png)、[驱动记录](evidence/visual-fixture-driver.gd.txt)和[局部计数日志](evidence/visual-fixture-motion.txt)仅证明当时受控数据下的渲染和暂停/隐藏更新计数；根线程明确不将它们或像素变化当作最终动态品质证据。新支座夹具图暂留`/tmp/space-idle-native472/reactor-scene-fixture.png`，同样只用于装配检查。真实宿主装备/战场整屏截图暂留`/tmp/space-idle-native472/reactor-new-host-screen2.png`。

顶栏改动后另留同一Godot进程、同一真实Session的[正常装备](evidence/nav-e5cbbb33-equipment.png)、[临时开放反应堆](evidence/nav-e5cbbb33-reactor-forced-grant.png)、[切回装备](evidence/nav-e5cbbb33-back-equipment.png)与[再切反应堆](evidence/nav-e5cbbb33-back-reactor.png)整屏截图；[驱动](evidence/nav-e5cbbb33-driver.gd.txt)和[日志](evidence/nav-e5cbbb33-log.txt)记录同一Session实例、真实native战场SubViewport持续`UPDATE_ALWAYS`、572×960且容器可见。反应堆页仅经Campaign公开`save_state/restore_state`临时授予开放键，未接展示出口，故这组图只核导航/战场连续性，不证明自然开放或反应堆业务。先前一次临时开放截屏出现右战场黑区；同Session分阶段复核及直接冷切/回切未复现，右战场各帧均可见。可确定黑区不是稳定的宿主切换结果；具体一次性采集/渲染时序原因尚不能从保留证据唯一确定，不将原黑图当通过证据或据此改战斗规则。

## 本执行环境

环境依照装备组[固定记录](https://github.com/rlmclmc2-boop/space_idle/blob/94040a18/space-battleship/docs/verification/equipment-hangar-godot/environment.md)重建：Godot4.7.2位于`/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64`，native清单位于`/tmp/space-idle-native472/space_native.gdextension`，Xorg:99为1440×900/Mesa llvmpipe。Godot程序SHA256为`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`，API SHA256为`d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`，本地native库SHA256为`a96c00d424b0aee223abc349b8f1c10c767b535e5b5f324974275a94ada4c24d`。本地导入日志`/tmp/space-idle-native472/reactor-host-import.log`记录1114资源导入，已正常退出；无需重复导入。XDG工具目录在`/tmp/space-idle-runtime472/`，主场景使用独立`settings-reactor-main.json`，未使用用户存档。工具、生成配置、缓存和临时存档不入Git。
