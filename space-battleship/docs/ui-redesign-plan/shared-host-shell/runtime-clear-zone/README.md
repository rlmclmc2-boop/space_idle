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
