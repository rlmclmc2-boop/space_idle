# 清晰分区公共壳：实机接入候选

基线为已接纳装备的 `main@e3b38d7b6d8256f6031e1b086c7db7812b6a441f`，本候选在 `design/clear-zone-host`。前期分区稿保存在独立概念分支 `design/shared-host-shell@fa28589b`，本分支不继承该分支的运行树。遵从用户后续要求：操作区和战斗区完整收边、字体和公共控件一致，分隔克制；去掉“战斗视窗”字样。右侧预留空间不加入环境或特效，后续由战场组处理。`51cc7c99` 的输入净空曾获限定通过，但用户随后退回整体公共 UI 质感、图标、空隙与贴边问题；该旧结论不覆盖本轮修订。历史 `c77afe04` 两模块组合曾因用户反馈退回；当前 `52c043e9` 已展示公共壳、装备、第一固态星球静态方向，仍非完整整体验收，也未获准合入 main。

本候选按[唯一设计规范第 6 节的每版整屏审核原则](../../../game-design/13-art-interaction.md#6-制作与双审证据口径)复看；局部修正或检查通过不自动成为整体视觉通过。

## 实际接入

- `src/ui/zone_shell.gd` 管公共顶栏、余额/状态详情、侧栏导航及分区边界。顶栏覆盖已验收装备面板顶部原留白，装备内区仍由原面板绘制；战斗内区仍由原 `BattleView` 绘制。右侧 `47.875 px` 只保留纯底色和细收边，没有重绘战场。
- `src/main.gd` 将原有舰船、成长、星图、超空、档案、设置页接到唯一导航，并沿用原开放条件；未开放的页禁用，装备独占弹窗期间禁止切页。保留装备原面板、战斗输入及暂停逻辑，去掉重复的装备顶栏余额和战斗 HUD 钱包。状态详情仍读取原保存状态。
- `src/ui/bridge_theme.gd` 调整原舰桥通用按钮、输入框、面板的字体尺寸、对比、边线、按下/焦点/禁用状态。公共壳制作阶段没有代改模块内部；下述接入只取装备、反应堆各自已审固定候选，未取星球 R14 或旧设计分支的运行树。

原布局审对首版 `730f94ab` 指出舰船选中悬浮时白字压在象牙底，以及顶栏/导航偏小、设置操作等权长条。后续修订覆盖按钮普通、悬浮、按下和选中悬浮组合态的底色与字色；顶栏资源与导航字级提高，资源改用轻分隔；设置公共操作按“存档与速度／偏好／进度管理／导入存档”分组，保留原回调和预览／确认顺序。导航全称在顶栏呈现，不再让原生提示浮层跨入战场。

公共质感使用 `assets/ui/public_shell/` 的可复用矢量资产：深蓝合金操作按钮（普通／悬浮）、象牙陶瓷选中／按下、低饱和禁用、凹入式输入槽、顶轨及资源／保存状态图标。它们经九宫格贴图装在原生 Godot 控件上，文字、金额、焦点和点击仍由原控件驱动；状态提示图标随真实保存告警切换。舰船等既有模块内部控件保持原样式。战斗主体和右侧预留带未加入贴图。

`07d879ae` 原审收口：顶栏标题从 `118 px` 扩为 `148 px`，调整相邻资源起点，改用无下缘多重内线的独立标题铭牌；“舰船与航程”维持 `20 px` 字级且不贴切角。设置页输入槽的普通／焦点／只读材质统一落在真实控件上；`SpinBox` 实际可见输入是内嵌 `SpinBoxLineEdit`，因此同时装配该子控件和上下步进背景／箭头。禁用时原生编辑状态与成组箭头图标一起降权。

`799c33b8` 原审继续指出设置输入槽内横线贴文字下缘。本次只修 `input-well.svg` 及焦点、只读两态：移除九宫格拉伸后进入文字区的内横线，保留切角外轮廓与短角线。已按实机整屏逐项核对路径、倍速、伤害数字和 `60 秒` 的文字下缘与外框净空；未调整文字字号、布局或交互。

本轮退回后的替换与可见结果：非装备页顶轨原来覆盖到 `y=85`，与 `y=65` 起的舰桥页重叠 `20px`，现只在装备页覆盖原留白，其他页收至 `y=65`；舰桥外层旧 `PanelContainer` 框线已替换为单层无框底色及布局内距，设置页原重复卡框已替换为同一页上的轻分隔，空的状态标签不再占据第一行。导航仍在原 `47.875px` 左预留带，原切角按钮样式已替换为有普通／悬浮／选中态的轻量图标槽，图标和中文上下排；顶轨旧重复刻线／金饰已从源 SVG 移除。余额顶栏、资源详情和战场掉落识别均引用同一 [资源身份规范](../../../game-design/13-art-interaction.md#22-全局信息层级与适配)及 `src/ui/resource_visuals.gd`；后者只改变掉落图形，不改变拾取判定。设置输入槽内容边距从 `10` 调到 `15px`，按实机文字轮廓检查贴边。

资源身份交接：公共顶栏与详情由 `zone_shell.gd` 负责；战场掉落识别由 `economy_view.gd` 读取同一图标/颜色，战斗场景与逻辑未改。装备费用由已验收装备组维护，反应堆、科研、星球、超空等各自费用与奖励由对应模块组接入同一资源身份；这些内部行本分支没有代改，当前 main 的旧装备图不能作为其最终效果。资源数值和结算仍以原业务端为准。

公共刷新路径核查：【发现并修复】`main._process → _sync_equipment_entry → _sync_zone_route` 原来每帧把七个导航控件的禁用态／图文色重复赋值；现状态相等时早退，余额文本和页面/挡层可见性也只在实际变化时写入。资源详情原来只在打开瞬间取余额，打开后余额变化会滞留；现与顶栏消费同一 `display_changed` 脏值，只更新预建行的变化文字。【核查未发现】本公共路径的余额、掉落显示更新未新建控件或重建整页。【未覆盖】装备、反应堆、星球等模块内部刷新策略，不从本轮推断其是否存在整刷。

`c4c48282` 后的原审补充指出设置页右半空、舰船页控件贴滚动条、资源详情过宽、掉落识别弱和详情打开后余额可能滞留。现设置页以全宽“存档位置”承接长路径，选择目录与保存进度共用右侧操作列；下方左列组织新游戏／载入／导入，右列组织倍速、自动保存和战斗显示，原控件及回调不复制。舰船页仅在共享滚动容器右侧增加 `18px` 内容净空；资源弹层由约 `470px` 收至 `330px`，四行图文仍在原生弹层中；战场资源标记改用 `28px` 图标及 `15px` 半径资源色圈，原 `18px` 拾取半径保持。根端对 `c4c48282` 装备截图标题的一次误判已在核对原 Git 图后撤回，原图标题确为“装备”，不记为发现过的路由缺陷。

尺寸对应：整屏 `1440×900`，操作/模块区 `x=0…808`；战斗容器 `x=808…1440`；原战斗投影仍从 `x=855.875` 开始，宽 `536.25`、高 `900`、比例 `0.9375`。左侧原空余 `47.875 px` 承载导航，右侧同宽保留给战场后续表现。舰船、设置等原 main 页面展开到 `x=0…808, y=65…900`；未改战斗主体尺度或密度。导航放左侧是本轮为现有 main 页面做的操作归属判断，并非用户对未来模块位置的最终选择。

## 同版实机证据

Godot `4.7.2`，桌面 `1440×900`，正常 main 入口实例。整屏：[装备／已选](evidence/equipment-1440x900.png)、[舰船未选悬浮](evidence/ship-hover-1440x900.png)、[舰船标题及悬浮选中](evidence/ship-1440x900.png)、[设置双列](evidence/settings-1440x900.png)、[SpinBox 焦点](evidence/settings-spin-focus-1440x900.png)、[SpinBox 禁用](evidence/settings-spin-disabled-1440x900.png)、[资源详情](evidence/resource-details-1440x900.png)、[自然战斗中的铁掉落](evidence/drop-identity-1440x900.png)。[连续六帧](evidence/route-motion-00.png) 至 [末帧](evidence/route-motion-05.png) 记录装备→舰船→装备的短切换，均为 Godot 直接截图。按原始尺寸查看了目录与保存按钮同列、双列信息/操作比例、舰船右净空、详情宽度及掉落识别。正常页面和自然掉落无玩法夹具；另以真实 `Economy.credit_yield` 在 `/tmp` 测试数据的运行实例中使时空微粒显示值 `1.14万 → 2.13万`，[同帧整屏](evidence/resource-live-update-1440x900.png) 记录打开的详情与顶栏一致；这只用于受影响状态观察，不改业务规则。

[窄范围检查记录](evidence/checks.json)：15 项通过，包括真实侧栏点击、选中悬浮组合态字底、余额显示、原战斗投影位置与尺度、SpinBox 内嵌材质／焦点／禁用、未开放页拦截、资源弹窗互斥、装备批量弹窗阻止导航。只覆盖本轮受影响的公共壳与入口；不代表自然解锁、完整游戏流程或各模块内部验收。运行日志只有图形 VSync 与音频设备回退告警，未见脚本错误。**当前仍是待审候选，不以这些检查宣称整体质感已获用户认可。**

`59237c7d` 的自然铁掉落初现帧中，青色接触亮形压住铁锭，原审据此退回掉落身份。实际绘制关系是 `BattleView.contact_layer` 位于 `z=2`，`EconomyView` 原为默认 `z=0`，而铁标底盘还有 `0.92` 透明度；后续帧亮形离开才看得清轮廓。本次仅把资源掉落层置于接触亮形之上（`z=3`），底盘改为实色，保留既有铁锭图标、琥珀色圈、28px/15px 尺寸、18px 拾取半径及战斗投影。正常入口自然战斗同版 1440×900 的[初现整屏](evidence/drop-identity-1440x900.png)、[10 帧后](evidence/drop-seq-010.png)和[100 帧后](evidence/drop-seq-100.png)显示初现与持续状态；这些图均为真实铁掉落，不替代其他资源的自然实机覆盖。共享身份 helper 中其余四种资源的映射未改，费用与奖励仍归各模块原组。此次只提交掉落识别修正供原审，先前公共页面限定结论不外推为本轮或整体品质通过。

模块内部的新质感及“数量循环键＋独立购买／升级键”由各模块原组制作和验收；下述接入把装备、反应堆固定候选装到本分支，其他模块仍按原组交接。当前 main 的旧装备截图不能作为模块最终效果。本轮公共 UI 修订仍待原审与用户判断。

## 装备与反应堆固定候选接入

装备源码 `bcad25d0bfc6eb3c603cc53fad1df21f24ac3e53`、原组图证 `3ccb298a`，反应堆源码 `bb212aee0d057b27cc8d5934d8711a24e78c16c0`，均只取各自固定候选。装备精确取 `src/ui/equipment_panel.gd` 及实际引用的两张 `materials-20261029` 贴图／导入设置；本分支 `src/ui/resource_visuals.gd` 与该候选的查询接口相同，继续让公共栏、掉落和装备费用共享资源身份。反应堆取 `src/ui/reactor_scene.gd`、`reactor_stage.gd`、Owner `src/systems/reactor.gd` 的原版快照／报价／分配端口，以及两场景直接引用的 r4/r5/r9 图与 shader；未取源分支 `main.gd`、`game_session.gd`、`economy.gd` 或其他模块源码。

安装端口只改本分支 `main.gd` 和公共 `zone_shell.gd`：反应堆场景作为 `808×900` 左区场景，由现有公共顶栏和导航驱动；绑定 Session 的反应堆输入、Owner 只读 `presentation_model`／`purchase_preview`／`purchase_max_preview`、支付与发布回调，Owner 的呈现变更信号及 Economy 已有的 `display_changed` 失效通知。公共导航增加独立“供能”入口，保留“成长”页的科研／强化；旧 `ReactorPanel` 构造路径及不再引用的 `src/ui/reactor_panel.gd` 已移除，反应堆场景和装备场景互斥显示。装备原自绘顶栏继续经 `set_shared_host(true, null)` 隐藏，只保留公共顶栏；没有叠新底板遮住旧控件。另加 `nav-reactor.svg`，与既有导航同线宽/尺寸。原 1440×900 战斗投影、输入通路和 89dc 铁掉落修正保持。

同版 Godot 4.7.2 正常主场景的[装备整屏](evidence/integration-equipment-1440x900.png)、[反应堆零供能](evidence/integration-reactor-zero-1440x900.png)、[×10 报价](evidence/integration-reactor-x10-1440x900.png)、[均分生效](evidence/integration-reactor-active-1440x900.png)、[切回舰船](evidence/integration-ship-return-1440x900.png)，及短工作帧[起点](evidence/integration-reactor-motion-00.png)、[中点](evidence/integration-reactor-motion-02.png)、[末帧](evidence/integration-reactor-motion-05.png)，均以原尺寸复看公共栏、接缝、导航、内区和战斗空间。[固定驱动](evidence/module-integration-driver.gd.txt)在正常实例中使用 Campaign 公开恢复端口临时开放反应堆与凝聚、Economy 公开入账提供预算；[运行摘要](evidence/module-integration-runtime.txt)确认导航互斥、×10 只改报价且等级不变、均分命令成功、切回舰船。此为接入观察，**不证明自然关卡解锁、自然收入、购买成交、极端值或其他模块的完整动态**；原组对各自固定版本的限定审查不替代本组合的原布局审，也不把受影响检查通过等同整体视觉通过。当前候选仍待原审与用户判断，未获准合 main。

`b5ec2350` 初次提交的 `integration-equipment-1440x900.png` 实际是舰船页：截图驱动读取正常实例后未显式切到装备，沿用了本地持久化的舰船页面偏好。这是取帧错误，未发现对应业务路由缺陷。现用[装备单页实际取帧驱动](evidence/equipment-only-capture.gd.txt)经公共装备导航切页，先断言顶部标题“装备”、装备导航选中、装备场景可见、成长与反应堆场景隐藏，再覆盖上面的装备整屏；图中标题、导航与机库正文一致。[运行摘要](evidence/module-integration-runtime.txt)附这次取帧状态。反应堆 `bb212aee` 的零供能、报价、均分和短工作帧不覆盖升级后的小占比状态，后续修订见下。

### 反应堆购后小占比修订

原组固定源码 `0514a48f7224c1e09d2a26c41c57dc045acce1cc` 只比已接入的 `bb212aee` 改动三文件：`src/ui/reactor_scene.gd` 将正但小于 1% 的 Owner 占比标为 `<1%`，`reactor_stage.gd` 对非零工作负载设置仅视觉用的最小可见强度且零负载仍关闭，`assets/ui/reactor/ship-hub-r9/transport_work.gdshader` 提高输送光路可见度。本分支逐文件原样同步；反应堆 Owner、装备、公共路由／资源身份、战斗投影和输入边界不改。原组 `4a611456` 的六张整屏与 12 帧审查仅覆盖其版本；这里另看当前组合的购后状态。

同一正常主场景、Godot 4.7.2、1440×900 的[×10 购后整屏](evidence/integration-reactor-post-ten-1440x900.png)、[MAX 购后整屏](evidence/integration-reactor-post-max-1440x900.png)和短工作帧[起点](evidence/integration-reactor-post-motion-00.png)、[中点](evidence/integration-reactor-post-motion-03.png)、[末帧](evidence/integration-reactor-post-motion-05.png)均按原始尺寸检查。固定[接入驱动](evidence/reactor-post-purchase-driver.gd.txt)经公开 Campaign 恢复端口临时开放反应堆、公开 Economy 入账 1000 铀，再由当前公共“供能”导航进入，以原生鼠标事件点击循环键和执行键；[运行摘要](evidence/reactor-post-purchase-runtime.txt)显示等级 11／12 时武器真实占比约 0.43%／0.29%，界面均为 `<1%` 且四口仍在工作列表。两次购后图的公共栏、操作区收边、右侧主体投影未见增量错位；短帧只证明本次可见工作变化。临时开放和入账不是自然进度证据，也不外推其他极端状态、模块完整动态或整体美术验收。此为最终共享组合候选，待原布局审复看，不合 main。

## 用户退回后的两模块统一交接

用户看 `c77afe04` 后认可质感提升，但指出装备与反应炉仍不统一、反应炉有文字超框且新控件受旧效果遮挡；**该组合已退回，以上历史“候选／局部通过”不能作为当前整体验收**。共享标准只在[13第 2.3 节](../../../game-design/13-art-interaction.md#23-所有模块共享的状态与反馈)和[14第 1 节](../../../game-design/14-ui-contracts.md#1-版本与使用边界)维护，本页记录当前源码差异与接力范围，不另立一套标准。

| 交接面 | 当前 `c77afe04` 的实际差异／风险 | 后续归属 |
|---|---|---|
| 字体与信息层级 | 两页都用 `assets/fonts/NotoSansSC.ttf` 常规 400／强调 600；装备通用按钮 `16px`、反应炉执行键 `20px`／其他键 `17px`。装备费用在手绘台面和比较区，反应炉费用／数量／执行在底台；字号可按场景微调，但对象、当前值、报价、失败原因、主操作的主次和实际字形净空需一眼对应。 | 装备、反应炉原组各自调整内部字级和文案承载位；整体组只保公共标题／资源／导航。 |
| 材质与控件状态 | 装备用 `materials-20261029/painted-console-shell.png` 和 `satin-metal-tile.png`，`EquipmentSurface`／`_prepare_button_material` 按普通、悬浮、按下、禁用、焦点及自定义选中切换；反应炉 `_button` 用 `ship-hub-r9/console-key.svg` 着色，同样有普通、悬浮、按下、焦点、禁用，但两页尚未形成同一主次材质与字底关系。逐态还须看悬浮按下、选中悬浮、键盘焦点和禁用后的轮廓与字体对比，不能只比 normal。 | 各模块原组在各自真实机库／舱室内做同家族材质与状态，保留场景专属性；共享宿主不覆盖内部 Theme。 |
| 数量／报价／执行组 | 装备工作台当前循环键约 `96×36`、执行键动态约 `292×36`，报价行在其上；反应炉循环键 `82×34`、执行键 `128×34`、均分另占 `90×34`，费用在底台另一行。两页均已有 ×1→×10→MAX 循环和独立执行；当前装备是左数量／右执行、平直灰蓝按钮，反应炉是均分／执行／数量且多道描边嵌槽，阅读顺序与材质重量明显不同。后续共用“报价先读、左数量、右执行”的关系和同家族状态材质，均分独立安放，不把机库和设备舱机械画成同一房间。视觉上报价与按钮的条件／动作关系不等强，长金额、MAX 可购数和失败原因可能超出各自可见承载面。尺寸是当前实现事实，**不是统一目标规格**；原组应按实际描边、切角、凹槽、文字墨迹与点击区重排完整操作组，不简单拉长按钮或加新框。 | 装备／反应炉原组各自处理内部布局与状态；价格、MAX 和支付仍归 Owner，不由宿主重算。 |
| 可见安全区与效果层序 | 装备工作台逻辑框为 `x=16…792,y=610…896`，实际漆面有切角与内缘；反应炉底台读数／报价位于约 `y=769…856`，其中费用明细布局框 `x=508…767`，实际浅色台面和折角的安全边界须从原图量，不可把布局框当文字净空。反应炉 `reactor_stage.gd` 管静态舱室、核心／主管／设备工作层，`reactor_scene.gd` 管局部 `work/pulse`、控件和文字；用户已见旧效果挡新控件，具体交叠源与包络由原组按动态帧定位，移除或裁切旧效果本身，保持控件／文字／焦点在可读层。比例条配色、百分比数字与标签的层级需在真实非零分配整屏上重做判断，原组负责内部修订。当前证据只确认用户问题，不从代码顺序臆定单一根因。 | 反应炉原组修内部文字安全区、旧效果包络和新控件层序；装备原组核工作台切角与操作组；整体组仅核公共顶栏、导航、区域边界。 |

原组后续候选到达后，整体组只按源差异精确接入当前非 main 组合，重新依[13第 6 节](../../../game-design/13-art-interaction.md#6-制作与双审证据口径)看同一新版的完整装备／反应炉整屏及相关动态，报告仍存在的画面问题；不拿 `c77afe04` 的旧检查清单或原组局部结论抵消新问题。星球、战场内部、价格与业务规则仍不在本轮公共接力范围。

## 资源材质图标修订（当前待审）

用户退回顶部铁／铀／时空微粒原线稿，认为轮廓像线条拼接。本轮**替换**公共资源身份的三枚旧 SVG：新 [材质图集](../../../../assets/ui/public_shell/resource-material-atlas.png) 依次为琥珀金属锭、绿核燃料、蓝青时空沙漏；[生成提示](../../../../assets/ui/public_shell/resource-material-atlas-prompt.txt) 和 [源文件记录](../../../../assets/ui/public_shell/resource-material-atlas-source.json) 保留原始图像哈希及三格位置。`resource_visuals.gd` 按可见主体边界一次提取并缓存 24px 透明小图，公共余额 `17px`、详情 `20px`、掉落 `28px` 从同一接口缩放；三枚旧线稿文件已移除，无叠层。色圈仍按原资源色，数值、拾取半径与经济逻辑未改。强化碎片、简并物质的旧图标未更换。

Godot 4.7.2 正常 1440×900 主场景同版实机：[顶部／装备费用整屏](evidence/resource-material-equipment-1440x900.png)、[打开资源详情整屏](evidence/resource-material-details-1440x900.png)、自然铁掉落的[初现整屏](evidence/resource-material-drop-000.png)和[10 帧后整屏](evidence/resource-material-drop-010.png)。[详情取帧驱动](evidence/resource-material-details-driver.gd.txt)和[自然掉落取帧驱动](evidence/resource-material-drop-driver.gd.txt)固定页面断言及掉落事实；自然铁标来自正常战斗，不是伪造掉落。按实际显示尺寸看三种资源在顶部和详情有独立材质与轮廓，铁掉落在原色圈内可辨；没有用放大素材图代替实机判断。自然掉落证据仅覆盖铁，不外推铀／时空微粒的自然掉落状态。

公共 `zone_shell.gd` 的余额／详情及 `economy_view.gd` 的掉落已调用 `icon_modulate` 保留材质原色；装备和反应炉内部虽通过共享 `icon(id)` 得到新图，但其费用行仍有原组自己的 `color(id)` 整幅着色，完整材质显示须由各原组在本身费用／奖励行改用 `icon_modulate(id)`，并以真实小尺寸实机复看。其他模块消费／奖励也归各自所有者。共享契约只在 [13 第 2.2 节](../../../game-design/13-art-interaction.md#22-全局信息层级与适配) 和 [14 第 1 节](../../../game-design/14-ui-contracts.md#1-版本与使用边界) 维护；本段仅记录本次实际接入与未覆盖范围。当前是新候选，须按 13 第 6 节重新整体审图，不能沿用之前公共页面或模块的限定结论。

### 同屏资源家族补齐（当前待审）

原审看 `da018a65` 的正常详情整屏，确认前三枚新材质小尺寸可辨，但强化碎片仍是紫色线框，整体未过。本次从已看过的前三枚图集风格制作 [补充图集](../../../../assets/ui/public_shell/resource-material-supplement.png)：紫色实体晶片与银蓝致密球；[生成提示](../../../../assets/ui/public_shell/resource-material-supplement-prompt.txt) 和 [源文件记录](../../../../assets/ui/public_shell/resource-material-supplement-source.json) 保留来源、哈希与提取边界。`resource_visuals.gd` 将五个已存在的资源 ID 全部映射到同一 24px 缓存提取路径；删除两枚废弃线稿 SVG，不叠新控件，不增资源或改经济事实。唯一视觉契约随之更新在 [13 第 2.2 节](../../../game-design/13-art-interaction.md#22-全局信息层级与适配)，14 第 1 节已有公共接口无需另写一套。

Godot 4.7.2 导入无脚本错误。正常主场景 1440×900 的[四行资源详情整屏](evidence/resource-family-details-1440x900.png)可见紫晶片与前三枚同家族；[五行同版整屏](evidence/resource-family-five-1440x900.png)使用[固定驱动](evidence/resource-family-five-driver.gd.txt)经公开 `Economy.credit_yield` 临时给简并物质入账 `1`，只为显示默认隐藏的第五行，不是自然获得／掉落证据。原[自然铁掉落整屏](evidence/resource-material-drop-000.png)所用前三枚图集及 `economy_view.gd` 绘制路径未变；余额只常驻前三种，不将后两种塞入顶栏。五种详情图标在真实 20px 显示下均有独立轮廓与原色。未取得强化碎片／简并物质自然掉落图，也不外推各模块内部费用、奖励和整体视觉通过。

### 装备工作台结构决定

用户判断工作台重排、按需展开和进一步压缩目前不构成必要的结构级改善，要求先打磨现有界面。相关提案仅存档，**不是当前待执行项**；保留现有工作台结构。已经授权的边界、文字、控件一致性和资源质感修整继续由各自原组在所属内部处理，公共壳不代改装备工作台，也不据此启动新布局实现。

### 装备 243b24a1 固定候选接入（当前待原布局审）

原装备组固定源码 `243b24a1`、其图证 `1354d2bb`。相对本分支只同步 `src/ui/equipment_panel.gd` 三处窄改：工作台 ObjectHeader 的既有面材改沿外壳切角绘制并增高 `36→40px`，现装标题与等级按字形净空下移，费用图标调色从 `ResourceVisuals.color(id)` 改为 `icon_modulate(id)` 以保留新材质图的原色。源码取自装备原组的固定文件版本；**没有**合入其分支的公共壳、旧三资源图集、旧 SVG、文档方案或其他模块。当前五资源共享源 `08e23a1c`、公共导航／顶栏／装备 `set_shared_host` 适配及战斗投影均保留。用户已搁置的工作台重排、按需展开和压缩没有实施。

Godot 4.7.2 正常主场景 [1440×900 装备整屏](evidence/equipment-source243-combined-1440x900.png)经[固定取帧驱动](evidence/equipment-source243-combined-driver.gd.txt)明确切到装备并断言标题、选中导航和场景可见；[运行摘要](evidence/equipment-source243-combined-runtime.txt)记录本地导入缓存恢复和成功状态。原尺寸复看切角内的标题净空、费用铁图标颜色、公共栏／导航／模块边界和右侧原战斗主体，未见这次接入造成的新增覆盖。图仅覆盖当前默认选中装备与普通余额，长标题、所有费用资源、悬浮／焦点及完整工作台操作状态继续受原组 `1354d2bb` 的局部证据边界约束；反应炉内部未随本次同步。仍须按 13 第 6 节由原布局审对**当前组合**重新看完整画面，不将旧 `c77afe04` 或原组局部结论外推为整体通过。

### 反应堆 c3171595 固定候选接入（当前待原布局审）

原反应堆组固定源码 `c317159597bcd4f0a7c3a0bef66a223126421704`；其原组 `ship-hub-r9` 入口下的整图与两段动态已获**内区限定**审查，不替代当前共享组合审。相对本分支已接入的 `0514a48f`，逐文件原样取 `src/ui/reactor_scene.gd`、`src/ui/reactor_stage.gd`、`assets/ui/reactor/ship-hub-r9/device_pulse.gdshader`、`device_work.gdshader`、场景最终直接引用的 `working-bay-eight.png`，并依源删掉已不再引用的 `console-key.svg`。原分支中间图 `working-bay-seven.png` 未被最终运行源码引用，未取；Owner `src/systems/reactor.gd` 未变。没有合入源分支公共壳、装备或旧资源身份文件。`reactor_scene.gd` 的费用图已用本分支五资源 `ResourceVisuals.icon_modulate(id)` 原色接口；当前装备 `348e2321` 的切角及费用修正、宿主安装端口、顶部／导航、战斗投影保持。

Godot 4.7.2 正常主场景 1440×900 [零供能整屏](evidence/reactor-c317-zero-1440x900.png)、[均分生效整屏](evidence/reactor-c317-active-1440x900.png)、[×10 购后](evidence/reactor-c317-post-ten-1440x900.png)、[MAX 购后](evidence/reactor-c317-post-max-1440x900.png)，以及受影响工作态短帧[起点](evidence/reactor-c317-motion-00.png)、[中点](evidence/reactor-c317-motion-03.png)、[末帧](evidence/reactor-c317-motion-05.png)，以[固定驱动](evidence/reactor-c317-driver.gd.txt)和[运行摘要](evidence/reactor-c317-runtime.txt)记录。驱动经公开 Campaign 恢复端口临时开放反应堆、公开 Economy 入账 1000 铀，以原生鼠标事件点击数量／执行键；×10 后等级 11、MAX 后等级 12，非零占比约 0.43%／0.29% 均显示 `<1%`。这些是接入与受影响动态观察，不是自然解锁、自然收入或完整操作矩阵。按 13 第 6 节原尺寸复看上述当前组合整屏与帧，未见本次接入导致的公共顶栏、导航、区域边界或右侧战斗主体增量退化；仍由原布局审判断同版画面。旧 `c77afe04` 已退回，原组内区限定通过不外推为本组合或 main 验收。

### 反应堆 4924205e 等级与失败报价窄修接入（当前待原布局审）

原组固定源码 `4924205e374974e030c3d7083a9fa634543bce19`，相对已接 `c3171595` 的**唯一运行文件差异**是 `src/ui/reactor_scene.gd`：底台等级标签 x `91→112` 避斜边，报价刷新恢复正常字色／字重／宽度，资金不足和无可购数时将失败原因与费用／模式分出可读层级。本分支原样同步该文件；`reactor_stage.gd`、shader／图、Owner、装备、五资源身份、公共壳与输入区域不变。原组内区整图和两段动态的限定认可仅属其源版本，不代替当前组合判断。

Godot 4.7.2 正常主场景同版 `1440×900` 的[零余额失败整屏](evidence/reactor-492-zero-failure-1440x900.png)、[余额可购整屏](evidence/reactor-492-affordable-1440x900.png)、[均分工作整屏](evidence/reactor-492-active-1440x900.png)、[MAX 购后无可购整屏](evidence/reactor-492-post-max-failure-1440x900.png)，由[固定驱动](evidence/reactor-492-driver.gd.txt)经公开 Campaign 临时开放、Economy 入账及原生鼠标点击取得；[运行摘要](evidence/reactor-492-runtime.txt)记录等级 11／12 的实际占比与可见四路。按 13 第 6 节原尺寸看本版完整图，等级文字与左斜边分开，失败原因不压费用，可购时铀实体图仍保留；公共栏、导航、两区边界与右侧原战斗主体未见这次窄修引入的新覆盖。此处只覆盖零余额、当前可购、均分、×10／MAX 后失败及当前组合普通值；不证明自然解锁／收入、所有错误原因、极端长数字、其他模块或整体视觉验收。动态渲染源码未变，先前 `412d9d2f` 的短帧只作历史参照，不冒充本版动态结论。仍待原布局审重新整体判断，不合 main。

### 反应堆 68f35e4e 失败费用图标窄修接入（当前待原布局审）

原组固定源码 `68f35e4e0e479112e7eef2cc53c6bce425c2f100`，原组无钱／可购两整屏仅获其**内区限定**认可。相对已接 `4924205e`，唯一运行差异是 `src/ui/reactor_scene.gd` 的报价布局：刷新时恢复费用标签宽度；单资源报价即使资金不足也显示共享原色资源图，失败态调整图标与费用文字位置，可购态保持原布局。此文件与源 SHA 的 Git blob 完全一致；反应堆 stage／shader／Owner、装备、公共壳、五资源身份、输入与战斗区域均未改。

本组合 Godot 4.7.2 正常主场景的[无钱整屏](evidence/reactor-68-no-funds-1440x900.png)和[可购整屏](evidence/reactor-68-funded-1440x900.png)均为本版 `1440×900` 直接取帧；[固定驱动](evidence/reactor-68-driver.gd.txt)经公开 Campaign 恢复口临时开放、再经公开 Economy 入账 1000 铀，明确两次均在反应堆页。[运行摘要](evidence/reactor-68-runtime.txt)确认费用图标存在与脚本状态。依 13 第 6 节看本版完整整屏，无钱时铀实体图、数量与失败原因均可辨，可购后图标原色及执行键仍在；公共栏、导航、区域界和右侧主体未见这次窄修的新增覆盖。只覆盖本版普通无钱／可购两态，不证明自然收入、所有价格/错误、操作动态或整体视觉验收；`492` 的动态帧属于旧版，**不作为 `68f35e4e` 动态证据**。仍待原布局审重新判断，不合 main。

### 装备 a8467d65 材质候选接入（当前待原整体审）

原装备组固定源码 `a8467d65653b33e818f79bbe33fae59b0df4d795`，原组图证 `4d56ad55`，入口为其 `workbench-optical-revision/coherent-material-polish/README.md`。本分支相对已接 `243b24a1` 精确同步 `src/ui/equipment_panel.gd` 与其直接使用的 `assets/ui/equipment/materials-20261029/control-materials.png`、`.import`、生成提示／来源记录；公共 `resource_visuals.gd` 和后两资源补充图集已与源一致，保留本组合版本而未重取。原组源码用玻璃内面替换仪表／候选灰片，用漆面材质替换按钮与标题旧平填／微粒消费，并修主键焦点字色、按下亮度和短文字重复 tooltip；未改变工作台结构、原生控件交互、费用业务或 `set_shared_host` 安装接口。没有合入原装备分支的宿主／反应堆／公共文件，也未实施已搁置的重排／按需展开／压缩。

Godot 4.7.2 正常主场景同一实例的[装备整屏](evidence/equipment-a846-combined-1440x900.png)与[切到反应堆整屏](evidence/reactor-a846-combined-1440x900.png)均为本组合 `1440×900` 直接截图；[固定驱动](evidence/equipment-a846-combined-driver.gd.txt)明确断言装备标题／导航／场景，再经公共导航进入反应堆，[运行摘要](evidence/equipment-a846-combined-runtime.txt)记录路由互斥。按 13 第 6 节原尺寸重看两张完整画面：新材质实际进入装备工作台，切页后公共顶栏、区域边界与右侧战斗投影保持；**当前无钱态深色主键上“购买1级”字底对比偏弱，跨页按钮材质家族观感也需原整体审判断**，不能因源组内部认可而预称共享组合整体通过。当前只覆盖默认装备无钱普通态和反应堆零余额普通态；原组悬浮／按下／焦点与Batch证据只绑定其固定版本，不自动外推到本组合，反应堆此前 `492` 动态亦非本版动态证据。当前主场景未合 main，仍待原整体审。

### 装备 e52e72c3 禁用字修订接入检查点（待反应堆材质候选）

原装备组固定源码 `e52e72c36df55f89b3caa70cccf9b66874947d96`、图证 `671215bb`，入口 `workbench-optical-revision/disabled-action-readability/README.md`；其正常／资源不足／受控冷却三整屏获原装备审**本版视觉限定**认可，不代表完整操作通过。相对已接 `a8467d65`，唯一运行差异为 `src/ui/equipment_panel.gd`：从现有 navy 材质缓存禁用态低高光面，禁用键不再整幅压暗；主键禁用文字单独调亮。此文件与源 Git blob 完全一致，没有新资产、结构、价格或输入变更；当前公共五资源、宿主顶带、区域边界与反应堆 `68f35e4e` 均保留。

本检查点只完成装备源码接入、`git diff --check`、Godot 4.7.2 编辑器导入及该脚本 `--check-only`（均无脚本解析错误），**未采最终两页组合整屏**。原装备组 `671215bb` 证据属于其源版本；此时反应堆材质新固定 SHA 尚未交付，不把旧 `68f35e4e` 画面称为新材质组合，亦不把旧动态贴到未来版本。待反应堆固定候选到达后只精确接入其模块变化，再采同一源码版装备／反应堆完整整屏交原整体审按 13 第 6 节重新判断；本检查点不是整体验收，也不合 main。

### 装备 e52e72c3＋反应堆 51456ce0 同版材质组合（待原整体审）

在装备 `e52e72c3` 检查点上，原样同步反应堆固定源码 `51456ce05463cc426239863f0c692689fdf4b893` 的 `src/ui/reactor_scene.gd` 与其直接引用的 `assets/ui/reactor/ship-hub-r9/control-materials.png`／`.import`。该 PNG 的 Git blob 与已接装备 `materials-20261029/control-materials.png` 相同，但保留反应堆原组的场景资产路径；反应堆从图中提取冷深蓝辅助键、暖金主键，并按装备同源方法缓存低高光禁用键，原生文字／焦点保持。`reactor_stage.gd`、shader、Owner、装备 `e52`、公共五资源身份／顶带／导航、输入和战斗区域均未改；未合源分支或实施工作台重排。原装备组 `671215bb` 三态、原反应堆组 `51456ce0` 五整屏的限定视觉认可只属各自源版本，不能替代此组合审。

Godot 4.7.2 正常 `main.tscn` **同一实例** `1440×900`：[装备无钱](evidence/material-combo-equipment-unfunded-1440x900.png)、[装备可购](evidence/material-combo-equipment-funded-1440x900.png)、[反应堆无钱](evidence/material-combo-reactor-unfunded-1440x900.png)、[反应堆可购](evidence/material-combo-reactor-funded-1440x900.png)。[固定驱动](evidence/material-combo-514-driver.gd.txt)显式断言装备路由，再通过公开 Economy 入账铁／铀各 1000 与公共导航切页；[运行摘要](evidence/material-combo-514-runtime.txt)记录场景互斥与可购键。按 13 第 6 节原尺寸重看四张完整实图，两页冷深蓝禁用键文字与暖金主键具有可读主次，新材质没有在公共顶栏／导航、模块边界或右侧战斗主体产生本次增量遮挡。入账为受控视觉状态，**不是自然收入或完整购买流程**；本组合未采连续动态，旧 `492` 动态及原组各自视频均不冒充本版组合动态。普通值四图不覆盖全部费用资源、键盘焦点、极端长字、自然解锁、完整游戏或用户整体品质验收。交原整体审重新判断，不合 main。

### 星球 R17 第一固态完整态接入（当前待原整体审）

原星球组固定源码 `f0b617f12b7aff2e635da997f1f0fe96177adda6`，唯一原组入口为 [R17 圆滑实体脊梁材质代表候选](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)。原审只限定认可**第一固态星球四设施完整态的静态外观**；逐步建造、连续运动、其他天体和完整操作仍归原组，不能外推。本分支接入基线为 `3404ef06d73a05f7402457f8f2214086fa637655`：保留装备 `e52e72c3`、反应堆 `51456ce0`、公共五资源原色源、输入及战斗空间。

按运行依赖精确取源版 `src/ui/planet_panel.gd`、`src/systems/planet.gd`、`src/systems/crew.gd`、`scripts/planet_visual.gd`、`rotating_planet.gd`／shader、`planet_facility_scene.gd`、`planet_orbital_spine.gd`／shader，及实际引用的 `facilities_v5` 四个 GLB、八张设施分层 PNG、`orbital_spine/deck-albedo.png`、`painted-v4` 球体／云图与相应导入设置。星球与船员 Owner 在本分支原先等同旧 main，源版新增 `facility_facts`、`conquest_facts`／通知和 `member_facts` 供新页只读使用；未取源 `GameSession`、`PlayerText`、宿主或其他模块，因为它们带有本组合之外的分支差异。旧“星图”页的船员、星系、重铸交易仍保留；只移走其 ScrollContainer 中旧 `PlanetPanel`，避免把新 `808×900` 星球场景塞进 `y=65` 起的滚动内区而裁切。

宿主仅在 `main.gd` 装入独立 `808×900` 星球场景、加公共“星球”导航图标/路由并将九个导航键的纵向间距设为 `90px`。星球页通过原组 `set_shared_host(true, null)` 隐藏自带余额栏，沿用公共顶部资源/标题/退出及 `ResourceVisuals` 五资源身份；视觉上下文补现有 `Economy.balance_rows()`，不改价格或玩法。导航只在 Campaign 星球功能开放时可用；装备、反应堆、星球、星图互斥显隐。星球内部排他弹窗阻止公共切页/战斗输入，离开时 `prepare_host_hide()` 清除页内焦点；重铸请求转到保留的星图原交易界面。原战斗投影仍为 `x=855.875` 起、`536.25×900`、scale `0.9375`，右侧余量未被占用。

Godot 4.7.2 正常 `main.tscn` 的[第一固态四设施完整态整屏](evidence/planet-r17-shared-stage4-1440x900.png)、[切回装备整屏](evidence/planet-r17-shared-equipment-return-1440x900.png)、[切回星图整屏](evidence/planet-r17-shared-universe-return-1440x900.png)，均为本组合 `1440×900` 原图。[固定接入驱动](evidence/planet-r17-shared-driver.gd.txt)经既有 Campaign/Planet 恢复端口临时开放第一星球并设四设施 built；[运行摘要](evidence/planet-r17-shared-runtime.txt)记录星球尺寸、导航/场景互斥、自带钱包隐藏和焦点清理。已按 13 第 6 节原尺寸查看三张整屏：本版公共顶栏、导航、星球内区、装备返回、星图返回及右侧原战斗主体未见增量遮挡；仍交原整体审重新判断。此夹具图不代表自然解锁、逐步建设、星球内部完整操作、连续整圈或其他天体；本组合未采动态，不借用原组动态作共享组合证据，也不合 main。

### R17 接续窄修与星球内控件交接（整体审退回后）

原整体审退回 `6de07599`：第一固态星球主体成立，但星球操作键仍为象牙／灰绿平填，与公共顶轨和装备控件的材质、字级及状态完成度不一致；公共栏下 `y≈65…90` 有深色空带。**这不是旧顶栏叠层**：公共 `ZoneShell._draw()` 对非装备页绘制的顶轨止于 `y=65`，R17 `PlanetPanel._layout()` 的既有星空视觉始于 `y=90`，中间露出根背景。宿主只在 `set_shared_host(true, null)` 模式把原视觉起点移到 `65` 并延伸到 `900`，独立模式仍保留原 `90` 顶部；没有加遮罩、第二块底板或改公共顶轨。环、球、设施及右侧战斗主体仍由原绘制源呈现。

[窄修后的第一固态四设施完整态 1440×900 实图](evidence/planet-r17-shared-stage4-1440x900.png)已在正常主场景原尺寸重看：顶部星空直接接公共轨，原 `65…90` 平直色带消失；主体和左侧导航未见新的裁切。装备／星图返回整屏与上一提交相同，固定驱动又核了两次路由互斥与离页焦点；[本版运行摘要](evidence/planet-r17-shared-runtime.txt)只对应本版静图和路由，不把旧版图冒充新状态动态。本轮显式指定 Godot `--audio-driver Dummy`，因为先前自动选择 ALSA 时 `/dev/snd` 不存在，`AudioDriverALSA::init_output_device` 返回 `ERR_CANT_OPEN` 后引擎回退 Dummy；对象是宿主机音频输出设备，非星球贴图、GLB 或脚本，旧版截图及逻辑仍运行完成。本次日志无 `ERROR`／`SCRIPT ERROR`，仅图形驱动不支持 VSync 的告警；并未声称实际音频播放通过。

星球**内区仍待原组修订**，宿主不以公共 Theme 强盖：`PlanetPanel._theme()` 当前给 `Button`／`OptionButton` 的普通、悬浮、按下、焦点和禁用态同一 `f0eddf`／`d2e6df`／`b3bdb7` 平面与 `243d50` 字色，`_action()` 的停止／取消等键、三枚设施／人员／探索页签、星球选择器、详情抽屉及其关闭键均属星球组。请按唯一 [13 第 2.3／6 节](../../../game-design/13-art-interaction.md)与 [14 UI 契约](../../../game-design/14-ui-contracts.md)，在原组自己的内区用装备／反应堆已用的冷深蓝辅助、暖金主操作、字底对比和可辨状态家族做实际场景适配；核普通、悬浮、按下、选中、禁用、焦点以及长名称、报价和失败提示的净空，替换旧平填实际绘制源，不额外套框。星球的空间场景与设施动作保持原组所有权，不要求画成机库。公共顶栏、资源身份、导航和左／右区界归整体组；星球内建设、人员、费用、详情和状态样式归星球组。此交接只界定待做差异，**不宣称星球控件已统一或本次整体审通过**。

### 星球 867e1825 内区控件候选接入检查点（待原组征服文字收口）

原组固定 `867e18256c0bef231a6f32b33d244e88237bc854` 相对已接 R17 的唯一运行文件差异是 `src/ui/planet_panel.gd`，原组入口仍为 [R17 README 的 planet-control-surface 小节](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)。本组合从该 SHA 精确取此文件的内区按钮、抽屉、选择器和展开态场景避让；保留已审宿主专用的顶轨 y=65 接续：收起时原视觉从 y=65 到900，展开时原视觉在 x=292…808 同样从 y=65 起，原组既有左抽屉背景也在共享模式从 y=65 起。独立模式仍用原组 y=90。没有取原组 main、公共壳或其他模块文件，装备、反应堆、资源身份、焦点输入与右侧战斗空间未改。

已在 Godot 4.7.2 以 Dummy 音频驱动完成本版编辑器导入、主脚本 `--check-only` 及 `git diff --check`，无脚本／资源错误。本检查点**尚未取最终组合整屏或动态**：原星球组还在收口征服详情的两处文字层级，当前 `867e1825` 的七张整屏静态方向限定认可只属其内区版本，不能外推本共享组合或完整操作。最终固定修订到达后，只同步后续实际差异，再采同版装备／反应堆／星球必要整屏供原整体审重新判断；当前旧版截图不冒充 `867e1825` 最终视觉证据，不合 main。

### 星球 5458a8b1 征服详情收口后的共享组合（待原整体审）

原星球组后续固定 `5458a8b19c96a1b3b8305772e01728a55c76a1f3`，源 [R17 README 的征服详情局部排版收口小节](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)。相对 `867e1825` 仅 `src/ui/planet_panel.gd` 中两条征服事实、累计奖励标题及四项左右对齐排版变化；本分支只应用这段源补丁。当前文件与该源 SHA 的差异只余共享宿主 y=65 顶轨接续及展开态左背景适配，独立星球模式仍 y=90。装备 `e52e72c3`、反应堆 `51456ce0`、五资源身份、公共导航、战斗投影和输入未改；反应堆此版只作既有场景返回对照，用户要求的反应堆重设计仍暂停在概念阶段，本接入没有续改。

Godot 4.7.2 正常主场景同一源码版的 `1440×900` 原图：[星球完整态](evidence/planet-5458-combo-stage4-1440x900.png)、[设施展开](evidence/planet-5458-combo-facilities-1440x900.png)、[探索／征服详情](evidence/planet-5458-combo-conquest-1440x900.png)、[切回装备](evidence/planet-5458-combo-equipment-1440x900.png)、[切回反应堆](evidence/planet-5458-combo-reactor-1440x900.png)、[切回星图](evidence/planet-5458-combo-universe-1440x900.png)。[固定驱动](evidence/planet-5458-combo-driver.gd.txt)使用既有 Campaign/Planet 恢复端口造第一固态四设施 built 状态，刷新反应堆可用性，未提交购买、建设或探索命令；[运行摘要](evidence/planet-5458-combo-runtime.txt)记录路由互斥、钱包隐藏及焦点清理。Godot 导入、主脚本 `--check-only`、同版运行与 `git diff --check` 通过，Dummy 音频驱动下无脚本／资源错误；音频播放未验证。

按 13 第 6 节原尺寸查看本版整屏：星球顶轨接续无 y65–90 断带，收起与展开时环、球、四设施未见新裁切，征服事实与累计奖励不再逐字断行且主次可辨；返回装备与反应堆时公共栏、导航及两区边界未见本次增量遮挡。此为交原整体审的当前候选，**不预称整体视觉或星球原组最终通过**。夹具图不证明自然解锁／逐步建设／连续动态／其他天体；旧自然时间视频与本版控件源码不同，不拼接为本版动态证据。反应堆现有页面的品质亦不因路由截图被重新验收，未合 main。

### 星球 dc9bdfb8 连续抽屉材质接入（待原整体审）

原组固定 `dc9bdfb8c2b8fa7bd327a6c43ffbd8857abd973b`，入口为 [R17 README 的“变高抽屉的连续承载面”](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)，原星球审本版七张整屏仅**内区静态整体接受**。相对已接 `5458a8b1`，精准同步唯一运行脚本 `src/ui/planet_panel.gd` 和其直接载入的 `assets/ui/planet/control-materials.png`／`.import`，并保留原组的材质提示、来源记录。该 PNG 的 SHA256 为 `707d137c2201aa0e9f33d730675402cff2b9195d26282d6305a66b22e37e5d6c`，与现有装备漆面材质文件字节相同；星球保留自身资源路径。当前 `planet_panel.gd` 与源 SHA 的代码差异仍仅共享宿主模式 y=65 的星空及展开抽屉左背景接续，独立模式仍 y=90。没有取原组 main、Owner、公共壳或其他模块文件；公共顶轨、顶部资源与退出、导航/焦点、装备、反应堆、五资源身份及原战斗投影保持。

Godot 4.7.2 正常主场景同版 `1440×900` 原图：[星球完整态](evidence/planet-dc9-combo-stage4-1440x900.png)、[设施短抽屉](evidence/planet-dc9-combo-facilities-1440x900.png)、[探索／征服长抽屉](evidence/planet-dc9-combo-conquest-1440x900.png)、[切回装备](evidence/planet-dc9-combo-equipment-1440x900.png)、[切回反应堆](evidence/planet-dc9-combo-reactor-1440x900.png)、[切回星图](evidence/planet-dc9-combo-universe-1440x900.png)。[固定驱动](evidence/planet-dc9-combo-driver.gd.txt)经既有 Campaign/Planet 恢复端口设置第一固态四设施 built，刷新反应堆可用性，未提交购买、建造或探索命令；[运行摘要](evidence/planet-dc9-combo-runtime.txt)确认路由互斥、钱包隐藏、焦点清理。Godot 导入、主脚本 `--check-only`、正常实例运行和 `git diff --check` 通过；Dummy 音频驱动下无脚本／资源错误，未验证音频播放。

按唯一规范 13 第 6 节原尺寸看本版完整画面：星球主键、次键、选择器已呈同源漆面，长短抽屉为连续面色和细壳，不再是旧按钮玻璃片纵向拉出的竖带；标题、收起键、侧底壳的净空可见，顶轨 y65 接续、球环及四设施未见新增裁切。返回装备／反应堆／星图时公共栏、导航和战斗主体没有本次新增覆盖。**仍须原整体审对当前组合重新判断**，原星球组内区静态结论不外推整体。旧反应堆截图仅证明既有页面可返回；其 B01 重设计仍归原组，未在本接入修改或验收。此夹具不证明自然解锁、逐建、连续运动、其他天体或完整操作；旧自然时间视频与本版控件码不同，不拼成同版动态证据。未合 main。

### 当前 52c043e9 公共入口覆盖与剩余归属

在当前 `52c043e9` 正常主场景、同版 `1440×900`，独立补看[舰船公共入口](evidence/public-52c-ship-1440x900.png)、[设置双列](evidence/public-52c-settings-1440x900.png)、[打开的资源详情](evidence/public-52c-resource-details-1440x900.png)，以[同版取帧驱动](evidence/public-52c-driver.gd.txt)明确经公共导航进入，断言路由和弹层可见；[运行摘要](evidence/public-52c-runtime.txt)无脚本错误。驱动复用现有第一星球四设施 built 的临时 Campaign/Planet 夹具，因此截图不代表自然开放。原尺寸查看当前公共顶轨、导航选中、设置分栏、输入槽字底和资源弹层：这三页未见本版新增的公共边界错位、贴边或资源图标混用。余额弹层预建五种资源图标行；当前 Economy 钱包仅返回四种余额，第五“简并物质”在尚无该资源事实时隐藏，并非图标缺失的断言。此为公共受影响入口的当前静态覆盖，不替代用户或原整体审对完整品质的判断。

**独立职责已完成到当前候选的可核范围**：公共顶轨、九路导航、资源身份/余额弹层、设置原生控件材质与布局、切页显隐/焦点，以及本版星球宿主端口均有源码和当前实图；未发现一个能仅凭当前事实继续改的公共缺陷，故不凭“整体未完成”再堆新框或造美术微调。舰船页中的航行/驻守、换船和属性长表分别由 `CampaignPanel`、`FleetPanel`、`AttributesPanel` 绘制，公共组只负责其窗口承载和可见边界；装备、星球、反应堆内部价目/材质/动作由原组交候选。本版旧反应堆只作路由对照，用户批准的 B01 整模块重设计由原组制作，未交固定运行候选时不能在本分支代改或称其已完成。后续可独立推进的是收到各组固定候选后的精确宿主接入和同版整体审证据；该步骤依赖候选 SHA/原组限定结论。当前整体品质选择与是否合 main 仍待用户/根端，不能从局部截图推出。

### 反应堆 B01 与公共设置材质同版接入（交原整体审）

在 `02b8e3af4be2395527e953505eb2e47909d0be71` 公共组合上，精确取原反应堆组 `25475c0f360c7286e1ac0bc9d52b02f4f2eff7fd` 的 `src/ui/reactor_scene.gd`、`src/ui/reactor_stage.gd` 和其直接使用的 `assets/ui/reactor/b01/` 素材。原组运行交接入口是该 SHA 中的 `docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md`。本次未取源分支的 `main.gd`、公共壳、装备、星球或 Owner；旧 R9 反应堆的四角面板、脉冲覆盖和底台旧砖在新两脚本的实际绘制路径中已被 B01 原组代码替换，历史 R9 素材仍留供历史来源，不再叠画。新场景仍由现有 `808×900` 宿主安装、公共顶轨与退出、资源身份、导航显隐与焦点契约承载；装备 `e52e72c3`、星球 `dc9bdfb8` 和战斗投影未改。

同一版公共修正对应原整体审对 `02b8e3af` 的退回：设置音乐／音效仍为默认圆角勾选，资源弹层与设置操作关闭／执行键仍是平框。现在四个设置 `CheckBox` 都在原生控件上用公共 `BridgeTheme.public_check()` 设置勾选与未勾选图标、禁用图标、漆面普通／悬浮／按下／禁用面及焦点边；回调与文字保持原样。公共 `public_button()` 直接从已存在的装备 `materials-20261029/control-materials.png` 取漆面九宫格，供原有设置操作键与资源详情关闭键使用，**替换**原四个不再引用的平框 SVG，不增加覆盖控件层。新公共勾选图标仅四张 SVG，属于公共壳；B01 内部原组控件未被公共样式强盖。

Godot 4.7.2 导入、`main.tscn` 脚本检查和正常主场景运行无脚本／资源错误；受控驱动经公开 Campaign 恢复端口开放反应堆、Economy 入账 1000 铀，并操作原生均分／数量键，记录 [零载](evidence/b01-shared-zero-1440x900.png)、[带载](evidence/b01-shared-active-1440x900.png)、[×10](evidence/b01-shared-ten-1440x900.png)、[MAX](evidence/b01-shared-max-1440x900.png)、[切回装备](evidence/b01-shared-equipment-1440x900.png) 五张同版 1440×900 整屏，固定[驱动](evidence/b01-shared-driver.gd.txt)和[运行摘要](evidence/b01-shared-runtime.txt)。另一当前主场景实例记录[设置普通](evidence/b01-public-settings-normal-1440x900.png)、[焦点](evidence/b01-public-settings-focus-1440x900.png)、[受控禁用](evidence/b01-public-settings-disabled-1440x900.png)及[资源弹层](evidence/b01-public-resources-1440x900.png)整屏，另有[悬浮取帧](evidence/b01-public-settings-hover-1440x900.png)与[驱动](evidence/b01-public-driver.gd.txt)／[运行摘要](evidence/b01-public-runtime.txt)。原尺寸看当前整图，B01 底台、四路、中央场景、公共轨及右侧战斗主体没有这次接入新增的遮挡／压缩；设置勾选、禁用字底与弹层关闭键与现有按钮漆面相接。悬浮取帧由本机鼠标定位生成，截图视觉变化不明显，不能据此宣称已单独验收悬浮视觉。

这些是当前组合的静态与必要切页／数量接入观察，不是自然解锁、自然收入、完整购买、连续战斗或全部输入状态证明；B01 原组 10 秒视频属于源分支，**不是本共享组合动态证据**。原组零载／带载／×10／MAX 内区视觉认可及先前公共审结论都不外推本版整体；须按唯一规范 13 第 6 节由原整体审重新看当前真实整屏。未合 main。

### 装备 fc361675 同族材质接入 B01／星球共享组合（交原整体审）

在已固定的 `e9f36379a8c8c1c825be51e032b836c4a814f5ae` 上，精确取原装备组源码 `fc361675131aa59ce21ec270a5aaa7e9715f9746` 的**唯一运行差异** `src/ui/equipment_panel.gd`；其图证固定于 `784d8de3536afaae0bb430506ab1dfc697bcd8d5`，原组入口为 `docs/verification/equipment-hangar-godot/workbench-optical-revision/README.md` 的同族材质候选。没有新增装备素材：新版从本组合已有 `materials-20261029/control-materials.png` 取同一内面材，把托盘、标题、键、侧槽、禁用／焦点状态收敛为同一截面。当前文件与原组源码 blob 一致，原有 `set_shared_host`、`prepare_host_hide`、`ResourceVisuals.icon_modulate` 端口仍在；没有取源分支公共壳或其他模块，也没有实施已搁置的工作台重排／压缩。反应堆 B01、星球 `dc9bdfb8`、公共四态勾选／关闭键及五资源身份源、顶部退出、区域输入与战斗投影均未改。

Godot 4.7.2 编辑器导入、主脚本检查与受影响主场景运行未见脚本／资源错误。[固定驱动](evidence/fc-combo-driver.gd.txt)在**同一正常主场景实例**经公开 Campaign／Planet 恢复端口临时开放星球四设施完整态，并依公共导航依次取[装备](evidence/fc-combo-equipment-1440x900.png)、[B01 反应堆](evidence/fc-combo-reactor-1440x900.png)、[星球](evidence/fc-combo-planet-1440x900.png)三张同版 `1440×900` 原图；[运行摘要](evidence/fc-combo-runtime.txt)记录三路互斥、星球自带钱包隐藏。按 13 第 6 节原尺寸看当前三整屏，装备同族材质与公共顶轨、导航、星球／反应堆页面、右侧原战斗主体没有此次接入新增的裁切或遮盖；仍须原整体审重新判断，不能以文件差异少或旧原审结论代替当前审图。

`e9f36379` 的原整体审已**静态接受公共 UI**，但组合暂不通过：B01 费用行约 `x600,y795…812` 起字贴斜内缘，反应堆原组正与 MAX 标签一起修，待其固定源码再精确接入；本次只保留该旧版 B01 作路由和同版布局对照，不代改其内区，也不把旧 B01 图或源组动态冒充修订后证据。原装备组四整屏／七局部对其自身整页同族品质的视觉认可，不是用户验收或公共组合认可。本次图属受控第一星球完整态与当前普通余额，不证明自然解锁、建设、购买、连续动态或完整操作矩阵；未合 main。

### 跨页操作角色层级公共窄修与星球交接（当前候选，非整体通过）

`f72f6014` 的原整体审认为装备同族材质相对前版已有改善，但跨页仍不通过：装备低反差弱边缘面、星球与公共操作键亮金属包边的强弱不一致；同图集不等于同角色视觉层级。之后用户又退回 `fc361675` 装备内页右侧空置、装甲替换缺失、购买亮态异族；因此前节的原组视觉认可已被最新用户反馈覆盖，**`fc361675` 仅保留历史接入，不是最终装备基准，也不以其购买亮态作为公共模板**。这些装备内区问题归原装备组修，本节不改其脚本或结构。B01 费用贴斜缘与 MAX 标签亦由原反应堆组修；其 `9273a680` 修订已原审准许交接，但升级提示措辞和误标零态证据尚待原组收口，此节公共修订没有冒用旧 B01 零态图为新修订证据。

公共组在现有 `BridgeTheme.public_button()` 的**原样式绘制源**上替换原从装备图集取带亮外圈的整键片：现在只取同图集内层漆面，公共原生键由同一 `StyleBox` 绘制切角面、微弱受光上沿与暗回边，没有新增控件或叠第二框。普通选择／关闭为冷深蓝低反射，保存／确认提交在同面材上用克制暖边提示主次；悬浮提高边缘可见度，焦点只勾当前键，禁用降低面层但保留字，设置勾选仍保留原生选中/禁用图标。设置操作 `main.gd` 仅将“保存进度／确认新游戏／确认导入”指派为提交角色，业务回调与布局不变；公共顶轨、导航、装备、星球、B01 内部及战斗投影没有改。唯一规范已在 [13 第 2.3 节](../../../game-design/13-art-interaction.md#23-所有模块共享的状态与反馈)写跨页角色与同版整屏判断，[14 第 1 节](../../../game-design/14-ui-contracts.md#1-版本与使用边界)仅保留前后端归属引用，未新建并行规范。

星球原组短交接：当前 `planet_panel.gd` 的 `_paint_button()` 给设施／人员／探索页签、`world_planet_picker` 给星球选择，`_action()` 给抽屉执行／停止／取消与关闭。请在**现有这些绘制源**按选择、当前选中、提交、关闭、禁用、焦点分别收敛金属包边的面积/亮度及字底，不把全部键削成同一平片；设施与星球主体、环、抽屉连续承载面不重画，`set_shared_host` 与共享 y65 顶轨接续不改。以实际星球整屏与装备／公共设置同版比较可见面层和操作主次，再由原组交固定候选；公共组不强盖星球 Theme，也不声称本段文稿已完成星球内部修订。装备下一版也应按角色验证其购买亮态，而非追随现版亮度。

Godot 4.7.2 当前源码导入、主脚本检查及受影响主场景运行无脚本／资源错误；同版 [装备](evidence/role2-combo-equipment-1440x900.png)、[B01](evidence/role2-combo-reactor-1440x900.png)、[星球](evidence/role2-combo-planet-1440x900.png)、[设置普通](evidence/role2-public-settings-normal-1440x900.png)、[设置焦点](evidence/role2-public-settings-focus-1440x900.png)、[设置受控禁用](evidence/role2-public-settings-disabled-1440x900.png)、[资源详情与关闭](evidence/role2-public-resources-1440x900.png)均为实际 `1440×900` 完整画面；[三模块驱动](evidence/role2-combo-driver.gd.txt)与[公共驱动](evidence/role2-public-driver.gd.txt)只作受影响静态/路由观察。原尺寸看公共设置操作键比前版减少亮边重复，提交键与普通键有可辨主次，资源关闭不再是高亮金属整键；星球内键仍亮、装备内页与 B01 旧费行仍待各原组修。此处是公共窄修候选，**不能称跨页整体视觉通过**；自然流程、连续动态和完整业务操作未由这些截图覆盖，未合 main。

### B01 9273a680 费用斜边与 MAX 读面阶段接入（待原组文字收口）

原反应堆组固定 `9273a6805741703565aaa6cf0a1799ae62e69681`，原审对本版费用斜边净空及交互视觉准许交接，但升级提示措辞和原组“zero”文件误标仍由原组收尾。相对已接 B01 `25475c0f`，**唯一运行差异**为 `src/ui/reactor_scene.gd`：费用首格从 x600 内收至 x612、图标与金额右移、首格宽度缩为 68，并把无可购 MAX 的模式／失败原因分格。该文件从源 SHA 精确同步且与源 blob 一致；B01 场景、美术、Owner、装备 `fc361675`、星球 `dc9bdfb8`、公共控件角色层级及宿主边界均未改。未合原组分支，也未代改其提示措辞。

本组合 **新取** [当前真零负载](evidence/r927-shared-zero-1440x900.png)、[均分带载](evidence/r927-shared-active-1440x900.png)、[×10 报价](evidence/r927-shared-ten-1440x900.png)、[MAX 报价](evidence/r927-shared-max-1440x900.png)、[切回装备](evidence/r927-shared-equipment-1440x900.png) 同版 `1440×900` 整屏；[固定驱动](evidence/r927-shared-driver.gd.txt)在零帧断言 Owner `load=0`，之后用受控 Campaign 开放与 Economy 1000 铀入账，仅操作原生均分／数量键而不购买，[运行摘要](evidence/r927-shared-runtime.txt)记录报价及互斥切页。此前原组旧 `zero-1440x900.png` 的误标与本页新断言图无关，旧共享 B01 图片也不冒充此版。Godot 4.7.2 导入、主脚本检查及运行无脚本／资源错误；原尺寸看当前真零、MAX 图，费用起字离左斜边有净空，MAX 的“可购11”、铀图和金额分列清楚，公共栏、导航、战斗主体未见这次窄改新增遮盖。**本阶段不是最终反应堆文案或整体组合通过**；等待原组后续固定小差异再同步。上述图不证明自然解锁／收入、升级成交、连续动态或装备／星球内部最新验收，未合 main。

### 反应堆 01efbf12＋装备 9e420e1c 当前组合（交原整体审）

在公共角色层级 `45ffdb6e` 与反应堆费用净空 `6847ce61` 的共享宿主上，精确同步原反应堆组最终源码 `01efbf12e7c2d8a814343fe7503fd692861f4712` 的唯一运行差异 `src/ui/reactor_scene.gd`：成功升级提示根据实际成交数显示“已升级 N 级”，分配成功仍称“供能已更新”。原组证据入口仍为 `docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md`，其误标的旧 `zero-1440x900.png` 已由原组撤下；本组合仅引用自己的当前真零断言图。原组审对 B01 内区当前整屏/交互的认可仅限原组源版本，不代替共享组合整体审。

同版接入原装备组源码 `9e420e1c184d355133737a72f716358203ffa51a` 与证据 `ca6914ed3f64eef510c9ca421360a97359ed33f0`；原组入口为 `docs/verification/equipment-hangar-godot/workbench-optical-revision/candidate-balance-and-armour/README.md`。相对已接 `fc361675` 的唯一运行差异是 `src/ui/equipment_panel.gd`：弱化可用购买键的异族金面、同族延伸现有右侧候选托盘与无替换时的购买行，防御两候选按右栏宽度铺开。该文件与原组源 blob 一致，没有新增素材、旧框叠盖、工作台结构重排或 Owner 规则改动；`set_shared_host`、焦点/离页与 `ResourceVisuals` 端口仍在。公共壳/五资源身份/原生输入、星球 `dc9bdfb8`、战斗投影均保留。星球 `fd099201` 尚在原审，不抢取或称其通过。

Godot 4.7.2 主脚本检查、正常主场景及两份受影响驱动无脚本／资源错误。同一最终源码版 1440×900 的[装备默认](evidence/final-combo-equipment-1440x900.png)、[B01](evidence/final-combo-reactor-1440x900.png)、[星球](evidence/final-combo-planet-1440x900.png)三张完整整屏由[公共切页驱动](evidence/final-combo-driver.gd.txt)在同一实例取得，三页互斥且星球自带钱包隐藏。装备受控显示[武器可购](evidence/final-equipment-weapon-ready-1440x900.png)、[武器候选比较](evidence/final-equipment-weapon-replacement-1440x900.png)、[资金不足](evidence/final-equipment-weapon-disabled-1440x900.png)、[当前护盾](evidence/final-equipment-shield-current-1440x900.png)和[装甲替换候选](evidence/final-equipment-armour-replacement-1440x900.png)整屏，[驱动](evidence/final-equipment-driver.gd.txt)仅经原组既有受控 Campaign／Economy／Equipment 恢复端口准备显示、选择候选，**未执行安装或购买**；这不冒充原组 `ca6914ed` 的完整八态/安装证据。B01 [当前真零](evidence/final-reactor-zero-1440x900.png)在取帧前断言 Owner `load=0`，随后[均分带载](evidence/final-reactor-active-1440x900.png)、[×10](evidence/final-reactor-ten-1440x900.png)、[MAX](evidence/final-reactor-max-1440x900.png)及[当前 MAX 成交提示](evidence/final-reactor-purchased-1440x900.png)由[驱动](evidence/final-reactor-driver.gd.txt)经公开受控铀入账与原生键操作取得，日志记录等级 `1→12` 和“已升级 11 级”；[切回装备](evidence/final-reactor-equipment-1440x900.png)确认路由。上述三份[运行摘要](evidence/final-combo-runtime.txt)、[装备摘要](evidence/final-equipment-runtime.txt)、[反应堆摘要](evidence/final-reactor-runtime.txt)均属此源码版，不借用先前 `927` 或 `fc` 图证。

按 13 第 6 节原尺寸看本版完整画面，装备下方右侧的装甲/护盾候选及比较不再缺席，当前不可购/可购控件比 `fc` 的亮金异族键更接近本页冷面；B01 成功提示与报价没有覆盖其底台文字或公共顶轨；三页导航、顶部余额、区域边界和原右侧战斗主体未见此次双接入新增遮挡。仍由原整体审对当前组合重新判断，**不把原组各自静态/交互限定结论或旧公共静态接受外推为整体通过**。受控余额与候选不是自然开放、自然收益或全槽位/全部悬浮按下/完整交易矩阵；装备本驱动没有执行更换或购买，反应堆本驱动没有采连续动态，星球图只证明旧当前页可切入，均不合 main。

### ac026836 原整体审限定结论与下一依赖

原整体审已按 13 第 6 节亲看本组合 14 张原尺寸整屏：装备 `9e420e1c` 与反应堆 B01 `01efbf12` **在已展示状态的共享组合中可接受**，公共顶栏／导航／区域接续未见本版新增阻断；这不是用户最终验收，也不扩展为悬浮／按下、全部对象、自然流程、连续动态或完整游戏通过。当前唯一已知跨页视觉未收口项是星球 `dc9bdfb8` 的普通页签亮重包边，比公共／装备普通选择强调更强。星球原组已收到前节的角色层级交接，正在自行收敛内区及恒星品质；整体组不代改星球主体或控件。现有公共壳、资源身份、导航／焦点、装备／B01 已有固定源码与同版图证，没有另一项可在不越过模块归属的情况下独立推进的已知实施或复测；下一步依赖原星球组交付经原审确认的固定运行候选，再精确接入并按当前完整实图重新整体判断。此限定结论保留，不合 main。

### 现行源码控件映射（供根端建立 Figma 可编辑组件）

此索引只对应共享组合 `cc92031a58b003100b89827df659f2364eecbeda` 的**真实运行源码**：装备文件来自 `9e420e1c184d355133737a72f716358203ffa51a`，反应堆文件来自 `01efbf12e7c2d8a814343fe7503fd692861f4712`。根端已建[唯一 Figma 文件](https://www.figma.com/design/zlWQqp1rQ4MZoOoMMnerST)，由根端建立可编辑组件/token 后再交运行实施；本节只是现状定位，不代表组件已建或新样式已批准。尺寸为 Godot 逻辑像素，动态内容不能从静态画面反推。

| 归属／源码入口 | 现行几何、字体与状态源 | 动态值及边界 |
|---|---|---|
| 公共宿主 `src/main.gd::_show_session`、`src/ui/zone_shell.gd::_init/_draw` | 窗口 `1440×900`；左工作区 `808×900`，右战场容器 x808、宽632，原战斗逻辑画面按 `min(632/逻辑宽,900/逻辑高)` 等比居中；公共层只绘顶部轨和两侧预留带，不拉伸战斗。`zone_shell` 顶轨 x0–808、高65（装备页高85），标题牌 `(18,12,148,41)`、标题字 `(28,12,128,41)`/20；前三余额位置 x190/326/460，17px 图标与16px 字；资源键 `(684,12,92,41)`，状态键 `(650,16,28,32)`；九路导航 x813、y=`93+90×序号`、`37×70`，图标 `19×19`、字12。字体 `assets/fonts/NotoSansSC.ttf`、公共 `FontVariation` 字重450，主题默认15；`TEXT #f0f2e9`、`MUTED #b7cec9`、`DARK #0d2533`、`EDGE #6e9697`。 | 标题、导航当前选中/可用状态由 `set_active_route/set_route_available` 改原有控件；余额由 Economy `display_changed` 标脏后只更新文字/已打开详情行，三余额及五资源详情图标取 `ResourceVisuals.icon/icon_modulate`。资源详情 Popup 位置 `(450,66,330,190)`，状态详情 `(330,66,470,190)`，不是固定面板图。星球内容与战斗绘制均非公共控件。 |
| 公共状态 `src/ui/bridge_theme.gd`，实际挂接见 `zone_shell.gd` 与 `main.gd::_settings_action/_settings_field` | `public_button(state,padding,role)` 从现有装备图集 `control-materials.png` 的 `(120,800,1200,130)` **内漆面**生成 `PublicControlSurface`，5px 切角；普通冷面 `#304d57`，提交角色 `#52695f`/暖边，hover `#3c5c65`，pressed/selected `#819995`，disabled `#253d47`；focus 只画外轮廓。`route_button` 使用 `nav-idle/hover/active.svg`，selected/pressed/hover_pressed 同 active；`top_button` 使用 `top-control.svg` 与 hover 图；`public_input` 用 `input-well[-focus/-disabled].svg`。公共 `CheckBox` 用 `check-{off,on}[-disabled].svg` 和同一按钮面，四个设置框由 `main.gd` 实际调用；设置键最小高39，默认宽178，保存/确认才为 `commit`；资源弹层关闭键 `108×38` 为普通角色。 | `normal/hover/pressed/hover_pressed/focus/disabled` 是 Godot Theme override；选中导航另由 `zone_shell.set_active_route` 同步字/图标墨色（选中 `#173e4c` 或 `DARK`），不能只复制按钮底图。输入槽含 LineEdit、OptionButton、SpinBox 内嵌 LineEdit 与 stepper 图标/背景；这些在 `main.gd::_settings_field` 实际覆盖。`BridgeTheme.create()` 另有默认 Theme `StyleBoxFlat` 后备，不等于这些实例的最终可见外观。 |
| 装备内区 `src/ui/equipment_panel.gd::_setup_materials/_surface_material/_prepare_button_material/_button_tint` | 内区 `808×900`，同一 NotoSansSC 字体常规400/强600，默认15；文本 `INK #203f50`、`CREAM #f3f0df`、`LIGHT #d8ece8`，按钮16。漆面取 `assets/ui/equipment/materials-20261029/control-materials.png` 内面，控制台另用 `painted-console-shell.png`；`EquipmentSurface` 依据 `button/tray/candidate/index/header/instrument/deck` 轮廓绘制。工作台数量键为工作台内局部 `(20,208,96,36)`，购买键 `(226,240,218,36)`；批量弹层是另一套内区按钮布局。 | `normal/hover/pressed/disabled/focus` 在 `_prepare_button_material` 缓存，候选/索引的 selected 是 `_button_tint(chosen)` 切换材质变体和字色，非公共导航 selected。费用、可购、候选、数量、禁用由模块事实/报价刷新；公共组只承载 `set_shared_host`、路由显隐与输入边界，不拥有其工作台、装甲比较或购买键设计。 |
| B01 反应堆内区 `src/ui/reactor_scene.gd::_init/_button/_update_buttons` | 场景 `808×900`，内容 SubViewport 从 y65 起、`808×835`；NotoSansSC 常规400/中500/粗600，默认15，按钮粗17（主键18，升级键另设27）。按钮漆面取 `assets/ui/reactor/ship-hub-r9/control-materials.png` 的 primary/navy 切片，`ReactorKeySurface` 包住纹理；focus 是 `#b3ead8` 2px 轮廓，hover 调亮、pressed 调暗并下沉、disabled 冷面降亮，主键字 `#203f50`、次键字 `#f3f0df`。数量键 `(612,673,150,42)`，升级键 `(603,728,166,54)`；均分键 `(651,558,101,41)`。 | `normal/hover/pressed/focus/disabled` 由模块自身 `_button` 生成，未共享公共 `public_button`；×1→×10→MAX 由 `_cycle_quantity` 切模式/报价，升级键才成交。费用、按钮禁用、四路颜色（武器 `#ffc533`、防御 `#33b9ff`、铁 `#ff7d37`、碎片 `#ae53ef`）及比例条/场景均按 Owner 模型动态绘制，归反应堆原组；公共组不把 Figma 静态组件覆盖其状态逻辑。 |

**Figma 角色/状态对照口径**：默认、悬停、按下、选中、禁用、焦点按表内各自的实际 Theme/脚本分支建变体；“可购买”是**带事实条件的操作语义**，不是第七张通用底图。装备 `_refresh_comparison` 读取 `session.equipment_comparison(...)` 的 `comparison.affordable`，决定 `_purchase.disabled`，安装则由 `comparison.switch_admission.ok` 决定；反应堆 `main.gd::_setup_reactor_scene` 把 Owner `purchase_preview/purchase_max_preview(session.economy.can_pay)` 接到 `bind_purchase_quote`，`reactor_scene::_refresh_quote/_update_buttons` 用 `quote.can_purchase`、运行状态和模型决定升级键可用，模式键只切报价。两者在“可购”时的材料强弱仍各由模块原组控制；Figma 可统一语义/角色，不应把静态亮态替代实际可购判定或购买命令。公共导航的 selected 是当前路由，装备 candidate/index 的 chosen 是内区对象选择，二者语义不同。

当前星球仍是 `dc9bdfb8`；普通页签跨页强调待原组固定并经原审确认，`fd099201` 未作为本组合源码。后续模块内实施范围仍归原组：反应堆仅等级升级小面板、均分超框及未解锁碎片检查；装备统一武器/防御操作展示并精简防御冗余。公共组件映射不接管这些内区，也不重做已认可主体。此文稿不新增运行改动或视觉通过结论。

### Figma 公共状态增量与工具限额（阶段交接）

根端唯一 [Figma 文件](https://www.figma.com/design/zlWQqp1rQ4MZoOoMMnerST) 的页面 `0:1`、工作板 `2:14` 已实读：`ActionButton` 变体集 `2:29` 含 `normal/hover/pressed/selected/disabled/ready` 六个 `132×42` 组件，其六态已有同一个成功导入的内漆面 `imageHash=95fe0fd7f32f73eb7d6cab88d7270d3ff7825000`。根端反应堆局部已有该组件的 normal／ready／disabled 实例；不能为改公共颜色直接改 `2:29` 而连带改其局部。根端反应堆布局及装备布局节点本次均未修改，也没有重试此前 HTTP 413／405 的上传路径。

已成功在原有 `舰桥 UI` 变量集合 `VariableCollectionId:2:2` 的 `Default` 模式创建下列**公共按钮专用**颜色变量；颜色来自本节对应 `bridge_theme.gd::public_button`，用于后续独立公共组件绑定，不改原集合旧变量或既有六态组件：`public/button/face-normal` `VariableID:5:8` `#304d57`；`face-hover` `VariableID:5:9` `#3c5c65`；`face-pressed-selected` `VariableID:5:10` `#819995`；`face-disabled` `VariableID:5:11` `#253d47`；`face-commit` `VariableID:5:12` `#52695f`；`edge-normal` `VariableID:5:13` `#89a8a7`/0.47；`edge-hover` `VariableID:5:14` `#b6d3cb`/0.65；`edge-disabled` `VariableID:5:15` `#577b81`/0.36；`edge-commit` `VariableID:5:16` `#baa779`/0.69；`edge-focus` `VariableID:5:17` `#e5c784`/0.88。它们在创建调用中返回了上述 ID；**尚未绑定任何新组件或实例**。现有 `ActionButton` 的 ready 是结构工作稿，真实可购仍由上节装备/反应堆事实端口决定。

原拟在同页隔离建立公共专用变体集（含缺失的 focus），复用已导入内漆面并绑定这些 token，避免影响反应堆已有实例；**该组件/实例尚未创建**。补 `public/button/text-hover` 变量时，Figma MCP 返回 `INVALID_ARGUMENT`；紧接着只读检查明确返回“Starter plan MCP tool call limit”，因此这笔变量调用是否执行不能确认。根端后来依用户判断撤掉 Figma 作为持续制作／实施依赖；上述 token 和文件只保留历史交接，不再探测额度、补组件或把结构稿当批准成品。公共状态统一回到项目现有 `BridgeTheme` 与共享资产实际运行源，需替换重复样式而不叠盖旧控件。本节不触发运行游戏替换、测试或合 main。

### 星球 331866cc 恒星面与操作角色的共享接入（当前组合待原整体审）

原星球组固定源码 `331866ccae0153cfa9308358e495b3c1b1c0b246`，入口为 [R17 的 stellar-plasma-r2 节](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)。相对当前 `dc9bdfb8`，精确取其 `src/ui/planet_panel.gd`、`scripts/planet_{facility_scene,orbital_spine,visual}.gd`、`scripts/{planet_spine_opaque,rotating_planet}.gdshader`、两张 `assets/planets/stellar-{main-granulation,red-convection}.png` 及其导入设定和来源提示词；未取源分支 main、公共壳、装备、B01、Owner 或旧证据目录。`planet_panel.gd` 与源文件仅保留本共享宿主特有的 `_layout/_draw` y65 天空与展开抽屉左背景接续（独立模式仍 y90）。两张新图的 SHA256 分别为 `89d43018dfd60c808583155876240e99beb313ca1e8f8367f257e93ef384d803`、`391ab894b6bdbfa16d7c8e0c607a5b948d20f62013475d305489227635b9429b`；其他星球运行文件与源 blob 一致。

Godot 4.7.2 编辑器导入、主脚本检查及同一 `main.tscn` 受控主场景运行无脚本／资源错误。[固定驱动](evidence/planet-331-combo-driver.gd.txt)受控将六行星球设为已征服及四设施 built，并经公共导航取 [固态完整](evidence/planet-331-combo-stage4-1440x900.png)、[设施展开](evidence/planet-331-combo-facilities-1440x900.png)、[征服详情](evidence/planet-331-combo-conquest-1440x900.png)、[主序星](evidence/planet-331-combo-main-star-1440x900.png)、[红巨星](evidence/planet-331-combo-red-giant-1440x900.png)、[切回装备](evidence/planet-331-combo-equipment-1440x900.png)、[切回 B01](evidence/planet-331-combo-reactor-1440x900.png)、[星图](evidence/planet-331-combo-universe-1440x900.png)八张同版 `1440×900` 原屏；[运行摘要](evidence/planet-331-combo-runtime.txt)记录路由、钱包隐藏及焦点清理。首轮驱动只开放第一星球，直接选主序／红巨导致空场，已修正夹具并重采同名图；**不把那两张空场视为候选缺陷或证据**。现图取前断言对应视觉已准备好。

按 13 第 6 节原尺寸重新看当前八整屏：主序/红巨各自球面热纹及环内受光在共享区域可见，星球普通页签亮重包边较 `dc9` 收敛；固态环、设施抽屉、顶部 y65 接续、退出导航及右侧战斗主体没有本次新增遮盖，切回装备/B01 互斥。此为本共享组合**待原整体审**候选，不以原组十二整屏、六帧或两段约八秒视频代替当前组合动态，也不外推自然建设、六类整圈、全部操作或性能。原审先前对探索船半露的缺陷判断已撤回，本组不据此加修。未合 main。

### 项目内公共控件共源与真实状态展示（待原整体审）

用户已撤掉 Figma 持续制作依赖，公共状态统一直接落在项目原有 `src/ui/bridge_theme.gd`：`public_font()` 缓存 Noto Sans SC 450／既有 embolden，`PUBLIC_STATES` 和内容纵向边距为同一源；`apply_public_button` 负责原生操作键普通／悬浮／按下／悬浮按下／焦点／禁用面与字色，`apply_route_button` 负责导航选中及字色，`apply_top_button` 负责顶栏键，`apply_public_input` 负责输入槽，`public_check` 在同一按钮面上只加原生勾选图标和勾选字色。仍复用已接的漆面图与 SVG，没有新盖板或第二套 Theme。`zone_shell.gd` 和 `main.gd` 已将散落的重复状态 StyleBox/字色循环替换为上述调用；设置动作保留提交／普通角色、宽度及原回调，资源关闭、九路导航、顶栏余额、SpinBox 内嵌 LineEdit 和 stepper 保留原节点。`BridgeTheme.create()` 的通用后备样式仍服务非此公共操作组的控件，不据此给装备／B01／星球内部强盖状态。

Godot 4.7.2 导入、主脚本和当前主场景无脚本／资源错误。受影响实机 [设置普通](evidence/public-source-settings-normal-1440x900.png)、[悬浮取帧](evidence/public-source-settings-hover-1440x900.png)、[焦点](evidence/public-source-settings-focus-1440x900.png)、[受控禁用](evidence/public-source-settings-disabled-1440x900.png)、[资源弹层](evidence/public-source-resources-1440x900.png)均为本公共源码版 `1440×900`，[取帧驱动](evidence/public-source-driver.gd.txt)保留原生设置控件与资源出口。另有直接使用当前 `BridgeTheme` 样式与原生 CheckBox 绘制的 [完整状态展示](evidence/public-control-state-gallery-1440x900.png)及其[驱动](evidence/public-control-state-gallery.gd.txt)，列普通、悬浮、按下、选中、禁用、焦点、提交的真实共享面；这张是**诊断板而非游戏新页面**，可购业务态仍须读装备 `comparison.affordable`／B01 `quote.can_purchase`，板上不造付款结果。按 13 第 6 节看实机普通／焦点／禁用及弹层整屏，公共字底、勾选、输入、导航和关闭键未见新遮盖；悬浮自动取帧变化较细，不能由它单独断言所有悬浮／按下原生交互视觉已验收。`331` 星球截图是上一个公共源码提交的组合证据，不冒充这一公共修订后的整体审图；本节仍待原审重新判断，不合 main。

装备原组后来固定 `3916ffbc9e246f07693a633a772536faad982258`，唯一运行差异为 `src/ui/equipment_panel.gd` 四处文本／展示改动；在收到用户退回前该文件已暂取入本地，**该版本未获整版接受**。用户随后决定当前装备信息无需进一步精简，要求停止扩删并保留现有内容；根端核源未见此前所疑的武器新增，不再以等待「下一精简版」作为整体阻塞。当前原组内部目标是未选／已选替换装备时底部升级区的状态一致性，公共组不代改。本地 `3916` 四处改动仍仅为保全的未提交 WIP，是否采用须看原组后续固定交接；该决定不自动推广或丢弃它，也不以其取组合图。当前共享运行提交仍以装备 `9e420e1c` 为已固定基线。

原整体审对已发布 `6e419de7` 的八张同版整屏限定接受星球主体、两种抽屉和公共边界的**已展示静态构图**；跨页控件状态尚未完成。星球原组短交接：`planet_panel.gd::_ready` 将 `_task_button/_crew_button/_facility_button` 交 `_paint_button`，`_rebuild_drawer` 以 `set_pressed_no_signal(_open_section == ...)` 保持页签选中。现普通页签的金属边仍重于公共／装备普通选择，“设施”已选和未选的面色与轮廓区别偏弱，实际画面主要靠展开抽屉才读出选择。请原组在现有绘制源给普通页签降到非主操作层级，并让已选页签仅靠页签自身的持续面色／轮廓即可辨；悬浮、按下、焦点、禁用保持各自原生状态和字底，不对所有内区控件一律削亮，不改星球主体/环/抽屉结构。公共组不代改 `planet_panel.gd`；文稿和共源代码不能代替原组修订后按 13 第 6 节重看整图。星图长名单空白不在这次限定接受内，也不据此擅扩本轮设计。

### 公共状态字底修正（待原整体审）

原审在上一版[状态展示](evidence/public-control-state-gallery-1440x900.png)发现顶键按下深字落深青底、操作键按下／选中浅字落浅灰绿底。根因在同一 `BridgeTheme`：`top_button(pressed/hover_pressed)` 实际仍取深色 `top-control-hover.svg`，但 `apply_top_button` 给深字；`public_button(pressed/selected)` 是浅灰绿漆面，`apply_public_button` 给浅字。本版直接校正实际控件的两组按下／组合态字色，不加样式盖层：顶键按下保持浅字，操作键按下改深字；原生 CheckBox 延用同一操作键状态色。同步重采[状态展示](evidence/public-control-state-gallery-1440x900.png)，现在取真实 `apply_*` 字色，并列出悬停按下组合态；「选中」操作键格仅展示已有 `public_button(selected)` 材质与对应深字，不代表业务可购状态。当前 `9e420` 装备基线下的同版实机[顶键按住](evidence/public-source-top-held-1440x900.png)、[设置操作键按住](evidence/public-source-action-held-1440x900.png)、[普通](evidence/public-source-settings-normal-1440x900.png)、[悬浮](evidence/public-source-settings-hover-1440x900.png)、[焦点](evidence/public-source-settings-focus-1440x900.png)、[禁用](evidence/public-source-settings-disabled-1440x900.png)、[资源弹层](evidence/public-source-resources-1440x900.png)由更新的[主场景取帧驱动](evidence/public-source-driver.gd.txt)生成。Godot 4.7.2 主场景驱动无脚本／资源错误；独立诊断板脚本在退出时有引擎 RID／texture 释放提示，不据此冒称游戏运行错误或全状态验收。按 13 第 6 节原尺寸看本版全状态板与实际受影响整屏，原两处字底碰撞已消失；其他模块内部状态及跨页整体仍待原审，不合 main。

原整体审已亲看 `e20b72f0` 的七张公共实机图及状态板，**限定接受本版公共静态和按住状态**，当前字底、净空无明确退修；本公共源下尚无装备／B01／星球三模块同版组合图，不构成跨页完成。装备两态候选 `304883fb` 与星球页签候选 `ac5d7d55` 仍由各原组受审；取得原审结论后再精确接入，并沿本入口的现有主场景取图路径固定同版跨页证据。当前运行提交仍为装备 `9e420e1c`、B01 `01efbf12`、星球 `331866cc` 加公共 `e20b72f0`；本地 `3916` 装备文件只保全未提交 WIP，不代替固定候选。此时无其他独立公共修正待办，等待上述模块结论，不增加美术微调或复测，不合 main。

### 星球页签 ac5 与公共 e20 同版窄接（待原整体审）

原星球组固定 `ac5d7d5581237f76711cebe92b654e02cd5e686d`，原组证据入口为 [R17 planet-tab-state-source](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)。相对上一星球 `331866cc` 仅 `src/ui/planet_panel.gd` 的页签角色、普通／选中／悬停按下材质与字色变化；以源差异补丁接入，没有取源分支公共壳或其他模块。当前文件与原组源码只差共享宿主原有的 `_layout/_draw` y65 天空和抽屉左背景适配，独立 y90 保留。原组六整屏只能支持其页签/三抽屉本版可见状态的内区静态限定接受；没有独立 hover、hover-selected、按下动态图，不外推这些状态。

以公共 `e20b72f0`、装备固定基线 `9e420e1c`、B01 `01efbf12` 与此星球 `ac5d7d55` 的**同一运行树**，经[固定主场景驱动](evidence/planet-ac5-public-driver.gd.txt)取 [星球普通](evidence/planet-ac5-public-stage4-1440x900.png)、[设施展开](evidence/planet-ac5-public-facilities-1440x900.png)、[征服抽屉](evidence/planet-ac5-public-conquest-1440x900.png)、[主序星](evidence/planet-ac5-public-main-star-1440x900.png)、[红巨星](evidence/planet-ac5-public-red-giant-1440x900.png)、[切回装备](evidence/planet-ac5-public-equipment-1440x900.png)、[切回 B01](evidence/planet-ac5-public-reactor-1440x900.png)、[星图](evidence/planet-ac5-public-universe-1440x900.png)八张 `1440×900` 原屏。驱动断言路由、钱包隐藏、六星受控夹具、主序/红巨准备完成及星球切出焦点；Godot 4.7.2 主场景无脚本／资源错误。按 13 第 6 节原尺寸看本版整屏，设施抽屉中星球主体、顶部 y65 接续及公共导航未见新增遮盖，装备/B01 切回互斥；这仅为已展示静态与接入证据，待原整体审重新判断，不将原组动态图或自然建设、全状态、全星球性能冒充组合结论。

装备 `304883fbde448cd32fa288ae97967e43100209bc` 曾按原审结论复制到本地，**随后用户退回整组平移**，未提交为运行候选、未用于本节截图。本地 `3916` WIP 原字节 SHA256 `2bd2a6a57297a9a8b2de68cafc08013118341a6c64747034f0daa9f45d39207a` 与远端源提交 `3916ffbc` 完全一致，已另存原文件和差异补丁到 `/tmp/equipment-3916-superseded.*`；当前本地 `equipment_panel.gd` 为 `304883` 原组源码 SHA256 `da5ed854f9f96ad0dc26753824a39bdf74cf80099677fc9e62f70629e15b2775` 的**未提交、用户退回待替换 WIP**。这两份均有原组 Git 对象可回取，星球同版取图期间临时使用已固定 `9e420` 并在取后核哈希恢复 `304883` WIP。原装备组继续稳定升级操作锚点，本组不代改、不把旧装备图称作其最终版；待新固定候选再窄接。未合 main。

原整体审亲看 `3cd7295d` 八张原尺寸整屏，**限定接受公共壳与星球已展示静态组合**：星球主体、抽屉、页签、公共导航和区域边界无本版明确阻断。星图内区长名单空白不在接受范围；旧装备 `9e420` 与 B01 `01efbf12` 的切回图仅作路由对照，不代表后续模块最终验收。后续依赖反应堆接替原组交固定候选，再按源差异精确接入；装备结构概念待用户结论，当前退回的 `304` 未提交 WIP 保留不动。不从此结论外推动态、全星球或整游戏，也不以待定候选追加公共改动；未合 main。

### B01 eea 与公共 e20／星球 ac5 同版窄接（待原整体审）

原反应堆组固定源码 `eea1a7e6b31b3078e9299a391d40033115bafec2`，原组入口 `docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md`。相对当前 B01 `01efbf12`，只取 `src/ui/reactor_scene.gd` 的均分、等级、报价、循环数量和独立升级几何，`src/ui/reactor_stage.gd` 与 `assets/ui/reactor/b01/live-material.gdshader` 的凝聚锁定态参数，以及同源 `locked-{idle,active}-console.png` 两张源图及 `.import`；这三份源码与原组 Git blob 逐字一致。两张 PNG SHA256 为 idle `ed8de4b45786caf5e633fd6604dfe2550113de0a94b6c5051ecfa0ad0769dd31`、active `09a358adc2470a0bc71e81da0bce37f70a56d4f7aa9dcdfb3c350d9f19d5df85`。未取源树公共壳、装备、星球或证据目录；公共 `e20b72f0`、星球 `ac5d7d55` 的 y65 接续、资源身份、输入与右侧战斗投影保持原组合。

Godot 4.7.2 必要编辑器导入和本版受影响主场景取图无脚本／资源错误。[四模组跨页驱动](evidence/eea-combo-driver.gd.txt)在同一运行树取 [装备返回对照](evidence/eea-combo-equipment-1440x900.png)、[反应堆普通](evidence/eea-combo-reactor-1440x900.png)、[带载 MAX 报价](evidence/eea-combo-reactor-max-1440x900.png)、[星球返回对照](evidence/eea-combo-planet-1440x900.png)四张 `1440×900` 原屏；受控入账 1000 铀仅为同版报价观察，不改变价格或业务规则。另由[锁定三模组驱动](evidence/eea-locked-combo-driver.gd.txt)以独立临时存档目录取 [三路带载整屏](evidence/eea-combo-reactor-locked-loaded-1440x900.png)：公开 Owner 三路 34/33/33%、100/100，凝聚未开放、shader 凝聚负载 0。旧存档已有凝聚解锁，初次锁定态取图前置断言失败；改用新临时存档后成功，失败运行未作为证据。所有组合图均暂用已固定装备 `9e420` 取帧，随后核哈希恢复本地**未提交、用户退回** `304883` WIP；装备返回图不表示其结构方案获选。

按 13 第 6 节原尺寸看本版五张整屏：右侧新费用层级、并排数量/升级键及当前 752 铀 MAX 报价在金属小面板内可读；本组合未单独取长价状态，不以原组长价图替代。锁定三模组右上晶体设备及下右管路不见残影，公共顶轨/导航、星球页签和战斗区域未见新增遮盖。此为当前共享组合的**待原整体审**静态/必要接入候选；本组合未取真零、三模组连续动态、开放录像或性能。原组后续证据修订 `587cf2f9f99d1cf06d8b3fb8e62c1aef6dd72fa2` 已更正旧 `locked-zero` 误标并补真零，原审确认三模组 0/100 静态可交接，但那是原组图，不冒充本组合图；开放录像/性能仍属原组前版 `00971d36`，不冒充 `eea` 本版。装备结构仍待用户选择，当前旧 `9e420` 只作返回对照；未合 main。

### 整体字体与可见区域 R1（设计对照，未实装）

用户复看后将整体表现优先级收窄到**字体与行间距**：先处理字形、字重、字号、字色、控件文字位置，以及文字墨迹到真实漆面/图标边缘的光学留白；暂不重做所有控件外形。[可切换装备四稿与两模块实机的对照板](evidence/typography-visible-area-r1.html)现在将证据身份分开：装备为原组固定**静态设计** `9c795d6e40367c7f84adca627a7593ca25b529dd` 的 [早2](evidence/equipment-design-9c-01-early-two.png)、[中5](evidence/equipment-design-9c-02-middle-five.png)、[晚8](evidence/equipment-design-9c-03-late-eight.png)、[同槽下拉](evidence/equipment-design-9c-04-local-dropdown.png)，另附带现行 eea 反应堆及 ac5 星球**实机原图**；原组唯一入口为 `docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md`。四张设计图与源 Git PNG 的 SHA256 逐张一致，板内原图未改，只用页面排版提供文字建议。便于原整体审扫视的固定板视图为 [早2](evidence/typography-visible-area-r1-equipment-early.png)、[中5](evidence/typography-visible-area-r1-equipment-middle.png)、[晚8](evidence/typography-visible-area-r1-equipment.png)、[同槽下拉](evidence/typography-visible-area-r1-equipment-dropdown.png)、[反应堆](evidence/typography-visible-area-r1-reactor.png)、[星球](evidence/typography-visible-area-r1-planet.png)。旧 `9e420` 装备运行图只留在板内“旧装备实机”切页作公共顶轨/旧背景可见区历史测量，**不是当前逐槽目标**；静态新稿的米色顶带也不是已实施公共壳。逐槽结构获用户认可，但原装备审已退回 `9c` 表现：密集行即使上下等距仍挤，失败原因贴底且与普通单费行节奏不一致；四稿保留为待修对照，不能称通过或误称游戏实机。星球 `ac5` 虽有先前静态接入限定接受，用户现已退回整体品质方向，仍只作当前接入基线；原星球组继续按既有概念重做主体。

绘制归属与可见边界已核：`main.gd::_draw` 的 `#071423` 只是底色，x0–808 被模块不透明内景覆盖，战场被 `SubViewport` 覆盖；`zone_shell.gd::_draw` 才画公共顶轨 y0–65（装备 y0–85）、导航与战斗两侧各 47.875px 预留暗带。装备内景 y85–685 和工作台 y685–900 属装备原组，B01 的 `SubViewportContainer` 从 y65 到 900 属反应堆原组，星球共享 `_visual` 从 y65 到 900、抽屉左背景也属星球原组。有效战斗投影 x855.875–1392.125、宽 536.25、高 900、scale 0.9375 不压缩。旧背景被遮挡问题保留为整体待办；本版不拿不可见的 `main` 底色做新底板，不在模块背景上另叠场景，也不抢占字体优先级。

现行文字源是 `BridgeTheme.public_font()` 的 Noto Sans SC 450 + embolden 0.8、公共顶标题 20/余额 16/导航 12，装备与 B01 各自使用 Noto 的 400/500/600 变体，星球 Theme 默认字号 17。拟议优先用正式 Noto Sans SC 的 400/500/600 真权重收敛公共 `BridgeTheme`，减少合成加粗；**尚未改运行字形**。公共角色建议页面身份 20–22/600、资源 16/500、导航 13–14/500、执行 17–18/600；模块主数值依空间约 16–29/600，不强制三场景相同字号，费用/说明 14–17/400–500。状态字色沿已修的浅面深字/深面浅字关系。供装备原组按最新结构引用：槽身份 16/600、属性墨迹约 17–18/600、费用/拒绝原因 14–15/500、同槽下拉候选 16/600 与状态 14–15/500；原稿 87px 行距、x332–788 台体为设计几何，`ink-spacing.json` 在导出 Noto Sans CJK SC 下量了 23 行属性墨迹到可见名称下缘/费用上缘约 2.6–5.5px 且两侧近似对称；**这只是测量，已被原审判为密集状态净空不足，绝非目标值或通过值**。装备原组须把普通单费行与多费、失败原因行放在同页实看：原因不能贴可见底边，属性主值、费用图标/金额、原因及购买键要有可辨的行内节奏；必要时由原组调整本槽纵向组织，不能靠缩字或等距数据证明解决。正式 Noto 上还须复核攻击力、长价、双材料、下拉和禁用字底的真实墨迹与面层边缘，不以 Rect/参数相等或把所有模块强制同号判通过；装备槽内由原组落实，公共组只维护共同角色标准。此板是可审设计判断，原装备返修/星球后续固定及整体实机视觉仍待分别审核，不能宣称字体品质已改善或组合最终完成；未合 main。

### 跨模块字体改后画面对照 R2（设计预览，未实装）

[可切换改前／改后整屏及文字局部的 R2 对照板](evidence/typography-r2-visual-comparison.html)已实际输出三页固定板：[装备](evidence/typography-r2-board-equipment.png)、[反应堆](evidence/typography-r2-board-reactor.png)、[星球](evidence/typography-r2-board-planet.png)。每页左右均是完整画面，局部只放大字与可见边缘关系；可以分别打开原尺寸改后图：[装备](evidence/typography-r2-equipment-after.png)、[反应堆](evidence/typography-r2-reactor-after.png)、[星球](evidence/typography-r2-planet-after.png)。**所有改后图都是字体设计预览，不是 Godot 实机，也不是模块内部已落实。**

装备改前取原组最新固定静态稿 `56e4cc1827eb95e87aa82999a075b952de0aa0bc` 的晚8原图（本地[同字节副本](evidence/typography-r2-equipment-before.png)，SHA256 `a5ed268d72953d5db83efffe3017badfee42cf700b71da8c88491121731350d9`）；其四稿及唯一原入口仍为 `docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md`。新稿保留逐槽、舰体、战场与所有目标位置，已由原组把晚期首条双费／原因行扩为108px，其余普通行84px；本设计预览只在该固定 [SVG 派生稿](evidence/typography-r2-equipment-after.svg)内把身份、主值、费用、拒绝原因应用项目 `assets/fonts/NotoSansSC.ttf` 的500／600字重及角色字色，渲染为改后全图。没有替原组再扩行、移动按钮、改业务文案或将 9c 已退回的2.6–5.5px等距当合格目标。原组须在普通单费／多费／失败原因同页继续核墨迹与可见底边，`56e` 表现仍待原审，不因本板通过。

反应堆、星球改前是本组合已固定的 eea／ac5 实机原图；改后通过[项目 Noto 公共字区预览源](evidence/typography-r2-public-preview.html)在**原图上只覆字**：公共标题21/600、资源16/500、导航13/500，对照同屏层级。模块内区、战斗投影与原状态图像未变；局部覆字拼接边缘只服务字体判断，**不是拟议控件漆面或实际项目截图**，不能用它宣称公共质感、星球主体或反应堆完整视觉通过。ac5 星球仍是用户品质退回的历史接入基线；旧9e装备运行图不再作为新逐槽目标。公共字体若实施应在原 `BridgeTheme` 共源替换，不在旧字上叠新控件；装备／反应堆／星球内字由各原组负责。背景被挡及控件外形待办未在此图实施。

### 装备 ade5 固定槽位与同高状态的字体改后对照 R3（静态设计预览）

原组新固定设计 `ade5c66019c3b630a2425ae37b73e9275f87a192` 相对 R2 使用的 `56e4cc18` **影响改后图**：03 晚8把各槽 `Lv` 从身份框外收回框内，并调其箭头／字的位置（原图差异包围约 x556–659、y168–811）；新增 05 可购／不足对照让普通槽维持84px行高，把“升级／铁不足”置于同一头部预算内，支付状态变化不推后续槽。R2 保留为旧源历史对照，不能当最新版改后画面。

[最新 R3 可切换改前／改后整屏与局部板](evidence/typography-r3-visual-comparison.html)已从 ade5 两份固定 SVG 分别输出：[03 晚8板](evidence/typography-r3-board-equipment.png)、[05 同高板](evidence/typography-r3-board-equipment_05.png)，另保留[反应堆](evidence/typography-r3-board-reactor.png)、[星球](evidence/typography-r3-board-planet.png)公共字区对照。03、05 的 1440×900 改前原图分别为[03](evidence/typography-r3-equipment-03-before.png)／[05](evidence/typography-r3-equipment-05-before.png)，与原组 PNG 字节一致，SHA256 分别 `d14e74655f35da2179ba4af0970de204a69dce5d92eb8bad28f4de1cd0479a78`／`c7e1243262b7401b99ab8412f650dede6de207e0418bc1f9724240adfacf3ddc`。改后[03](evidence/typography-r3-equipment-03-after.png)／[05](evidence/typography-r3-equipment-05-after.png)由可追溯的[03 SVG](evidence/typography-r3-equipment-03-after.svg)／[05 SVG](evidence/typography-r3-equipment-05-after.svg)用项目 `NotoSansSC.ttf` 渲染，**实际改变**身份／框内等级／主数值／费用／状态的500或600字重与角色字色，保持普通84px行名称／主值原锚点，让费用文字与资源图标成组下移3px（不动行高／两键），为主值—费用留出实际墨迹净空；像素变化限定在两图 x351–755、y166–855 的装备工作台文字范围，整屏尺寸、槽位、按钮、舰体和战斗保持。局部板把密集双费行与普通单费行、以及05不足原因与可购同高行放在同屏实看；**字体改后不自动证明密集行、长原因或旧稿光学净空已通过**，原组仍须以原审新结论决定后续表现。

反应堆与星球 R3 板沿用 R2 的公共覆字范围，但以[独立 R3 覆字预览源](evidence/typography-r3-public-preview.html)重导[反应堆](evidence/typography-r3-reactor-after.png)与[星球](evidence/typography-r3-planet-after.png)全图并校正标题中心；当前实机原图及模块内部未改，覆字边缘不代表公共材质。`ade5` 四稿及05都是原组**静态设计**，当前原审中，非游戏实施或用户认可；装备运行 WIP 保全，公共 `BridgeTheme`／模块运行文件未改，未合 main。

R2 首次字体预览经原整体审退修：曾把深色分组条“武器 · 5／防御 · 3”误作浅面槽身份改为深字，且公共标题覆字光学中心约 x112、偏离铭牌内面中心约 x92。现行 R3 **已按真实面层角色修正**：深面分组字保持源稿浅字 `#eef0df`，浅面槽身份才使用深墨；03／05 两张改后图及对应整板已重导，实看防御分组和状态字底。公共标题预览改以 x93 为容器中心；从当前反应堆整屏明亮字形墨迹像素核到改前中心 x91.5、改后 x92.5，避免只按控件 Rect 对齐。R2 图片保留为退修历史，不再作当前字色／标题位置目标；当前 R3 仍是**设计预览非实机**，原审是否接受改稿仍待其当前整图判断。

R3 原审退修又发现两处连带问题：①预览把全部文本强制设为 `NotoSansSC.ttf`，但该字体缺 `⌄`（U+2304），导致8个槽位的下拉箭头全消失；②普通行主值上移后紧贴名称框下缘，没有形成名称／属性／费用的完整节奏。当前 ade5 03／05改后 SVG 已让箭头保留原字符并用 `Noto Sans Symbols` 字形渲染（仅静态导出字体回退，不新增或改运行图标），恢复8个可展开入口；撤销主值上移，保留名称／Lv／箭头及主值原锚点，把普通84px行费用文字**连同资源图标**成组下移3px。右上比较／状态与右下数量循环／独立购买两键仍在原位，03密集108px与05同高84px两态不变。该3px只为当前画面内整行节奏预览，**不是跨模块固定参数**；仍须按完整行与实际面层由原审判断，不能把箭头／净空单项消除宣称整体通过。反应堆底台的等级、比例、费用和提示由反应堆原组，星球页签／抽屉标题、数值与费用由星球原组；公共组已在R3给顶轨／资源／导航真实覆字对照，仅把角色与深浅字底、可见节奏交各原组消费，须各组在自己的新固定实图回看，当前板**不覆盖模块内字体统一**。

### 旧 ade5 整页适配 WIP 保全（已被 7c 新源取代）

[旧 R4 整页对照板](evidence/typography-r4-full-page.html)与其五态改后 SVG/PNG、B01 四路舞台两侧[边缘预览](evidence/typography-r4-reactor-edge.png)是在 `ade5c660` 尚为最新固定源时制作的**过程稿**。装备改后稿以实际公共装备顶带代替静态米色占位，并在原逐槽结构内对齐文字、图标、费用与两键；反应堆边缘稿仅示意现有舞台图层向宿主底色自然收口，不是新框或运行实现。现原装备组已给 `7c8d57d17a6bd1a8020ad03c9124fcf46165a8a5` 七态整页排版，**R4 装备部分立即退为历史，不得再当当前共享对齐源或用户可审候选**；R4 的反应堆四路图也不得外推1/2/3路真实解锁。后续完整组合以7c模块区域 `[0,85,808,815]`、当前公共顶带及反应堆原组待固定的1/2/3/4状态为准。运行装备 WIP 与其他模块源码未改。

### 当前 7c 装备整页与 B01 边界／共同材质 R5（进行中，非验收稿）

用户已认可逐槽操作结构和字体方向，但退回了整页布局及装备／反应堆不似同一游戏的跨页表现；反应堆舞台左右截断、可见旧背景和均分／1–4路真实状态亦在同一整体任务。装备原组新固定 `7c8d57d17a6bd1a8020ad03c9124fcf46165a8a5` 是**当前唯一装备内区排版源**，原入口 `docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md`。其七态已经在模块区域 `[0,85,808,815]` 重排连续工作台、行内名称／Lv／下拉、收益、费用、状态与两键；仍原审中，材质与背景尚未完成。前文 ade5/R3/R4 装备改后图皆为历史过程，不再消费其槽内坐标或拿其当最新版交用户。

[当前 R5 七态与 B01 可切换完整整屏板](evidence/typography-r5-current-assembly.html)固定了原组七张静态源图与当前公共壳的视觉关系；便于扫视的[早2](evidence/typography-r5-board-01.png)、[晚8](evidence/typography-r5-board-03.png)、[可购／不足](evidence/typography-r5-board-05.png)、[换装接纳](evidence/typography-r5-board-06.png)、[按需比较](evidence/typography-r5-board-07.png)和[B01四路](evidence/typography-r5-board-reactor.png)板均已输出。装备 03/05 的[原组同字节源](evidence/typography-r5-equipment-03-source.png)／[05源](evidence/typography-r5-equipment-05-source.png) SHA256 为 `33ed3a08d603be7c3e41d77b94d2a3cd33dbdc036b78244fe03b28fce4a89616`／`f6431bff585540f2a16ddde76e17b34dde627d1d727b4f676cb6811d084c92d6`；其余五态也取同一7c Git对象。[合成源](evidence/typography-r5-public-compose.html)只用现行公共装备实机图的 x0–808、y0–85 顶带**替换**静态稿原米色占位，未叠新运行控件；01/03/05/06/07 的合成图 y≥85 与原组源图逐像素一致。余额来自旧公共实机，**仅作字体、材质和页面关系参照，不是七个静态样例各自的同一经济存档，更不是运行逐槽已实现**。

实际绘制／占用诊断：`main.gd` 的底色在模块不透明背景后不可见，不能在它上面再加一层“新背景”解决问题。7c晚8机库的可见主景仅左侧约 x0–332，工作台 x332–788 已占右半，右 x808 起仍是原战斗投影；早期2槽台体更短，仍可看到完整机库余量。装备原组继续在**已可见的舰船/工作台区域**适配材质和背景，不再把被工作台盖住的旧全幅背景当作主要表现。B01 `reactor_scene.gd` 在 `(0,65)` 安装 `808×835` 的 `SubViewportContainer`，`reactor_stage.gd::_draw` 把 `b01/idle-console.png` 整幅绘至 `(0,0,808,835)`；该原资产左右装置在自身边缘即被截，容器再裁到 x0/808，因此左右到宿主暗面／导航处直接断。现有[四路25%均分真实组合整图](evidence/eea-combo-reactor-max-1440x900.png)与[原舞台图层两侧收口设计预览](evidence/typography-r4-reactor-edge.png)并排可见：预览只在背景源层两侧向宿主暗色收束，中央核心、下控制台、均分键、公共导航和右战场保持；**不是新遮框或运行实现**。最终须由反应堆原组在已有舞台资产／着色器完成真正边缘终止与1/2/3/4路真实解锁布局，再由整体组接同版整屏。当前四路图不能证明早期1/2/3路，旧均分按钮可见不等于所有状态完成。用户提出初开仅炼铁一路，但Excel／导出／Owner是否有该自然开放条件仍由原反应堆组核实；此前“仅3/4路可达”不得用来省去少模块视觉，**受控1/2路图与自然流程必须分开标注**。1/2/3/4路的背景空位、实际分配／均分控件与左右接续均为整体设计覆盖要求，当前不自行更改解锁业务或宣称1路已可自然到达。

跨模块视觉角色交接供根端转原组：公共组保持现 `BridgeTheme`／`zone_shell` 顶带、资源、导航、可见深海军蓝结构及原输入/战斗边界；不在模块上再叠主题。装备组以7c逐槽结构为准，在原 `equipment_panel.gd`／工作台材质源把浅色操作承托、深蓝结构、资源原色、普通／悬浮／按下／禁用字底做成同族；当前7c静态按钮与槽面偏平，须对照B01现有漆面厚度与主次，但八个逐槽购买不应一律发同等强金光。反应堆组保留核心舱强主体，以原 `reactor_stage.gd`／`b01/*-console.png` 与 `live-material.gdshader` 完成左右背景本层收边，并给真实1/2/3/4路及均分后操作整图；控制台主执行暖金、数量/次操作深蓝、禁用冷面，与装备可按操作角色不同强度共用材质语言。两组需把名称、主值、费用、状态与执行键在**真实完整页**重看，不把共同色表/字体参数当视觉统一已完成。当前缺装备材质／背景最终固定源、反应堆早期1/2/3/4与边缘固定源；本节和R5图只能供继续制作/协调，**不是可验收的最终完整组合**。运行代码、业务和战场空间未动，未合 main。

### a1 同台滚动后的整页组织 R7（设计过程稿，继续制作）

装备原组新固定 `a1a13a9902ef2b8cc7ce743bcc6b57d3862861c6` 取代7c作**当前内区结构参照**：早期工作台 x332–788/y320–615；中晚台顶 y280，晚期台底 y844、视口 y314–837，03顶端与08底端是**同一台滚动**而非两张台。八张原组整屏及滚动为静态设计，**原审已退回整体表现**，滚动未实装、整页尚未验收。此前试着沿7c移动身份牌/调整源背景的[早2](evidence/whole-page-r6-01-early-two.png)／[晚8](evidence/whole-page-r6-03-late-eight.png)由[可复现源](evidence/whole-page-r6-build.py)保全为已过时的过程稿，**不能拿来覆盖a1的滚动空间方案**。

先按a1**真实可见区**绘制的R7[早2](evidence/whole-page-r7-01-early-two.png)、[中5](evidence/whole-page-r7-02-middle-five.png)、[晚8顶端](evidence/whole-page-r7-03-late-eight.png)、[晚8底端](evidence/whole-page-r7-08-late-scroll-bottom.png)由[生成源](evidence/whole-page-r7-build.py)保全为过程稿；它还沿用a1晚首屏把防御1裁在底边的523px视口，**当前不再作为滚动目标**。公共装备顶带用既有组合实图的 x0–808/y0–85 **替换**原组米色占位。余额来自公共实机图，与设计样例非同一经济存档；这些图是静态设计，非当前游戏实机。

原装备审已退回a1：中晚船台成组与露背景有改善，但早期仍三块散，浅台与机库/战斗/反应堆的共同材质和边缘未闭合，晚首屏防御1残行且滚动提示弱。整体组进一步在[改后R8早2](evidence/whole-page-r8-01-early-two.png)、[中5](evidence/whole-page-r8-02-middle-five.png)、[晚8顶端](evidence/whole-page-r8-03-late-eight.png)、[晚8底端](evidence/whole-page-r8-08-late-scroll-bottom.png)四张1440×900完整设计图及[生成源](evidence/whole-page-r8-build.py)中，仍从a1固定SVG逐版取结构：早期只重取**原机库源景**视窗，让露出的停泊盘在左侧舰体下而非被右台遮住；同一舰船身份牌距舰体上缘11px；原工作台深蓝结构边、冷白操作面和原源景色阶按角色调整。没有添加工作台外的新底板、重复身份控件或战场画面。早期身份/舰体/台面由原场景连续承载，中晚沿同一舰体—台面关系；但这仍是需原装备组在其真实源适配的**设计方向，非用户验收成品**。

R8晚期滚动设计把原523px视口改为462px，初始停位恰好完整露五条武器，**不再露出半条防御1**；底端停位按原行高整体滚动294px，完整露武器4/5与防御1–3，下方22px自然收边。原台体随视口缩为503px总高，舰体和机库多露61px；同一台顶给出“↓ 防御还有3槽／↑ 返回武器”弱提示，侧轨用同族暖金标示当前位置。名称下拉、费用、两键和原行宽/行高/顺序不变。这个**静态停位**不能证明连续滚动中被裁半行不接输入：交原装备组在运行实现中采用行锚停位、仅完整可见目标可聚焦/接输入、滚动/弹层的焦点及底边剪裁一起验证；若需要自由滚动，则其半露行必须有清楚禁触/焦点回收语义，不能把本图当已经解决。a1滚动尚未实装，本组未改业务/运行。

R8四图已原尺寸实际查看：比a1更清楚地把早期舰体落在左可见停泊盘，晚期两停位没有悬在边缘的半行；但装备台面依旧保留原组平面绘制，B01的厚漆与边光尚未真正落到其内区。装备组继续以a1逐槽/同台为唯一结构源，在原台体/机库资产中做共同材质与边缘，不能把R8当新独立结构分支或在原面层上叠一层框；整体组以当前公共顶轨、导航、资源身份为固定共享角色，待原组回固定源后再审实机完整页与B01。R8是**可见的中间组织稿，未达到最终跨页同族品质**，不交用户验收。

反应堆当前四路均分[真实组合图](evidence/eea-combo-reactor-max-1440x900.png)可见左侧 x0–24 的设备和右 x780–808 的舱景在原舞台图边界戛然而止，下方台面也直接贴 x0/x808。`reactor_scene` 的舞台仍是 x0–808/y65–900 的 `SubViewport`，`reactor_stage.gd::_draw` 把原1187×1326的 `b01/idle-console.png` 拉满808×835；着色器 `live-material.gdshader` 在 `uv.y≥0.58` 直接输出 idle 台面，所以上景淡边不能修下台端。收边须落在**四张同坐标** idle/active/locked-idle/locked-active 原舞台图及相关mask/shader范围，左边终止机械透视、右边自然接公共导航窄脊，不在宿主之上再盖装饰边板。旧[收束预览](evidence/typography-r4-reactor-edge.png)只说明上景源层过渡，尚不能解决下台面的完整边端，不能称成品。反应堆组核Excel/导出/Owner自然解锁；用户预期初开炼铁与现事实核查分开，整体视觉仍须覆盖**受控1/2/3/4路**及真实均分操作图，受控图不得写成自然流程可达，更不得由整体组改解锁规则。

新核出的装备背景归属：原 `assets/ui/equipment/hangar/hangar-console.png` 为1188×1324，**y≈840–1324 自带同源双面控制台**；a1 SVG 却以 `viewBox="0 0 1188 845"` 仅取上部机库，把原承载面几乎全裁掉，再在右侧另画平面逐槽工作台。这解释了「旧背景被遮住／页面像三块拼贴」的实源关系，不能只给旧台面加一圈厚漆框。R8把早期可见停泊盘重取、晚期完整行视口理清，但尚未把机库、舰体、工作台画成一体：后续由装备原组以其**唯一** a1 逐槽源决定保留/重绘哪一个承载面，移除废弃的另一套背景/台面，整体组按当前公共顶带与B01共同材质角色审完整整屏，不另造第二套机库。用户提供的参考只说明整页一体感，不要求模仿深色空底或新增常驻候选页。船上仅关联**已有武器模型与槽位**，防御设备不硬加模型、引导线或指船身；装备组实现武器关联，整体组检视其可见占用与阅读顺序，不改业务或舰体模型。曾试现有 `painted-console-shell.png` 九切作台体替换，原尺寸图的标题与边缘不成立，未作为候选，不得回贴叠层。

把旧机库图全高1324直接放回 a1 的原尺寸试验又确认：旧双面台会在 y≈630–900 露出，现逐槽台 y280–783 压其右半，底下残留两块无内容旧面，页面更碎。因此**不能机械恢复原图底部**；需在装备原组唯一场景源里，为 a1 右侧高台画与左停泊位共用透视/材质的实际承托，旧双面台从最终可见背景中退出，或由原组提出同等完整的单承载替换。早期2槽仍可保留短台与完整停泊盘，晚期同台视口维持已认可逐槽读序；武器关联只占船体真实已有模型位置，不借背景旧面加伪控件。此处是已发生的失败对照及明确资产交接，**不是已完成的新背景素材**。

反应堆边端另给原组一张[源素材结束方式研究图](evidence/b01-edge-endcap-study.png)：以现 `b01/idle-console.png` 实际本地原图为编辑参照，ImageGen 输出1188×1324，左外机械结构与右盾舱都在画布内收成完整透视，下方金白台面拥有两端端盖，不另盖导航框；中心核、四设备和空的深蓝控制井仍在。但生成稿重绘了若干中心像素，原图为1187×1326，其原SHA256为 `e8686944a2477c9ed6837be216c40d4456c7cecd077f623cca030f3fe51f46bb`，研究稿SHA256为 `1bb6200066b01dfa1d00edcbccb6a2ecfba1af70e0c9f1285f846fc0a227e4db`。**这只是外观方向，不是可直接替换的运行贴图**：四张图、效果/模块/管路mask、shader采样坐标须由反应堆原组在同一几何下适配；也尚未合成当前1440×900公共导航与1/2/3/4状态，不可冒充同版组合视觉通过。整体组待固定运行源再核左边、x808右交界、下台端与均分控件全屏。

装备可见背景亦做了**一张原图编辑研究**：原组机库图1188×1324经 ImageGen 得到[单一承托背景](evidence/hangar-single-support-study.png)（[提示与来源](evidence/hangar-single-support-study-prompt.txt)），移除底部双空台，在房间右侧用同透视墙/地轨长出深蓝＋冷白承托、左停泊盘保持。以[构图源](evidence/whole-page-r11-build.py)把该背景**替换**a1自含SVG的 `asset1`，原a1逐槽、船、下拉、数量/购买、公共顶轨和右战斗投影保持，输出[早2](evidence/whole-page-r11-01-early-two.png)、[中5](evidence/whole-page-r11-02-middle-five.png)、[晚8顶端](evidence/whole-page-r11-03-late-eight.png)、[晚8底端](evidence/whole-page-r11-08-late-scroll-bottom.png)四张1440×900静态整页。早期右侧台体下的实际承托和左盘已由同一地轨连接；晚期支持架主要在台背/右边露出，完整行视口仍沿R8。四张均已原尺寸实看，但**浅色逐槽台仍是a1平涂面且压住大部分支架**，所以一体感/共同材质仍未真正完成；生成图的机械细节也与原资产不逐像素一致，不能直接替换原组最终背景，更不能冒充实机或用户验收。原装备组若采用此方向，应在唯一a1源中联合绘制/实现台体和背景，清退旧底部双台，不在旧台上再盖新层。整体组在其固定版回来后按相同早/中/晚+滚动底端的整张实图检验与B01的材质主次和公共边界。

当前独立待办与依赖：①整体组继续用a1同台滚动源审装备早/中/晚完整页的视觉层级、字体光学净空与公共顶轨关系，收到装备组材质/背景固定版后作当前同版实机；②装备组处理其内区可见机库、台体漆面、逐槽真实运行和R8停位/焦点/边缘交接；③反应堆组给原舞台左右边端、真均分与1/2/3/4路受控固定图/源，整体组接后审公共交界及与装备的同族主次；④公共层现 `BridgeTheme`／资源/导航保持共源，若当前组合实图指出其独立缺陷，再在原控件上替换修正，不新增遮层。星球当前旧ac5只是用户品质退回的接入基线，待其组新版后同版复核。已交的R5/R6/R7/R8板与边缘预览均为过程图，**不是等待用户选择的完成稿**；未合 main，未启动新实机复测或业务改动。
### b57 反应堆少路数与共享组合接入（待整体复审）

当前运行基线沿用本分支公共壳、星球 `ac5d7d55` 和反应堆 `eea1a7e6` 的宿主接口；本次从原组 `implement/reactor-centered-godot@b57b7089073a0a67d0a8adba419733426498b4eb` 精确取 `src/ui/reactor_stage.gd`、`assets/ui/reactor/b01/live-material.gdshader`、四张 `one/two-{idle,active}-console.png` 及各自 `.import`。`reactor_scene.gd`、公共壳、资源源、装备、星球、输入与战斗投影未从原组覆盖。舞台按公开 Owner 启用路数选择 1/2 受控图，3/4 保持原图；shader 在最终输出端收左右 24px 色边。没有把先前生成的 B01 端部研究图直接作运行素材。

[当前共享组合驱动](evidence/b57-combo-driver.gd.txt)在同一 Godot 4.7.2/1440×900 主场景取 [装备返回对照](evidence/b57-combo-equipment-1440x900.png)、[反应堆普通](evidence/b57-combo-reactor-1440x900.png)、[反应堆 MAX](evidence/b57-combo-reactor-max-1440x900.png)、[星球返回对照](evidence/b57-combo-planet-1440x900.png)。[受控少路数驱动](evidence/b57-controlled-combo-driver.gd.txt)从原组驱动只适配共享导航与输出路径，在同版共享主场景取 1 路[零](evidence/b57-controlled-combo-1-zero.png)／[均分](evidence/b57-controlled-combo-1-active.png)／[拖动](evidence/b57-controlled-combo-1-manual.png)和 2 路[零](evidence/b57-controlled-combo-2-zero.png)／[均分](evidence/b57-controlled-combo-2-active.png)／[拖动](evidence/b57-controlled-combo-2-manual.png)。[三路受控驱动](evidence/b57-controlled-three-driver.gd.txt)另取同版[零态](evidence/b57-controlled-combo-3-zero.png)／[均分](evidence/b57-controlled-combo-3-active.png)，公开 Owner 三路为 34/33/33%、凝聚未开放。受控 Owner 图只证少路数视觉与输入接入，**不等于 1/2 路可由当前自然解锁流程到达**。原组的完整动态／性能也不冒充此共享组合证据。Godot 4.7.2 导入完成，组合驱动四页路由与受控 1/2 零／带载／拖动断言通过；首次运行因未注入已有原生扩展启动失败，补入既有 `SPACE_IDLE_NATIVE_EXTENSION` 后重跑成功，失败运行未作证据。

本次当前实图可见 B01 左外缘仍以舞台图直接到屏边，右边到导航列为直切；24px shader 收边改善纹理端部，但不能仅据此宣称与公共宿主的完整材质衔接已解决。原组需消费共享 `x=0/808`、顶轨 `y=65` 和导航 `x=808–855` 的实际收边关系，保留四张原舞台图及 1/2 图与 effect/module mask 对齐；整体设计仍需连同装备当前 `04149eae` 静态设计的共同承托／背景一起审。b57 初次图曾误读工作区里用户已退回的 304 历史 WIP；后续已备份 WIP 字节／补丁／哈希，临时恢复 HEAD 已提交 `equipment_panel.gd` 后只重取本组四页图，随后按 SHA256 `da5ed854f9f96ad0dc26753824a39bdf74cf80099677fc9e62f70629e15b2775` 原样还原 WIP。当前 b57 图的装备页可由固定运行源复现，但仍是旧 9e 装备返回对照，**不是最新 041 静态设计已运行**。星球 ac5 亦为用户品质退回的接入基线。当前截图只供 13§6 的同版整体复审，不能外推组合验收。

### 装备 041 当前结构的整页承托设计 R13（静态设计，待整体判断）

原装备组 `art/equipment-materials-main-20261029@04149eae` 的 `inline-slot-workbench-concept` 29／30／31／32 是本次**唯一槽行和舰体结构源**；该组 29–41 的逐槽与已有武器关联方向成立，但早期舰名牌／小船／工作台分散、台体缺承托、旧底景与公共壳拼接仍被原审退回。前文 a1/R11 以及未固定的 a1/R12 仅是过时过程，不覆盖 041。本版 [可复现的静态 SVG 合成源](evidence/whole-page-r13-build.py)只从 Git 精确读取 041 四张 SVG，把公共顶轨、导航和战场替换成当前 [R13 原像素参照](evidence/r13-public-reference-1440x900.png)的原像素，模块背景在 x0–808、y65–900 接到顶轨，舰体／现有武器模型／逐槽名称下拉、比较、属性、报价、数量与执行键保留 041 原节点与原位置。该右战场参照只是当前组合画面，不代表静态装备稿已经实装。

可见改后整页：[早2](evidence/whole-page-r13-29-compact-scene-early.png)、[中5](evidence/whole-page-r13-30-compact-scene-middle.png)、[晚8顶](evidence/whole-page-r13-31-compact-scene-late.png)、[晚8底](evidence/whole-page-r13-32-compact-scene-bottom.png)，均为 `1440×900` **设计图，非 Godot 实机**。单一背景资产 [机库悬臂承托](evidence/hangar-cantilever-support-study.png)取代旧双台背景，物理悬臂自右壁伸到操作台下；[短台漆面](evidence/workbench-short-face-study.png)／[长台漆面](evidence/workbench-tall-face-study.png)在原工作台 x342 左缘取代两块旧平填 backing，原交替浅色行 slab 实际移除，使槽行处于一块连续搪瓷面；没有在旧框上再盖新框。舰名牌仍为原牌但右边延到 x342 与工作台边接触，底边离舰首约 10px。短台外框比原 backing 向上 14px、向下 35px，长台外框向上 14px、向下 24px，均仅为物理包边净空；原操作行／滚动视口／战斗主体未改。源脚本保留四态可重建入口，不用生成式重画舰体或战斗。

原整体审已看 R13 四张，认为材质承托／逐槽字费两键有实质改善，但舰名牌仍像平面说明卡贴金属台框，晚8滚动摘要条横压台内缘；因此 **R13 整页仍退回、不可交用户**，下版需整页重整两处收边，不以局部打勾销项。

交原装备组消费时须以 041 可编辑 SVG 的槽内结构为准，实际运行只替换既有模块背景与工作台原 backing 节点、按上述区域接续公共 `y65` 和 x808 导航；新图不是可直接当运行贴图的整屏。长台顶／底两张仍是静态停位，不证明连续滚动、焦点、裁切或真正换装；需原组在原面板内实现并按真实状态回图。防御保持自身信息操作，不强加船体模型／引导线。跨页最终质感仍须按 13§6 对当前**实机组合**重看，不能把本设计图或 b57 接入图当用户整体验收。

### e8 反应堆连续读面替换 b57 与固定装备来源矫正

原反应堆组 `implement/reactor-centered-godot@e8ec7c447d303e01773d31b8798d6ff630520229` 已替换 b57：相对 b57 仅精确同步 `src/ui/reactor_scene.gd` 的 1／2／3 路原生行位置、`assets/ui/reactor/b01/{one,two,locked}-{idle,active}-console.png` 六张同几何新台面，以及资产 README。原 b57 的 `reactor_stage.gd`、shader、其余 4 路图与 mask 保持；公共壳、装备、星球、资源、战斗与宿主输入不覆盖。当前来源 1／2／3 是连续金属读面而非空行槽，1/2 的可见输入仍为受控 Owner；当前正式自然路径的 3/4 由原组解释，未改解锁事实。

[当前固定装备源的同版跨页驱动](evidence/e8-combo-driver.gd.txt)在 Godot 4.7.2 主场景取 [装备旧源对照](evidence/e8-combo-equipment-1440x900.png)、[反应堆 4 路](evidence/e8-combo-reactor-1440x900.png)、[MAX 报价](evidence/e8-combo-reactor-max-1440x900.png)、[星球旧源对照](evidence/e8-combo-planet-1440x900.png)四张原尺寸整屏；[受控驱动](evidence/e8-controlled-combo-driver.gd.txt)在同一共享宿主另取 1／2／3 路 [零与带载](evidence/e8-controlled-combo-1-active.png)及 1／2 的真实拖动：具体同前缀 `e8-controlled-combo-{1,2,3}-{zero,active}.png` 与 `{1,2}-manual.png`。驱动实际断言 1 路 100%、2 路 50/50、3 路 34/33/33 及 1/2 拖动 Owner 接受。编辑器导入与本次组合脚本无解析／资源错误；未重跑原组完整鼠标、升级、性能矩阵，原组证据不可冒充此版共享组合。当前 1 路整屏连续控制井和右侧升级区在同屏可见；左右 x0/x808 端仍要按公共轨和导航一起审，24px shader 末端收色不等于用户已认可整体接缝。

取图前将未提交 304 装备 WIP 以字节副本和 Git binary patch 保存在 `/tmp/space-idle-runtime472/`，原 SHA256 为 `da5ed854f9f96ad0dc26753824a39bdf74cf80099677fc9e62f70629e15b2775`；临时换入当时 HEAD 已提交装备源，取完 e8 图再恢复，恢复后哈希相同。R13 静态稿原公共像素参照已另存 [固定副本](evidence/r13-public-reference-1440x900.png)（SHA256 `bd1e5d9a9640aa32404f0aaf6f6dde6401fe68b0640ef2d2d2728bcd3f7c5c15`），脚本改指该副本，避免矫正旧 b57 图改变 R13 再现性。装备页仍只是固定旧源，不代表 041 设计运行；星球 ac5 仍为用户品质退回接入基线。本组仅交 e8 当前组合供原整体审，不称最终通过；B01 外缘/公共接续设计与装备 R13 退回项继续。

### 装备 041 R14 整页收边修订（静态设计，待原审）

针对 R13 原审指出的早期平面舰名牌与晚8摘要横条，继续在**同一 041 SVG 源**完成 [R14 可复现源](evidence/whole-page-r14-build.py)：不新增外框，也不改舰体、武器关联、逐槽次序、报价、两键或战斗。原蓝色舰名卡及其冗余武器／防御行被实际移除，舰名变成工作台现有搪瓷顶沿的铭牌文字；机库悬臂仍在台底承托，早中晚不再有悬空说明卡。晚8顶／底的滚动摘要保留“还有哪些槽”的身份语义，但移除压在台内缘的独立深／浅横条：顶端用台面内一行向下提示，底端在台面内用一行向上提示，只有完整原生槽行仍有操作外形。其余原组 041 停位、视口与控制节点不动。

R14 四张 `1440×900` 完整改后页：[早2](evidence/whole-page-r14-29-compact-scene-early.png)、[中5](evidence/whole-page-r14-30-compact-scene-middle.png)、[晚8顶](evidence/whole-page-r14-31-compact-scene-late.png)、[晚8底](evidence/whole-page-r14-32-compact-scene-bottom.png)。这是基于当前公共原像素参照与 041 静态 SVG 的**设计图，不是运行图**。交装备原组时按源脚本删除旧卡／摘要背景节点并重排既有标题／提示文本，不可运行时在旧卡上盖新字；原组仍负责连续滚动、焦点、完整行视口和换装后的真实面板，待真实组合再依 13§6 审整体。

### B01 左右环境端部 R1（同版四路数设计，非运行贴图）

当前 e8 原舞台图在 `x=0` 与 `x=808` 仍把舱室侧景直接裁断，`live-material.gdshader` 最终 24px 收深蓝只是像素淡出，不提供舱室建筑的终止逻辑。作为可给反应堆原组直接消费的**环境源图方向**，[1187×1326 边缘素材研究](evidence/b01-structural-endcap-study.png)从现行四路 idle 原板编辑：让左右外缘的舱壁、立柱与下台端构成向镜头回转的实体结构，右端在公共导航 `x808–855` 前完成物理收口。它不是 UI 柱或新增宿主遮罩。研究图内部被生成工具重绘过，**不能直接替换任何 B01 运行底板**。

[可复现设计合成源](evidence/b01-endcap-r1-build.py)仅取该研究图的左右各 60 屏幕像素、`y65–525` 上段作环境端部示意，其他区域全部取 e8 当版真实共享整屏：[单路](evidence/b01-endcap-r1-one.png)、[双路](evidence/b01-endcap-r1-two.png)、[三路](evidence/b01-endcap-r1-three.png)、[四路](evidence/b01-endcap-r1-four.png)。原尺寸逐像素核对：四图的中间 `x60–747`、战场 `x808–1439`、下台 `y525–899` 与各自 e8 原图完全一致；没有缩放核心、挪用舰船、覆盖均分／升级／费用或假造少路数控件。此合成仍只是**设计比较**，不是现有 shader 的运行表现，更不能拿四路生成边缘当 1／2／3 源图完成。

原反应堆组的准确可消费接口：运行舞台仍 `808×835` 放在共享 `y65`，八张 idle/active 底板均保持 `1187×1326` 与 effect/module/pipe mask 同坐标；研究的 `60px` 屏幕外缘约对应每侧 `88px` 原图，设计只针对原图上部约 `y0–731`，中间 `x88–1098`、下部控制台保持 e8 源像素。请原组在**各自 1／2／3／4 状态的原板层**重画真实结构端，不在 Godot 上叠一个通用边栏或把四路机器漏到少路数；原组需重新核 idle/active 与 24px shader 淡出关系和真实 x0／x808 接缝。公共宿主只保留 y65 顶轨、x808–855 导航及其暗蓝材质，不同时改 B01 内层源。当前 R1 的细边能提示端部方向，但未获整体视觉审认可，不能当最终衔接完成；后续以原组修板同版实机整屏按 13§6 判定。

### B01 端部 R1 退回与 R2 全高结构方向（设计过程，非运行修复）

原整体审退回 R1：两侧只有 `60px`、`y65–525` 的叠影，舱壁／回廊断续，`y525–900` 下台又回到旧直切。R1 脚本确实只在这个上半窄域取边缘图，问题不是 shader 数值微调可解决。R1 四图及脚本只保留历史对照，不再给原组当落地资产。

本轮从现行 `idle-console.png` 完整 `1187×1326` 原板做[全高建筑源板方向](evidence/b01-endcap-r2-full-source-study.png)：侧墙在顶梁、回廊、地坪、下台侧颊之间连续回转，控制台两端作为同一建筑的承托，右端先物理终止再接公共导航。另有[整页情境稿](evidence/b01-endcap-r2-composition-study.png)及[同画幅缩放的 1440×900 设计预览](evidence/b01-endcap-r2-composition-1440x900-design.png)用于判断整间舱室与公共栏、战场的主次；**情境稿原生 1586×992，缩放稿虽为 1440×900，但顶部字形、中心机器及战斗画面均有生成重绘，不能作为当前实机图、像素保真比较或任何可运行源**。全高源板虽恰为 `1187×1326`，中央机器／面板同样被生成重绘，也不能直接覆盖运行板。两图只表达完整实体收边和材质方向；当前 e8 组合仍旧源、未修此项。

原组可消费的源层约束见[端部 R2 几何与状态合同](evidence/b01-endcap-r2-source-contract.json)：绘制须从各自八张原板的原图层完成，按 `808×835` 舞台、顶部 `y65`、导航 `x808–855` 回看整屏；原板四态中央机器、四路布局、下台内信息井、effect/module/pipe mask 的坐标与动态功能保持一致。侧墙所占空间不能只是两侧几十像素半透明纹理，要在上景回廊和下台侧颊形成可识别、连贯的建筑终止；不在公共壳新叠底框。`live-material.gdshader` 当前左右约 `24px` 的色淡出仅处理末端色值，不替代源板建筑收口。原组交 1／2／3／4 idle/active 同尺寸板及必要 mask 后，整体组接入真实组合按 13§6 重看每态整屏；本版 R2 仍为待原审的美术方向，不能称已完成八态或整体通过。

装备现行内区设计源已转为 `art/equipment-materials-main-20261029@e15484ceabfe953605eef132e71b6883a3590bf5` 的 42–62 静态稿：该组舰船、实体台、机库同材质已成立，但原审仍退修早期厚台抢小舰及 `x808` 台架／机库硬止到导航暗带。041 R14 对旧源的静态接受只作历史，不替代 e154、更不代表运行。公共组后续只处理顶轨／导航／区域过渡与跨页主次，装备原组消费其实体台／舰船比例及内区右边缘原素材；不能各自在旧图上再盖一层。当前 e8 真实组合装备仍是已提交旧 9e 源，星球仍为旧 ac5 接入基线，静态 e154 与 R2 均未运行。

### 装备 e154 与公共导航接续研究（静态，待原审／原组）

已从原组固定 `inline-slot-workbench-concept/42-coherent-early.png` 与 44／45 晚期整页核对：其公共顶轨在 `x0–808/y0–85` 是设计上下文，**导航 `x808–855` 仍是一条纯暗带而非当前运行的按钮列**；内区右墙、厚台右支脚均在 `x808` 被截，晚期更明显。因而不能把静态稿的暗带当成已完成的公共衔接。当前 [公共接续情境研究](evidence/e154-public-junction-study.png)和[1440×900 同画幅预览](evidence/e154-public-junction-1440x900-design.png)用现行导航列的角色和深蓝内凹接头作方向：右墙／地坪／工作台支脚在内区自有原素材内形成终止面，导航作为共享暗蓝竖脊紧邻它，而不是在宿主上再盖旧边框。原稿由生成编辑得到 `1586×992`，另作等比整幅输出；文字／舰体／控件像素有重绘，**只判断材质与构图，不是 e154 原图的几何保真修订，更非运行证据**。

可执行分工及**实际节点／文件入口**见[装备 e154 接续合同](evidence/e154-junction-source-contract.json)：原组可编辑生成源是 `inline-slot-workbench-concept/build-design-plates.py`，短／长机库底景分别为 `coherence-assets/hangar-short-carrier.png`／`hangar-tall-carrier.png`，均在生成源以 `x=-27,y=85,width=843.2,height=815` 放入 `x0–808` 裁切域；42／43／44／45 SVG 是实际设计板。公共运行绘制源则是 `zone_shell.gd::_draw`，在 `x808–855` 画导航背与边线，在装备态画 `y0–85` 顶轨。公共组保持真实导航／顶轨／战场投影，不把导航做成机库墙柱，也不在导航上补一层遮墙。装备原组在 e154 自己的底景／台体源内完成 `x≈760–808` 的右墙结构回转、台右支脚与地坪端面，使早期小舰不再被厚台抢主次，晚期实体台能在导航前自行收边。真实素材完成后公共组精确接入并看 2／5／8 与上下滚动停位的 **1440×900 实机**，再判断共享导航和 B01／星球同屏角色；本研究不代原组运行实现，也不据此称整体风格已统一。

### 真实公共几何下的 R3／e154 精确设计对照（非运行）

原审对 R2／e154 生成情境稿只认可建筑收边方向，退回其公共几何和路由身份：生成重绘使顶栏左缩、战场界线移到约 x870、装备选中键错成“供能”。这两张偏移稿只保留历史，**不作落地比例依据**。现用[可复现的源边界装配脚本](evidence/exact-boundary-study-build.py)把真实 e8 同态共享 `1440×900` 图留在原像素：模块 `x0–808`、导航 `x808–855.875`、战斗有效投影 `x855.875–1392.125`（scale `0.9375`）、顶轨 B01 `y0–65`／装备 `y0–85`。逐像素核对四路 B01 图的公共 `x808–1439` 与顶部 `x0–807,y0–64` 完全等于对应原共享实图；装备四图的公共 `x808–1439` 完全等于当前装备路由实图，选中键确为装备。

B01 的[单路](evidence/b01-r3-exact-one.png)、[双路](evidence/b01-r3-exact-two.png)、[三路](evidence/b01-r3-exact-three.png)、[四路](evidence/b01-r3-exact-four.png)四张完整设计图分别引用对应 e8 真实受控整屏及从**同路数各自原板**编辑的 1187×1326 全高建筑素材：[1](evidence/b01-r3-one-source-study.png)、[2](evidence/b01-r3-two-source-study.png)、[3](evidence/b01-r3-three-source-study.png)、4 路沿用上节 R2 源板。中间机器、下台价格／按钮／均分均以真实原屏保持原位置，外侧侧墙／地坪／控制台侧颊作为设计素材贯穿至底。生成素材虽取各路数原板，不等于运行八张 idle/active 板或 mask 已同步；合成边界只服务设计判断，原组要在原板图层绘制，不在 Godot 叠剪裁层。四张设计图仍有局部材质接缝，需原审当前整页判断，不称最终品质或实机通过。

原审发现首版 R3 四图两侧约 30px 旧舱景残条，根因是设计脚本把 `1187×1326` 图像放进 `808×835` SVG rect 时未设 `preserveAspectRatio="none"`，默认 `meet` 仅横铺约 747.5px；这**仅是设计装配失误，不是 Godot 运行问题**。现脚本对原板研究图显式设 `none` 并重出上面四张同路径当前图，保留真实公共区及中心原像素；原尺寸重新看四页，左右残条已消失，端柱与地面进入下台侧颊，均分／报价及四路核心未被边缘素材覆盖。仍需原整体审重新判读整页质感与真正原组 0af 运行板，不凭这处参数修复宣称端部最终通过。

装备 [早2](evidence/e154-source-context-early.png)、[中5](evidence/e154-source-context-middle.png)、[晚8顶](evidence/e154-source-context-late.png)、[晚8底](evidence/e154-source-context-bottom.png)把 **e154 原组 42／43／44／45 的整个 x0–808 模块源像素保持不动**，只换入当前真实装备选中导航与右战场作为公共几何对照。它们准确暴露 e154 右墙／台脚在 x808 原层硬止及早期厚台抢小舰的剩余问题，**不是把上节生成右缘图冒作已修好**。原装备组对短／长 carrier 原素材、工作台右端及小舰／台体主次做完整修订后，公共组再拿同版 2／5／8、上下停位实机检查；连续滚动、焦点、换装仍非本静态对照覆盖。当前运行组合仍旧 9e 装备／e8 反应堆／ac5 星球，公共几何虽准确，设计板不是运行状态。

为把早期厚亮台抢小舰从口头判断变成可见原素材协作，另按 e154 真正的 `hangar-short-carrier.png` 做[低亮薄框／右端内收的同尺寸背景研究](evidence/e154-early-balanced-carrier-study.png)，并用[可复现原 SVG 节点替换源](evidence/e154-early-balanced-build.py)仅把 42 原 SVG 的**唯一**机库背景 image 节点换为该图。原 42 的舰体、武器模型、名称、两槽文字与原生控件所有其它节点保持原位置；背景因新图台沿位置不同，在这个**静态设计预览**中改用 `x=-27,y=50,w=843.2,h=850`、仍裁在 `x0–808/y85–900`，不是悄悄改运行宿主几何。结果见[早2完整 1440×900 改后页](evidence/e154-early-balanced-exact-1440x900.png)：早期台体金边／灯带权重降下来，圆形舰台与小舰较清楚；右墙／台脚自身形成深色端面，真实装备选中导航／战场 `x808–1439` 与现共享图逐像素相同。新背景是生成编辑的设计资产，具体面板边缘仍由原装备组核 42 源与运行目标并重画／替换；它没有推翻逐槽结构，也不是 e154 已获原审新通过、运行滚动或完整跨模块品质通过。中晚期 43–45 没有套用这张短背景，仍以前段源对照等待原组自己的长背景收边。

长背景的右端另以 e154 原 `hangar-tall-carrier.png` 编辑出[同尺寸墙／台脚回转研究](evidence/e154-tall-return-carrier-study.png)，通过[43／44／45 原 SVG 节点替换源](evidence/e154-tall-return-build.py)仅换唯一长背景节点，输出[中5](evidence/e154-tall-return-middle-1440x900.png)、[晚8顶](evidence/e154-tall-return-late-top-1440x900.png)与[晚8底](evidence/e154-tall-return-late-bottom-1440x900.png)。生成图的浅色操作面右端比原图早收，故**仅在设计 SVG**把背景 image 的宽从 `843.2` 调成 `880`（仍 x=-27,y85,h815，clip x0–808），保全原 43／44／45 所有槽行、报价、购买、滚动摘要及舰船节点的原位置。原尺寸实看三页，最右两键／费用仍落浅色面内，右墙和台支脚在导航前形成深色终止；公共 `x808–1439` 与真实装备路由截图逐像素相同。该图不是任意拉宽运行背景的批准，也未验证连续滚动或输入；原装备组须将端面落实到其可运行素材并核 2／5／8 全页、最宽报价和下拉弹层，公共组随后重新整体审。R2 早／中／晚是可讨论的源材质方向而非本版整体通过。

### 原组可直接取用的最小 Git 包与返还件（04:00 交接）

以下仅是已经发布在 `design/clear-zone-host` 的**设计源／边界交接**，不是把该分支整树合进原组，更不是让图证替代运行实现。根端可分别转发精确路径；原组仍按自己的当前固定源审差异，不拿本分支未提交 304 装备 WIP。

| 原组 | 最小取用包与源节点 | 应在原组源内完成／不能动 | 下一份需返还的固定件 |
| --- | --- | --- | --- |
| B01 反应堆 | `evidence/b01-r3-{one,two,three}-source-study.png`、`b01-endcap-r2-full-source-study.png`（4路）；`b01-r3-exact-{one,two,three,four}.png` 对照；`exact-boundary-study-build.py`；`b01-endcap-r2-source-contract.json`。均在本入口相邻 `evidence/`，当前 Git 起点 `e36d452a`。原运行节点为 `src/ui/reactor_stage.gd::_draw` 的 `Rect2(0,0,808,835)`、`show_snapshot` 的路数板选择。 | 在 `assets/ui/reactor/b01/` 的 `one-idle-console.png`／`one-active-console.png`、`two-idle-console.png`／`two-active-console.png`、`locked-idle-console.png`／`locked-active-console.png`、`idle-console.png`／`active-console.png` **八张各自原板**重画顶梁→回廊→地面→下台侧颊；每张保持 `1187×1326` 且 1／2／3／4 机器数、核心/控件位置真实。核同目录 `effect-mask.png`／`module-mask.png`／`pipe-mask.png` 坐标与 `live-material.gdshader` 现末端约 24px 色淡出；需要改 mask/shader 才改，不能在 Godot/宿主叠通用边框，不改 `reactor_scene.gd` 内部操作业务或公共 `zone_shell.gd`。 | 八原板及必要 mask/shader 的 Git SHA、差异清单；真实共享 `1440×900` 的 1／2／3／4 idle/active 代表与均分／升级受影响图证，区分受控解锁、自然流程及性能覆盖。组内动态图不能冒共享组合动态图；整体组按固定候选窄接重审。 |
| 装备 | `evidence/e154-early-balanced-carrier-study.png`＋`e154-early-balanced-build.py`＋早2整页；`e154-tall-return-carrier-study.png`＋`e154-tall-return-build.py`＋中5／晚8顶底整页，当前 Git `d118c4b1`／`be7e3892`／`23819624`。原可编辑节点是 `inline-slot-workbench-concept/build-design-plates.py` 唯一背景 image：短／长 `coherence-assets/hangar-{short,tall}-carrier.png`，原变换 `x=-27,y85,w843.2,h815` 裁 `x0–808`；42／43／44／45 SVG 属原组设计源。 | 在原组**背景与台体原层**处理早期小舰与厚台主次、长短机库右墙/地坪/支脚在 x808 前实体终止；早2研究仅静态 `y50,h850`，中晚研究仅静态 `w880`，需由原组按完整 2／5／8 图核后决定真实资产变换。保留已认可舰上武器关联、逐槽2/5/8读序、费用、数量循环＋购买、候选下拉、原有焦点/输入语义；不加防御船上模型、不在公共导航上盖墙，也不从本分支取未提交 304 或历史 041 R14 当新运行源。 | 原组可运行短／长 carrier、`equipment_panel.gd` 与必需同源素材的固定 SHA／文件清单；同版 2／5／8、晚顶底、最宽费用及下拉的完整整屏，并按原职责给连续滚动停位／焦点／实际换装受影响证据。整体组只精确接固定源并核真实 `x808–855.875` 导航与战场，不宣称本静态稿已运行。 |

公共不得改动的共享边界来自当前 `zone_shell.gd::_draw`：模块 x0–808，导航 x808–855.875，战斗投影有效 x855.875–1392.125（scale 0.9375），B01 顶轨 y0–65，装备顶轨 y0–85。当前组合实机仍是 e8 B01＋旧 9e 装备＋ac5 星球；新 B01／装备材质均未在共享运行组合落地。R3 四态和装备早／中／晚整页已交原整体审，**没有发用户一份已完成可验收稿，也不称等待用户选择**。组合落地、完整视觉统一、反应堆八态真实动态、装备滚动焦点换装持续属未完；其独立源实现须等上述原组固定候选，本组不为等候去重画已送审图或扩独立复测。

### 反应堆 0afc6692 八原板真实共享接入（本版阶段静态视觉可交）

原反应堆组固定 `implement/reactor-centered-godot@0afc66924e39ad0958a01b38f8bacdd09650f274`，本组以现公共 `10dc56f1` 为基准核差异：**仅八张** `assets/ui/reactor/b01/{one-,two-,locked-,无前缀}{idle,active}-console.png` 运行图相对当前 e8 已接源改变；`reactor_stage.gd`、`reactor_scene.gd`、三张 mask、`live-material.gdshader`、公共 `zone_shell.gd` 均无本次源差异。八图逐个按 Git blob 比对与 0af 源一致后精确同步；没有把 R2/R3 设计合成图当运行贴图，也没有盲合反应堆分支。原组 `b01-redesign/README.md` 的 10 整屏和原组驱动仅是其固定源证据，**不代替**以下本组合实图。

Godot **4.7.2** 当前运行树完成导入，主场景按[当前跨页驱动](evidence/r0af-combo-driver.gd.txt)取得同版 [装备返回](evidence/r0af-combo-equipment-1440x900.png)、[四路普通](evidence/r0af-combo-reactor-1440x900.png)、[四路均分／MAX](evidence/r0af-combo-reactor-max-1440x900.png)、[星球返回](evidence/r0af-combo-planet-1440x900.png)四张 `1440×900` 实机整屏；[运行摘要](evidence/r0af-combo-runtime.txt)断言路由互斥、星球钱包隐藏。另按[必要少路数视觉驱动](evidence/r0af-controlled-visual-driver.gd.txt)只取 1／2／3 路各自 [1路零](evidence/r0af-controlled-1-zero-1440x900.png)／[1路带载](evidence/r0af-controlled-1-active-1440x900.png)、[2路零](evidence/r0af-controlled-2-zero-1440x900.png)／[2路带载](evidence/r0af-controlled-2-active-1440x900.png)、[3路零](evidence/r0af-controlled-3-zero-1440x900.png)／[3路带载](evidence/r0af-controlled-3-active-1440x900.png)六张整屏；[摘要](evidence/r0af-controlled-runtime.txt)记录受控 Owner 1=炼铁 100%、2=武器/炼铁 50/50、3=34/33/33，未重复原组鼠标全链或性能矩阵。两次取图均临时用 HEAD **已提交旧 9e 装备源**替换未提交 304 历史 WIP，退出即按 SHA256 `da5ed854f9f96ad0dc26753824a39bdf74cf80099677fc9e62f70629e15b2775` 原样恢复；装备返回图因此可复现但**不是新 e154 静态设计运行**。

按 13§6 原尺寸看本组合 4＋6 整屏：0af 真实左右舱壁、回廊、地坪与下台侧颊在 y65 到底部连续落进模块自身区域，公共 x808 导航/顶轨没有被原板遮住；少路数未露未开放机器，控制井/均分/等级/费用及导航状态可辨，四路 MAX 也未压公共栏。根端转达原整体审已核本版 10 张真实整屏及 0af 源一致性：**B01 当前端部／少路数落位静态视觉可交阶段结果，无明确视觉阻断**；不再将本版端部静态审列为待完成。装备旧 9e 内页、星球旧 ac5 仅返回对照，**不称跨页全组通过**。该受控少路图不证明自然 1/2 路可达、真实鼠标全链、连续动态或严格性能；原组记录的 `27.33/30.40 fps` 是非严格 A/B 的软件渲染短采样，不能报性能通过。本组没有另跑性能，仍待原反应堆组在目标环境／同版条件核。装备新 3946 目前仅静态设计，滚动/焦点/换装尚未运行接入；本候选未合 main。

### 装备 3946 原层端面与公共导航对照（静态，取代旧 e154 接续研究）

原装备组固定 `art/equipment-materials-main-20261029@3946a1b8cf81122b517a6f3e9b7e623f4cb97989`，唯一源入口 `inline-slot-workbench-concept/README.md` 当前 63–83 节及 `build-host-return-plates.py`、`host-return-source.json`。本组逐字节取其 [63 早2](evidence/e3946-source-early-1440x900.png)、[64 中5](evidence/e3946-source-middle-1440x900.png)、[65 晚8顶](evidence/e3946-source-late-top-1440x900.png)、[66 晚8底](evidence/e3946-source-late-bottom-1440x900.png) 四张 **1440×900 静态原组设计整屏**作当前公共边界对照；没有重绘舰船、槽行、台体或把图称为本组合实机。原审曾接受本版 63–83 共 21 态静态设计，根端亲看并已将 **63／64／65／66 四张设计确认稿实际发给用户**。用户现已回复并要求原装备组继续修：费用行中**哪个资源不足就将哪个资源标红**，不另列常驻不足原因；仅点击升级时提示不足；升级前后攻击／防御属性在**同一行**表达；每张武器／防御卡片有明确边框区分。用户进一步明确「这几个改完后可以合进实机看看」，原装备组已获实施授权并在原分支制作；本组不在 3946 上另画一套或代改其内部。该授权仅指修改后进入游戏实机查看，**不是合 main 许可**。此前原审静态接受仅为历史，不代表 3946 已获用户最终认可或运行交互／跨页验收。

与旧 e154／000a 研究不同，新原层短／长素材分别是 `coherence-assets/hangar-short-subordinate.png`／`hangar-tall-wallfixed.png`，生成源使用原 `x=-27,y=85,w=843.2,h=815`、裁在模块 `x0–808/y85–900`，没有旧长台 `w880` 越界撑宽或分段压缩。原尺寸看 63–66：早期舰体和已有武器同锚等比放大、台面灯框权重降低；中晚台上梁在约 x775 转入完整右墙，底梁在约 x785 接落地端脚，至 x808 留深墙余量，旧研究在 x808 硬裁的长台右上角／右下脚已由**装备原组源层**改为自终止。顶部公共轨仍 x0–808／y0–85，装备选中导航仍 x808–855.875，右侧战斗投影不压缩；四图源自原组静态公共截图上下文，非当前 `b178ec39` Godot 同版采样。该端面／公共几何对照不替代用户新要求下的整页新版及运行验证。

旧 `e154-early-balanced-*`／`e154-tall-return-*` 保留为历史研究，不再作为实现源或继续返修目标。运行组合现已接反应堆 `0afc6692`（本分支 `b178ec39`），装备仍是已提交旧 9e 返回对照，星球仍 ac5；未提交 304 装备 WIP 原样保全。**装备当前依赖**是原装备组完成已授权的卡片／文字／费用修订，固定**可运行代码与必需同源素材**，并交连续滚动停位、焦点、换装的受影响记录；不再等待用户给实机许可。本组在固定交接后精确接入并取同版跨页实机图，不抢先把 3946 当最终源。**其他待办**：0af B01 本版静态阶段审已完成，不无依据重修；其动态／真实鼠标全链未由本组合图覆盖，严格性能由原反应堆组在目标环境／同版条件核，不能以软件短采关闭；星球 ac5 品质退回待其组固定新源。公共控件／背景如无当前完整实图新增明确缺陷则不盲造美术微调；跨页整体终审须等真实各模块候选组合。本组当前无另一个已知、可独立实施而未固定的公共源码修正，不重复 B01 鼠标／性能矩阵，也不合 main。

### 装备 4dd4 原生 WIP 的正式宿主隔离闭包（供原装备组直接消费）

原装备分支 `art/equipment-materials-main-20261029@4dd4f1238ad59517965409b58eb52fb3acb14438` 的 `inline-slot-workbench-concept/NATIVE-WIP-HANDOFF.md` 明确为**旧宿主上的原生 WIP**，其 `src/main.gd` 与已合 main 的 `e3b38d7b6d8256f6031e1b086c7db7812b6a441f` 字节相同。e3 正常入口本已有窗口 `1440×900`、模块 x0–808、右容器 x808 宽632与战斗逻辑等比投影；**不要取本分支整个 `src/main.gd`**，它静态预载并安装 `reactor_scene.gd`／`planet_panel.gd` 及其 Owner／模型传递依赖。以下只给 4dd4 装备以正常主入口验证所需的公共闭包，非另一套旁路产品、非 WIP 验收或合 main 授权。

| 来源固定 SHA | 取入路径／精确范围 | 用途与排除 |
|---|---|---|
| 本组 `bfe5a19373c348946982d37c79f148789b5649e0` | `space-battleship/src/ui/zone_shell.gd`、`bridge_theme.gd`、`resource_visuals.gd` 三个**整文件**；`space-battleship/assets/ui/public_shell/*.svg`、`resource-material-atlas.png{,.import}`、`resource-material-supplement.png{,.import}`；`space-battleship/assets/ui/equipment/materials-20261029/control-materials.png{,.import}`。 | `ZoneShell` 唯一公共轨／导航／余额，主题状态与五资源身份。后两张资源图是 `ResourceVisuals` 预载；漆面图是 `BridgeTheme` 加载。`assets/fonts/NotoSansSC.ttf` 与原舰／武器／config／原生扩展已在 e3，无需重复取。public_shell 目录内的 prompt/source 文稿不是运行依赖。 |
| 原装备 `4dd4f1238ad59517965409b58eb52fb3acb14438` | `space-battleship/src/ui/equipment_panel.gd`、`src/systems/equipment.gd`；`assets/ui/equipment/hangar/inline-{short,tall}.png` 及各自 `.import`。 | 逐槽卡与原生 Owner 即时切换是一组，不能只换面板背景；`equipment_panel.gd::_init(session)` 继续用 e3 Session／Economy／Equipment 事实接口，`set_shared_host(true,null)` 由主入口调用。其 `NATIVE-WIP-HANDOFF.md` 记录 MAX 材料准入末补丁尚未完整重跑、退出清理和下拉新截图待原组核，不由公共闭包宣称通过。 |
| `e3b38d7b6d8256f6031e1b086c7db7812b6a441f` | 保留原 `space-battleship/src/main.gd`、`project.godot`、`src/game_session.gd`、Economy／战斗／舰船／config 等原产品文件，仅按下文改 `main.gd` 的装备公共挂载片段。 | 不复制当前本组 `main.gd`、`reactor_scene.gd`、`reactor_stage.gd`、`planet_panel.gd`、B01 八板／mask／shader或星球素材；这些不属于装备正常入口最小闭包。 |

对 **e3／4dd4 的 `main.gd`** 作以下原位适配，而非替换整个文件：①在预载区加 `const BridgeTheme = preload("res://src/ui/bridge_theme.gd")`、`const ZoneShell = preload("res://src/ui/zone_shell.gd")`，成员加 `var _zone_shell: Control`；`_ready()` 首部设置 `ThemeDB.fallback_font = BridgeTheme.public_font()` 和默认主题字体。②`_show_session()` 原 `equipment_scene.exclusive_ui_changed.connect(_sync_equipment_entry)` 后调用 `equipment_scene.set_shared_host(true, null)`；在同一方法创建 `CanvasLayer`（`layer=10`）、`ZoneShell.new(session.economy)` 并连接 `route_requested`，然后保持原 `_battle_input_blocker`、增长页和战斗 viewport；将 `reactor`、`planet` 导航设为不可用，**不实例化这两模块**。③原 `_setup_growth_panel()` 的旧 `_bridge_open` 顶部入口隐藏（仍保留该节点供既有禁用/焦点代码），由公共导航触发 `_set_page("growth")`；装备路由触发 `_set_page("battle")`，其他 `ship/growth/universe/hyperspace/archive/settings` 路由只映射 e3 现有六个 `_tabs`，隐藏页不得选择。④原 `_sync_equipment_entry()` 保留装备/增长显隐与战斗输入 blocker，然后由现有页态设置 `_zone_shell.set_active_route("equipment" 或对应 tab)`、`set_navigation_blocked(_modal_ui_occupied())`；把 `_zone_shell.has_exclusive_ui()` 纳入 `_modal_ui_occupied()`，关闭详情弹层再切页。原 `_refresh_feature_visibility()` 将 `growth/universe/hyperspace` 的可用性与原 `_tabs` 隐藏条件同步，`reactor/planet` 恒禁用。原存档状态只调用 `_zone_shell.set_status(...)` 更新公共状态内容，不重建整壳。**不要改 e3 的 x808 战斗投影、原输入 viewport、原 Session／Economy 事实接口或 `_set_page` 业务语义。**

这是可按两枚固定 SHA 取文件并在原主入口局部适配的**文件／函数闭包**，不是未经运行检验的“直接 cherry-pick 清单”。原装备组在自己的 4dd4 正常入口落片段后需以同版真整屏证实装备标题/导航/正文一致、x808 边界与输入；本组当前组合仍使用旧 9e 返回对照，不把该隔离装配图冒本组或 4dd4 已验收证据。本组后续把其完成的固定运行源精确接回当前 B01 0af＋星球 ac5 公共组合。

### 装备 4dd4 WIP＋反应堆 6d0 packed 的当前共享组合（待整体审）

原装备固定 `art/equipment-materials-main-20261029@4dd4f1238ad59517965409b58eb52fb3acb14438` 的唯一原组入口是 `inline-slot-workbench-concept/NATIVE-WIP-HANDOFF.md`：其矩形卡、单行属性、逐项费用、原生 Owner 即换仍标 **WIP**，末次 MAX 材料准入／退出清理尚未在原组完整流程重跑。相对本组原装备运行源，本次精确取 `src/ui/equipment_panel.gd`（Git blob `234e5eb3`）、`src/systems/equipment.gd`（`6c019ccb`，去同槽 10 游戏秒切换锁及恢复旧字段归零）、`assets/ui/equipment/hangar/inline-short.png`（`a378788a`）和 `inline-tall.png`（`f850b0d1`）及各自 `.import`；保持原 `main.gd` 正式公共路由与装备 `EquipmentPanel.new(session)`／`set_shared_host(true,null)` 安装点，不取原组旧 main 或静态整图替换运行面板。旧未提交 304 装备 WIP 已按 SHA256 `da5ed854f9f96ad0dc26753824a39bdf74cf80099677fc9e62f70629e15b2775` 将完整字节及 patch 隔离保存在 `/tmp/space-idle-runtime472/equipment-panel-304-wip-before-4dd.{gd,patch}`，本版运行树明确由已提交 4dd4 面板替代，旧 WIP 未混入提交。

原反应堆固定 `implement/reactor-centered-godot@6d0ee146ca54613cf13e9cd1ae2863310e3ed424` 相对本组已接 `0afc6692` 只改 `src/ui/reactor_stage.gd`（blob `1f0385f7`）和 `assets/ui/reactor/b01/live-material.gdshader`（`5b6a69e9`），新增 `pipe-effect-mask.png`（`c6b28046`）、`module-effect-mask.png`（`80f139d9`）及各自保持 RGB 的 `.import`；八张 0af 原板、原 Session／Owner／scene、公共源与星球均未换。原组三 mask 并未从本组树删除，舞台运行参数只绑定新两张 packed 图。原组在软件渲染 ABAB／BABA 短窗内报告小幅收益和受控鼠标／购买证据；本组**不重新测其完整交互或性能**，也不把它报告成目标硬件严格性能通过。

Godot **4.7.2** 在此当前树导入无错误。[共享跨页驱动](evidence/r4dd6d-combo-driver.gd.txt)／[日志](evidence/r4dd6d-combo-runtime.txt)取得同版 [装备早2](evidence/r4dd6d-combo-equipment-1440x900.png)、[反应堆普通](evidence/r4dd6d-combo-reactor-1440x900.png)、[反应堆 MAX](evidence/r4dd6d-combo-reactor-max-1440x900.png)、[星球返回](evidence/r4dd6d-combo-planet-1440x900.png)四张 `1440×900` 实机整屏，路由互斥／星球钱包隐藏断言成立。另按[装备受控阶段驱动](evidence/r4dd6d-equipment-states-driver.gd.txt)／[日志](evidence/r4dd6d-equipment-states-runtime.txt)只取 [早2](evidence/r4dd6d-equipment-early-1440x900.png)、[中5](evidence/r4dd6d-equipment-middle-1440x900.png)、[晚8顶](evidence/r4dd6d-equipment-late-top-1440x900.png)、[晚8底](evidence/r4dd6d-equipment-late-bottom-1440x900.png)四张同版整屏；后两种舰体通过原 Campaign／Equipment Owner 受控更换，不冒称自然阶段进度或原组完整操作链。原尺寸实看八图：装备新矩形卡、逐槽两键与右台墙在 `x0–808` 内，公共装备选中导航 `x808–855.875`、右战斗投影和顶带未被覆盖；B01 packed 版四路控制台与端柱保持原边界；星球仍旧 ac5 返回对照。当前装备图可见不少空槽，原生事实与版面由装备组继续核；跨页材质／全状态品质必须由原整体审按当前图重判，**不以可运行／路由断言或旧 3946 静态接受当本版通过**。本版未固定真实鼠标全链、连续滚动焦点／换装或目标硬件性能；装备组自身 WIP 末补丁、星球新候选、跨页终审继续按原职责交接。本候选不合 main。

### 装备 8430 运行源／51c 同源证据与公共资源量级修复（同版组合，待整体审）

原装备组运行代码固定 `art/equipment-materials-main-20261029@8430cd9c8cd84372e0218762daab986e989f3fbe`，后续证据固定 `51c13d9b8e932eda267404691809d31b561814d4` 仅增原组正式宿主／真空槽图证、视频和记录，**`src/`／`assets/` 与 8430 相同**。原组入口 `inline-slot-workbench-concept/README.md` 最新正式宿主／真空槽节；相对当前 4dd4 运行闭包，**仅** `src/ui/equipment_panel.gd` 有 37 行运行差异（Git blob `9bc82d3a`）：真空槽只保留可选身份，不再摆出占位等级／属性／报价／购买，修本地下拉图标尺寸顺序及材料未开放说明净空。本组精确取该文件，保留已接 4dd4 `src/systems/equipment.gd`、短／长环境素材和主壳；原组 `main.gd` 是其隔离宿主适配，`zone_shell.gd`、`bridge_theme.gd` 的 Git blob与本组公共源相同，均**不整取覆盖**。原反应堆 `implement/reactor-centered-godot@b68994bb8e0be49777706e78f414a3f0668a7b0c` 相对已接 `6d0ee146` 的 `src/` 与 `assets/` **无运行源差异**，仅补原组连续录像／记录；本组不复制该视频冒作当前组合动态，也不重复其全链或性能。

根端看 51c 原组正式壳图指出当前公共资源顶栏“铁：99…”／“铁：1.2…”丢量级。根因实测为 `Economy.balance_rows()` 已使用原生 Amount `to_display` 经 `PlayerText.number` 得到完整紧凑文本，如 `铁：9.99万`、`铀：1,000`、`时空微粒：4.32万`；`zone_shell.gd` 却把**图标＋重复资源名称＋数字**塞进首格 76px（其他格 74／132px），再启用 ellipsis，截掉了主数量。现只改原公共 `ZoneShell`：图标继续表达资源身份，顶栏只绘该官方文本冒号后的**数值**；净宽分别增为 88／86／144px，不动三格分隔线、资源图标、余额 Owner 或详情弹层。科学表示只在这条窄轨把 `PlayerText.number` 的 `×10^` 写成等价 `e`，按原生字体实际字宽在 16／14／12px 选择可容字号；详情与悬停仍保完整官方行。本版同屏正常铁 `9.99万` 和受控长铁原行 `铁：1.235×10^39` → 顶轨 `1.235e39` 都能**直接读出量级**，没有用 tooltip 替代主值，也未叠新资源控件或触碰数额算法。更极端、长度超过最小字级可容宽的指数尚无同域真实截图，不据此泛称全无限域通过。

Godot 4.7.2 本版导入无解析／资源错误。[同版跨页驱动](evidence/r51c6d-combo-driver.gd.txt)／[日志](evidence/r51c6d-combo-runtime.txt)取得 [装备早2](evidence/r51c6d-combo-equipment-1440x900.png)、[受控长数顶栏](evidence/r51c6d-combo-resource-long-1440x900.png)、[反应堆普通](evidence/r51c6d-combo-reactor-1440x900.png)、[反应堆 MAX](evidence/r51c6d-combo-reactor-max-1440x900.png)、[星球返回](evidence/r51c6d-combo-planet-1440x900.png)五张当前 `1440×900` 完整实机图，路由互斥／星球钱包隐藏仍成立。[装备受控阶段驱动](evidence/r51c6d-equipment-states-driver.gd.txt)／[日志](evidence/r51c6d-equipment-states-runtime.txt)另固定 [早2](evidence/r51c6d-equipment-early-1440x900.png)、[中5](evidence/r51c6d-equipment-middle-1440x900.png)、[晚8顶](evidence/r51c6d-equipment-late-top-1440x900.png)、[晚8底](evidence/r51c6d-equipment-late-bottom-1440x900.png)四张；后两类受控换舰，不宣称自然进度。原尺寸看装备空槽只留下“武器／防御 · 空槽”选择入口，已安装卡的报价／两键和名称仍在原位；顶部正常／长金额无省略，公共 x808 导航和战斗有效空间不变，B01／星球路由保留。**这是共享接入及受影响静态状态证据，非原组鼠标全链、连续动态、严格性能或跨页整体审结论**；原装备组 8430 真空槽与 51c 同源证据仍由其审，星球 ac5 仅旧返回对照。本候选未合 main。

#### 可直接交原装备组的资源条最小补丁身份

当前资源条修复固定在本组 `design/clear-zone-host@459df59315e20708075bda5fafe9ef8408b69a7d`；相对该提交的父 `a5da0606ba063fc3b7dccfb02d83eb9f3c25f03a`，**唯一公共运行源码差异是 `space-battleship/src/ui/zone_shell.gd`**（完整 Git blob `8998e38d746b31f7f676fdbc0126906c79e0863d`，旧 `dfe75787802b6118e681b4f32141292dc48b4b0f`）。`zone_shell.gd` 的原公共闭包／素材已在上文 `0fccb579` 取入；原装备 8430 的文件现仍为旧 `dfe75787`，故原组只须从 459df593 **精确替换这一个脚本**即可消费新宽度／数值格式，不需要本组 `main.gd`、反应堆／星球代码、另一份资源资产、Amount／Economy 规则或其他公共叠层。其正常主入口继续使用已交 `0fccb579` 的公共挂载与原装备 Session；本补丁只在原 `ZoneShell` 现有三格改文本净宽、复用 `Economy.balance_rows()` 的官方紧凑数值、科学量级窄轨表示与字号容纳，完整资源详情／悬停原文保留。

原组可直接看本组合的[正常余额真实 1440 整屏](evidence/r51c6d-combo-equipment-1440x900.png)与[受控长铁真实 1440 整屏](evidence/r51c6d-combo-resource-long-1440x900.png)：主栏分别直接显示 `9.99万` 与 `1.235e39`，资源图标仍在，长铁详情原格式为 `铁：1.235×10^39`；[同版运行日志](evidence/r51c6d-combo-runtime.txt)有实际 `Economy.balance_rows()` 值。两图只是当前共享静态画面及资源可读性，不替代装备组 8430／51c 内部全链、组合整体视觉审或目标性能；本组不要求原组复制当前 B01／星球运行树。

### 装备 d354 资源条同源确认稿已送用户（仅状态续记）

原装备组运行代码 `art/equipment-materials-main-20261029@d354e60f1530435a6790cca0814ddc7e76f84f82` 相对其 `8430cd9c8cd84372e0218762daab986e989f3fbe` 的 `src/`／`assets/` **只改** `src/ui/zone_shell.gd`；该文件 Git blob `8998e38d746b31f7f676fdbc0126906c79e0863d` 与本组已接 `459df593`／当前组合**完全相同**，装备 `equipment_panel.gd` 仍同一 blob `9bc82d3a`。原组证据固定 `19a2ba967cd265673a40b9d526db88671b5f1924`，唯一入口 `inline-slot-workbench-concept/README.md` 最新资源条节、`resource-rail-confirmation/` 五张 1440×900 原生整图与账本；根端确认这五态已由根和既有审看过，**实际送用户确认**。故本组无需再复制同一运行源、重拍五态或催原组重复消费资源条；此前“等原组取公共修复／仅 8430”已过时。五态只覆盖装备本页与顶部量级；用户意见尚待回复，不代表整游戏、星球／B01 或 main 验收。

当前组合仍是本组 `459df593` 的 51c／8430 同 blob 装备面板＋已接 6d packed B01＋旧 ac5 星球＋当前公共资源修复，实际完整图见上节。独立余项的固定依赖是星球原组新运行源与质量审、反应堆原组目标环境严格同版性能／未覆盖动态范围，以及新候选到位后的跨页整体终审；装备当前只待已送五态的用户反馈，不再待其资源条源码。没有新的明确公共可独立修正退点，本轮不造微调／重复复测，不合 main。

### 当前九整屏＋三往返静态组合审结论

根端转达原整体审已实际核上节 **51c／8430 同 blob 装备＋6d packed B01＋公共资源条**的九张同版完整整屏，并另核三张装备／反应堆切页往返图：**已展示的装备、B01 与公共层静态组合成立，当前没有明确可独立修正的公共区域／导航退点**。这是本版所见静态画面和切回外观的限定结论，不外推装备 `19a2ba96` 已发用户五图的回复、星球旧 ac5 的品质、未覆盖的连续动态／真实全链、目标环境严格性能或整体游戏验收。当前不重拍这九张已审图，也不凭局部通过自行合 main。

真实后续依赖仍逐项分开：装备等待用户对已发 `19a2ba96` 五图的意见；星球等待原组固定新运行源和品质审；反应堆目标环境性能及本组合未覆盖动态仍属原组／后续同版范围；新候选齐备后再做跨页整体终审。没有新固定源或明确公共缺陷时，本组无另一个独立公共改动可做，不把缺候选说成工具阻塞，也不重新索取用户已给的实机授权。

### 8c9 动态证据／40db 星球局部候选核查（未接入）

10 时只读核当前本组 `a037ecbf5b9bf046d0da5c8101751fa1343667ab` 远端一致、tracked 工作区干净；旧 304 装备 WIP 仍仅隔离于 `/tmp/space-idle-runtime472/equipment-panel-304-wip-before-4dd.gd`，SHA256 `da5ed854f9f96ad0dc26753824a39bdf74cf80099677fc9e62f70629e15b2775`。前次停机是文稿自然交付，无平台容量、权限或工具阻塞。

反应堆固定 `implement/reactor-centered-godot@8c9dbad60d2e7454b2f28e817459e6304d00a56a` 相对其前版 `b68994bb8e0be49777706e78f414a3f0668a7b0c` 在 `space-battleship/src/` 与 `assets/` **没有任何运行源差异**，本组已接的 6d packed 文件无需再取。原组 `b01-redesign/README.md` 新增受控 1／2／3 路约 22 秒连续录像与四路购级→低正载→真零约 18 秒连续录像、关键整屏和日志；原组注明少态/过渡新片仍待其既有原审，1／2 非自然开放，软件录屏不是目标硬件严格性能。它们是**原组源版录像**，不冒作本组装备＋星球当前组合动态，也不据此重跑整套鼠标／性能。

星球固定 `feat/planet-single-side-ui@40db4ed465555539561c8dac0f5920da44f27b29` 的唯一入口是 `visual-r17-curved-spine/README.md` 最新“单槽装甲材质与正确 mipmaps”节。该**局部候选**最新提交只新增 `assets/planets/orbital_spine/deck-armor-single-channel.png{,.import}`、把 `scripts/planet_orbital_spine.gd` 的甲板纹理引用改向该图，并附局部 stage2／4／模拟90° 证据；原组明确单槽材质和整体均待原审，端头／站侧壁／炉下暗肩／船坞壳与整体剪影仍未收口。相对本组旧 ac5 星球运行基线还隔着多笔尚未整体交接的几何／设施修改，故**不单挑 40db 的图片或脚本接入当前组合**，更不称星球整页已过。待原星球组给经审固定完整运行候选、准确源闭包与覆盖范围后，再按原共享宿主边界精确消费并取同版整屏。

当前真正待交：装备 `19a2ba96` 五图已送用户、尚无新回复；星球待完整固定源与品质结论；反应堆新录像待原组范围审及目标环境性能；新模块候选到齐后跨页终审。本组已有装备＋B01＋公共层静态组合阶段结论，现无新增明确公共缺陷或可独立同步的完整源，故本次只读核查并记录，不把缺候选误称技术阻塞，不造新美术微调／复测／main 合并。

### 808 反应堆视觉交付／6400 星球船坞局部候选核查（11 时）

本组运行仍是装备 `d354e60f1530435a6790cca0814ddc7e76f84f82` 同 blob、反应堆 `6d0ee146ca54613cf13e9cd1ae2863310e3ed424` 14 文件闭包与旧 `ac5d7d5581237f76711cebe92b654e02cd5e686d` 星球。`implement/reactor-centered-godot@808253769aa381560d6b0377785543eaacce711b` 的原审视觉结论已到，三段原组视频已实际送用户；`d20e5905c0a921244256a35bd74aad9a1c0e7e73` 在原 [B01 入口](../../../verification/reactor-centered-godot/evidence/b01-redesign/README.md) 登记为**仅视觉待用户意见**。从已接的 6d 到 808，再到 d20，`space-battleship/src/` 与 `assets/` 均无差异，故没有新运行文件要同步，也不把原组视频冒作本共享组合动态。受控 1／2 路不等于自然解锁；现环境调查虽已收口，**目标机器约 10 fps 损失尚未证明消除**，原组有界软件采样不代目标机性能验收。

`feat/planet-single-side-ui@6400b71e8bfb4197078e9ead414861d2ce5fed53` 相对前版 `affb1ea6` 只新增 `evidence/shipyard-single-bay/` 的运行／导入／哈希文本，无 `src/`、`scripts/`、`assets/` 变更；原 [R17 入口](../../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md) 仍称船坞单泊位为局部候选，四建筑整体退回且由原组核整体范围。相对本组 ac5 基线还隔着未整体验收的星球几何、设施与素材变化，不将该局部证据或其中任一文件单挑接入。

装备 `19a2ba967cd265673a40b9d526db88671b5f1924` 五态图已送用户，仍待意见；当前九整屏＋三往返静态组合的限定结论保持。现无新增明确公共缺陷或已获整组交接结论的运行差异，本次只更正依赖状态，不另取图或复测。后续固定依赖分别为装备用户反馈、星球原组完整运行源与品质结论、反应堆目标机性能实证／未覆盖的本组合动态，以及新模块候选齐备后的跨页终审；这些是证据与原组交接依赖，非本工作区技术阻塞，也不构成整体通过或合 main 授权。

### 全局数字档位与逐资源不足反馈：公共源交接

用户新定的 `k/m/b/t/kt/e`、一位小数规则已写入唯一[13 全局数字显示](../../../game-design/13-art-interaction.md#22-全局信息层级与适配)，展示端口与逐资源不足语义见[14 两键契约](../../../game-design/14-ui-contracts.md#1-版本与使用边界)。可供各模块消费的实际公共运行文件仅 `src/ui/player_text.gd` 的静态 `PlayerText.number(value: String)`；已有装备、反应堆、战斗等数字路径调用它。入口接受 native Amount `to_display` 的十进制／科学记数文本，按十进制字位舍入，不将 Amount 转成 float；不改 Amount、Owner、报价、支付、比较或数据库。公共余额对齐另改 `src/systems/economy.gd::balances_text/balance_rows`（增加只读 `raw` 字段）、`src/ui/zone_shell.gd::_process/_update_resource_rows`（顶栏与详情共用格式、悬浮显示 native 原文），不再有顶栏专属科学记号改写。模块内部若只需统一金额，可仅取 `player_text.gd`；若使用公共余额顶栏，须同时取上述两个文件，并以当前公共宿主为基线精确合并，不取整棵未审模块树。

边界校核：`0→0`、`12→12.0`、`999.94→999.9`、`999.95→1.0k`、`999950→1.0m`、`1e15→1.0kt`、`9.9995e17→1.0e18`、`1e20→1.0e20`、`1.235e39→1.2e39`；负数保符号，舍入后为零不显示 `-0`，极大指数仍按字符串进位。Godot 4.7.2 对 21 个定向输入比对均通过，`economy.gd`／`zone_shell.gd` 脚本解析通过；这是展示函数边界检查，不冒充各模块同版整屏已重新视觉验收。顶栏和详情现在都显示缩写；悬浮 native 文本仅补精度，主读数本身保量级。

资源不足参考当前已接装备 `d354e60f1530435a6790cca0814ddc7e76f84f82` 的 `equipment_panel.gd::_refresh_card/_render_fees/_cycle_slot/_buy_slot`：报价按资源逐项 `Economy.can_pay`，只将不足项费用文字转红，彩色图标保持原色；余额不足不禁用购买键，数量循环只刷新本地模式与报价，真正执行收到 `InsufficientResources` 才短暂提示。其他模块由原组按自身 Owner 端口接入，不能由公共组代改内部；装备批量弹层 `_buy_all` 的不足提示仍需装备原组按同一规则核，不能将逐槽实现外推为批量／全模块完成。原反应堆组的均分、费用与不足状态修订仍由其内部负责，公共规则不准许切数量时发命令或改变失败业务语义。

### 性能报告基线（仅规范交接）

全项目后续性能优化报告统一按[07 全项目性能优化报告的用户基线](../../../game-design/07-verification.md#全项目性能优化报告的用户基线)执行：以最近**实际送达用户**的指标列“上次 → 本次”，不可比条件与缺失项明确写出。此处只引用总体权威规范，不另造 UI 专属性能标准；本次未开展测量，不改变上文 B01 目标机器约 `10 fps` 损失尚未证明消除的限定结论。用户已撤回立即强制三制作分支接入公共壳的要求，本次不制作安装补丁或催组。

### 装备／B01 操作承载面同族探索 R1（静态设计，原审退回）

用户指出当前装备过于克制、B01 下方分配和升级面板过于花哨，两页不像同一游戏；此前公共壳的静态限定接受不覆盖此新退点。以装备 `d354e60f1530435a6790cca0814ddc7e76f84f82` 的[原组 19a2 早 2 槽实图](evidence/coherent-controls-r1/source-equipment-19a2-early2.png)及当前 6d／808 同运行闭包的[B01 组合整屏](evidence/r51c6d-combo-reactor-1440x900.png)为固定参照，做了可编辑[Godot 设计渲染源](evidence/coherent-controls-r1/render-study.gd.txt)、[并排 2400×1030](evidence/coherent-controls-r1/compare-2400x1030.png)、[装备 1440×900](evidence/coherent-controls-r1/equipment-1440x900.png)与[B01 1440×900](evidence/coherent-controls-r1/reactor-1440x900.png)。原源图、设计图、材质来源与哈希见同目录 `SHA256SUMS`、`material-prompt.txt`。图均为**静态设计预览，非实机**：保持原 1440×900 顶栏、导航 x808…855.875、战场投影和各自实机背景，只在概念渲染中替换模块操作区；源图中的顶栏余额仍按拍摄时旧格式，不能冒作本组新 `f688ea7c` 数字显示的同版实机证据。装备预览保原 19a2 早 2 槽、余额 0 与逐项红字；B01 保四路 25%、均分、等级和功能色。

**建议方向：**两页统一以一层深青低反光承托面和一层象牙信息面组织操作，外缘冷青单线加浅金属厚度；普通操作键均是同一深青漆面，悬浮提亮冷边、按下压暗底面、已选持续青边、焦点独立可见、禁用降低反光而保字。可购执行键仅一圈克制暖金边；余额不足仅对应费用文字转红，资源图标保持原色，执行反馈仍由 Owner 决定。装备卡保下拉、比较、属性、费用、×1/×10/MAX 循环＋购买；B01 保一体功率条、四色路数、滑杆、均分、等级报价与独立升级，四色只标能量和资源，不给普通框上色。B01 旧厚金层、金滑块与逐行金描边收成同一承托层，设备与核心本体不削光；装备不加一圈额外外框或变成 B01 舱景。取舍是 B01 下台的仪式感降低，换取读数和操作主次；两页各自的机库／反应堆观看主体仍不同。状态板只表达视觉关系，不声称 hover／按下／不足等已在两页运行实现或已通过审查。此方向尚未获用户选定，不能以本图宣布全模块材质统一已完成。

**源层归属与后续消费：**装备原组若采用，应在 `src/ui/equipment_panel.gd` 的 `EquipmentSurface/_surface_material`、原卡 `_make_card/_card_border`、原键 `_button` 与费用 `_render_fees` 上**替换**旧漆面／细框绘制，保留节点、逐槽事实与点击回调，不在旧卡上再盖一套；B01 原组应以 `assets/ui/reactor/b01/{one,two,locked,idle,active}*console.png` 对应原板（实际八态文件见 `src/ui/reactor_stage.gd` 顶部 preload）、`reactor_stage.gd` 的 mask/shader 与 `reactor_scene.gd::_build/_button/_panel` 为接线范围，在原板下台和现有原生控件面上收减金边，维持 1／2／3／4 路真实 mask、比例与滑杆输入；不能在宿主叠遮框或用本静态 4 路图替八态运行源。公共 `BridgeTheme`、`zone_shell.gd`、导航、业务 Owner、支付和战斗投影此方案未改。原组实际源与八态／逐槽状态接入后，仍需按 13 第 6 节重新看当前真实完整整屏和相关动态；当前仅可供视觉方向评判与精确协作，不合 main，也不恢复已撤回的强制公共壳接入。

**阶段定位与未完范围：**`4bdea799` 的两整页和并排已由既有原审正式退回，**不交用户**：B01 在 y≈517 直切舱景、下台像平面表格；装备矩形板盖住支架；纸纤维／细框键不像设备面，操作尺度和抓手也不统一。其色彩方向可供 R2 参考，但不能按 R1 源实现。R1 使用 `material-reference.png` 中央纹理及 `draw_rect/draw_line` 绘制键／边线，**不是已接运行的组件**。预览仍沿 19a2 早 2 槽旧布局，不能当作原装备组当前纯名标题／费用左齐版的排版验收。

### 装备／B01 同族设备操作面 R2（完整静态设计待整页审）

针对 R1 正式退回，在真实 [装备 1440×900](evidence/coherent-controls-r2/equipment-1440x900.png)、[B01 1440×900](evidence/coherent-controls-r2/reactor-1440x900.png) 与[并排 2400×1030](evidence/coherent-controls-r2/compare-2400x1030.png) 上改后重看：装备保留机库旧框、支脚、地面与舰体，仅**替换框内旧面**；B01 保留顶部核心、连续舱梁、功率条支承、左右台颊和落地端脚，仅在既有下台内换操作面。设计源为可编辑的 [Godot 绘制脚本](evidence/coherent-controls-r2/render-study.gd.txt)，使用项目现有 `assets/ui/equipment/materials-20261029/control-materials.png` 漆面／金属键 atlas 作两页同源九宫格、`assets/ui/reactor/b01/slider-knob.png` 作真实滑杆抓手；不是在旧表单上增加一圈外框，也没有运行源码修改。三图、脚本与资产的哈希在同目录 `SHA256SUMS`。本版去掉 R1 纸纤维面和平线框键，深青普通键与暖金执行键共用一套尺寸和材料关系；装备下拉用可见三角抓手，B01 四路色仅用于分配语义。

**实图自查与边界：**两张整页同为 `1440×900`，模块 x0–808、公共导航 x808–855.875、战斗有效 x855.875–1392.125 均来自固定源图，未缩放舰船或战场。装备原 19a2 截图的舰名牌仍带“武器1／防御1”旧副文，内台题改为“逐槽工作台”以免双写舰名；**最新原组要求的纯名牌并未由这张旧源图验收**。费用从属性下方左起，红字只指不足铁。B01 四路比例、均分与升级仍保留原功能位置，原 B01 舱景在台后和两端可见。本图是**静态设计合成，非当前实机／可运行资产**：装备只演示早 2 槽，B01 只演示四路 25%；normal／hover／pressed／selected／disabled／focus／可购／不足的跨页原生状态、1／2／3 路、长报价、滚动和全链操作均未由本图证明。图内余额、业务值沿源截图拍摄态，不冒新数字规范或同版 Owner 证据。

原组消费若采用，应**替换** `equipment_panel.gd` 原卡面／按钮样式或 B01 `reactor_scene.gd` 原面／按钮样式，并在其既有节点与八态原板中适配实际内距、端脚、hover／按下及有效焦点；不得整图贴入运行或压公共壳。装备纯名、费用左齐的最新版排版仍由原装备组现行源码负责，本 R2 只给材料与完整场景承托判断，不能以 19a2 旧槽位图宣称其最新版已适配。B01 少路数八板及均分、升级的真实状态由原反应堆组给固定候选。本组保留公共几何及已接运行闭包，待原审按 13§6 从**整个当前画面**判断 R2，不能因 R1 退点逐项消失就自称统一完成；方案未获用户／原审批准，不合 main。
