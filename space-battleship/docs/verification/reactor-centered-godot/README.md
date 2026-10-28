# 中央反应堆 Godot 实施检查点（尚未完整交付）

用户已认可中央核心＋四向短接，授权真实实现；入口仍为[游戏设计README](../../game-design/README.md)，本轮决定已更新[M3](../../game-design/art/modules/reactor.md)。执行上下文已实际压缩，按约停止并交替换线程在原工作区续作；未开子任务、未合main。

## 压缩交接：2026-10-28

### 接替后的已验证进度

- 最小共享宿主已单独固定并推送为`51e704c8`（`implement/reactor-centered-godot`）：左808×900的装备/反应炉注册与切换、右632等比战场、真实Session时钟和暂停接入。后续根据现行开放配置，注册点修正为`_register_left_module(layer,id,title,scene,unlock_kind,unlock_target)`，星球首入口使用`planet:1`；仍由同一左侧导航挂载，不改各模块领域。未合main。
- 当前Godot4.7.2入口`--check-only`、`git diff --check`和提交后native真Session headless启动30帧均退出0。Xorg:99真实游戏窗口画面已见左装备、右战场，截图暂留`/tmp/space-idle-native472/reactor-new-host-screen2.png`；正常新局反应炉尚未开放，这张图不证明反应炉运行验收。
- 新支座/实体短接版夹具重新渲染，无脚本或shader错误；四路能看见源端口投影与机械插入，读数调整为手动/免费/有效的区别显示。此图仅用于装配检查，依然不作真实展示、动态性能或最终品质证据。
- 固定只读`presentation_model`及其变化通知仍未接入，真实反应炉开放/四设备/隐藏/成功拒绝/购级/暂停等完整证据仍待它交付。其余WIP和导入缓存均原位保留。

- 工作区`/workspace/space_idle`，当前分支`implement/reactor-centered-godot`，HEAD `bd38d881`：合入固定装备宿主`94040a18`作为依赖；此前自己的已推送检查点为`8b78c8a8`。当前HEAD未推送，以下WIP未提交。
- WIP为`src/main.gd`、`src/ui/reactor_scene.gd`、`src/ui/reactor_stage.gd`、`assets/ui/reactor/centered-v1/working_fields.gdshader`，另新增`supports.png`及`prompt-supports-r1.txt`。保留全部WIP，勿用旧检查点覆盖。
- 已获最小宿主修改授权；main现在挂左808反应堆/装备切换、真实Session开放/暂停/game_time与经济变化失效通知，右战场和装备Control未改。真实展示出口仍待接口组交付，缺失时诚实显示状态不可用，没有私读领域缓存或伪造游戏数据。
- 新支持图原件为`/workspace/generated_images/exec-eb6483c5-434b-49b2-8739-96feb6601fc6.png`，原图未加工复制为supports.png。替代L/U原始线段的是设备自带操纵支座、分段等比实体接头及总控面；端口/流光仍共用投影。新增体积噪声核心shader和按需更新SubViewport补丁已写入，**尚未编译或实图验证**，不能据此声称品质完成。
- 已有夹具图被根线程明确判为装配检查，不能作最终交付。下一步必须先核新shader/Control编译，等待固定展示接口，随后真实游戏截图、四设备/隐藏/操作/暂停动态和上两接口接合验证。不要再凭像素变化判定动态品质。
- 先前导入会话73933已正常退出0；日志`/tmp/space-idle-native472/reactor-host-import.log`显示1114资源导入完成，无需重复启动。导入产生大量未追踪.import/.uid，不应整批加入Git。`git diff --check`通过；尚未验证新宿主运行。
- 前turn failed回调未提供可核实错误原因；本次工具/工作区正常，未发现WIP丢失。旧记录下方的宿主“待授权”状态已被本节取代；展示出口依赖仍成立。

## 已完成及证据范围

- `src/ui/reactor_scene.gd`：独立808×900真实Control，四路滑杆/整组预览确认、还原、均分与购级绑定；无精确数值输入/四块白卡。显示通过只读reader绑定，不读取领域私有缓存，不解析Amount或自算费用/倍率。
- `src/ui/reactor_stage.gd`及`assets/ui/reactor/centered-v1`：分离透明静态主体、四设备可见输入口、源坐标端口投影和独立工作shader。暂停/隐藏控制显式模拟phase，草稿不驱动真实工作负载。
- Godot4.7.2源码check-only通过；同API/Linux native构建完成，原e93主场景headless启动30帧无错误。它证明环境启动，不证明新反应堆已在共享宿主接入。
- [可视化夹具截图](evidence/visual-fixture-only.png)是实际Godot渲染但使用明确的受控显示数据，**不是完整游戏/自然开放/真实领域接口证据**。[临时夹具驱动文本](evidence/visual-fixture-driver.gd.txt)与[日志](evidence/visual-fixture-motion.txt)保留出处。0.6秒两帧差异：core10632、weapons606、defence1369、smelting1087、condensation362像素；暂停field_updates不增加，隐藏后场景计数不增加。这只支持局部shader/显隐时钟实现，不记为动态性能或全流程通过。
- 标记原图已从a8a214a4取回并实际查看。四路实体/流光共享源图端口投影，新的输入口朝内可见；最终正常/暂停/缩放/上两路近景接合仍未通过。

## 待根线程协调的最小接入点

1. **共享宿主**：复用装备组`94040a18`的1440×900/等比右战场，不改该宿主或装备页。挂载`ReactorScene.new(reactor, reactor_inputs, payment, publish_reactor)`于左808×900，统一导航控制显隐/领域开放，`command_finished`接现有结果面；提供只读`{game_time, paused}`，paused含真实暂停/停机。新Control不自己重写main/导航/战场。
2. **固定09af963c缺少实际展示出口**：该提交有`allocation_plan_preview/apply_allocation_plan`，但`presentation_model/presentation_changed`仅在文档候选表出现，实际Reactor脚本不存在；等级/购级只读报价、当前/预览有限显示比例、真实有效负载及变化通知需接口组补齐。此场景通过`bind_presentation(reader, context)`接入，拟消费level/capacity/remaining/load、modules稳定ID/enabled/ratio/effective/free/has_free/factor/load及purchase_quote显示文本/可购买/原因；字段名可在最小宿主适配，不要求领域拥有像素/布局。
3. 预览沿既有接口消费所有者current/target；确认提交已经显示的全套canonical目标，均分确认仅一次distribute。需所有者为equal预览提供有限显示ratio，前端不重做均分Amount计算。普通拒绝保留草稿与实际状态；集合变化旧预览失效。

在只读出口/宿主固定提交到位前，不读取`_state/_parameters/_factors`凑展示，不拼接假的游戏画面，不把夹具称为实际操作验收。完整四设备开放/凝聚隐藏、免费量/零负载、拒绝/成功/购级、暂停/重开及全场景动态性能证据均仍待真实接入后完成。当前属于**待依赖协调的实施检查点**，非最终UI验收候选。

## 本执行环境

已按装备组[environment.md固定来源](https://github.com/rlmclmc2-boop/space_idle/blob/94040a18/space-battleship/docs/verification/equipment-hangar-godot/environment.md)在本机重建；该组/tmp目录在本执行环境原先不存在。Godot官方zip SHA512逐字匹配既有记录，程序SHA256`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`；4.7.2 API SHA256`d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`；godot-cpp固定507ed9d，原生库SHA256`a96c00d424b0aee223abc349b8f1c10c767b535e5b5f324974275a94ada4c24d`，与装备组构建相同。未改native/Windows构建脚本，Linux本地SConstruct复用其链接隔离参数。

路径仍为`/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64`、`/tmp/space-idle-native472/space_native.gdextension`，Xorg:99/1440×900/Mesa llvmpipe。XDG工具目录位于`/tmp/space-idle-runtime472/`；主场景检查用独立`settings-reactor-main.json`，未使用用户存档。生成配置、工具/库、导入缓存和临时存档不入Git。完整构建日志与尚未完成的临时驱动留在/tmp/space-idle-native472，便于本工作区续作。
