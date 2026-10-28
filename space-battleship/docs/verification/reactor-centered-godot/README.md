# 中央反应堆 Godot 实施检查点（尚未完整交付）

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
| `3d763099` | 定向接入已审核的所有者展示出口`26832431`，不引入其分支其他变更。 | 字段和信号已由真实Session流程核对；自然游戏开放仍待验收。 |
| `65ab683e` | 同值整组确认后从已持有的当前快照退出草稿显示态，避免依赖净变化通知；优化大数显示与购级标签。 | 真实同值确认显示和模型读取计数已核；不增加领域全读。 |

上述提交均已推送至`origin/implement/reactor-centered-godot`。本组修改了`src/main.gd`的最小挂载，未重写装备Control、玩法后端计算或native源码。新资产原件为`/workspace/generated_images/exec-eb6483c5-434b-49b2-8739-96feb6601fc6.png`，已按原图复制为`assets/ui/reactor/centered-v1/supports.png`。导入产生的大量其他未追踪`.import/.uid`未整批入Git。

## 接口依赖与验收边界

固定`09af963c`已有`allocation_plan_preview`和`apply_allocation_plan`。其后已将审核通过的所有者实现`26832431`定向引入本分支（本分支提交`3d763099`）：Reactor提供只读`presentation_model()`、`purchase_preview(can_pay)`及局部`presentation_changed`，Economy提供`budget_changed`。前端缺出口时显示“供能状态暂不可用”，不读取`_state/_parameters/_factors`、不解析Amount，也不伪造游戏数据。

本Control通过`bind_presentation(reader, context)`接只读展示与`{game_time,paused,running}`，另通过`bind_purchase_quote(reader)`只读+1报价。消费者需要等级、容量/剩余、购级报价、开放设备ID及手动占比/数量、免费量、有效量、最终增益和实际有效负载；已按方案分开场景与报价失效。整组确认提交预览中的全套canonical金额目标；均分确认调用一次`distribute`。普通拒绝应零写入、保留完整草稿；开放集合变化使旧预览失效。所有者提供有限显示比例，前端不重做均分Amount计算。

已在Godot4.7.2、Xorg:99和真实native Session的同一进程中运行[真实流程驱动](evidence/live-flow-driver.gd.txt)，输出[日志](evidence/live-flow-r8.log.txt)及[整屏截图组](evidence/reactor-flow-four-active-t0.png)。该驱动通过公开Campaign存取与Reactor刷新临时授予`feature:reactor`和`reactor_module:condensation`，并通过公开经济API注入购级预算；这明确**不是自然进度开放或自然收入的证据**。真实Session的领域展示出口、整组预览/接纳和拒绝均为实际调用，截图未使用夹具模型。正常新局的自然开放、非零免费量仍待实测。

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
