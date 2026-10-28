# 中央反应堆 Godot 实施检查点（尚未完整交付）

用户已认可中央核心＋四向短接，授权真实实现。规范入口为[游戏设计 README](../../game-design/README.md)，本轮决定见[M3/V3](../../game-design/art/modules/reactor.md)。当前在`/workspace/space_idle`的`implement/reactor-centered-godot`分支实施；未合main。此前`bd38d881`压缩交接中的“宿主未固定”“新素材未编译”等状态已由下列提交和验证取代。

## 当前固定状态（2026-10-28）

| 提交 | 已固定内容 | 验证边界 |
|---|---|---|
| `51e704c8` | 基于装备宿主`94040a18`，在真实main挂载左808×900装备/反应堆切换、右632等比战场；接真实Session的开放、暂停与game_time，以及经济变化通知。 | Godot4.7.2入口编译、native真Session启动和Xorg:99整屏已检查；正常新局反应堆未开放，整屏截图不算反应堆验收。 |
| `6f45bed5` | 反应堆Control、四向装配层、独立工作shader、新透明支座与导入设置；四滑杆、均分、整组预览/确认、还原和购级绑定。 | Godot编译和受控夹具装配渲染通过；夹具不证明真实领域数据、自然开放、最终接头质量或动态性能。 |
| `4c26b2e4` | 共享左模块注册点改为`_register_left_module(layer,id,title,scene,unlock_kind,unlock_target)`；按现行开放配置，反应堆使用`feature:reactor`，星球首入口使用`planet:1`。 | Godot4.7.2入口编译与`git diff --check`通过；星球页面由其所属任务独立提供。 |

三提交均已推送至`origin/implement/reactor-centered-godot`。本组修改了`src/main.gd`的最小挂载，未重写装备Control、玩法后端计算或native源码。新资产原件为`/workspace/generated_images/exec-eb6483c5-434b-49b2-8739-96feb6601fc6.png`，已按原图复制为`assets/ui/reactor/centered-v1/supports.png`。导入产生的大量其他未追踪`.import/.uid`未整批入Git。

## 接口依赖与验收边界

固定`09af963c`已有`allocation_plan_preview`和`apply_allocation_plan`，但Reactor实现仍缺少本Control需要的只读`presentation_model(inputs)`及`presentation_changed`。接口草案提交`3d14ded8`待审、尚非实现；该对象当前在本工作区及已抓取的origin引用中不可取，草案字段待其可读取后核对。前端缺出口时显示“供能状态暂不可用”，不读取`_state/_parameters/_factors`、不解析Amount，也不伪造游戏数据。

本Control通过`bind_presentation(reader, context)`接只读展示与`{game_time,paused}`。当前消费者需要等级、容量/剩余、购级报价、开放设备ID及手动占比/数量、免费量、有效量、最终增益和实际有效负载；字段名可在最小宿主适配。整组确认提交预览中的全套canonical金额目标；均分确认调用一次`distribute`。普通拒绝应零写入、保留完整草稿；开放集合变化使旧预览失效。所有者提供有限显示比例，前端不重做均分Amount计算。

反应堆在真实游戏中的四设备全开/凝聚隐藏、零负载与免费量、成功/拒绝、购级、暂停/隐藏/重开，及各局部动态性能，均**尚未验收**。用户标注的[上方接头原图](../../ui-redesign-plan/reactor-image-design/references/user-marked-upper-connections.png)已实际查看；四路实体连接、轴向插入、遮挡与流光共用端口仍须在同版真实游戏正常画面、暂停画面及上两路近景中核对，不能仅凭线碰到边或夹具可见判通过。

已有[旧夹具截图](evidence/visual-fixture-only.png)、[驱动记录](evidence/visual-fixture-driver.gd.txt)和[局部计数日志](evidence/visual-fixture-motion.txt)仅证明当时受控数据下的渲染和暂停/隐藏更新计数；根线程明确不将它们或像素变化当作最终动态品质证据。新支座夹具图暂留`/tmp/space-idle-native472/reactor-scene-fixture.png`，同样只用于装配检查。真实宿主装备/战场整屏截图暂留`/tmp/space-idle-native472/reactor-new-host-screen2.png`。

## 本执行环境

环境依照装备组[固定记录](https://github.com/rlmclmc2-boop/space_idle/blob/94040a18/space-battleship/docs/verification/equipment-hangar-godot/environment.md)重建：Godot4.7.2位于`/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64`，native清单位于`/tmp/space-idle-native472/space_native.gdextension`，Xorg:99为1440×900/Mesa llvmpipe。Godot程序SHA256为`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`，API SHA256为`d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`，本地native库SHA256为`a96c00d424b0aee223abc349b8f1c10c767b535e5b5f324974275a94ada4c24d`。本地导入日志`/tmp/space-idle-native472/reactor-host-import.log`记录1114资源导入，已正常退出；无需重复导入。XDG工具目录在`/tmp/space-idle-runtime472/`，主场景使用独立`settings-reactor-main.json`，未使用用户存档。工具、生成配置、缓存和临时存档不入Git。
