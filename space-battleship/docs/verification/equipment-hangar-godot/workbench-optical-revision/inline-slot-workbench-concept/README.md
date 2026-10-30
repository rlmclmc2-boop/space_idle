# 装备矩形卡与原生接入：当前执行检查点

用户已批准矩形卡修订后接入实机：每槽完整矩形卡、单行当前→升级后、逐项不足费用标红，拥挤时保图标数字并悬停0.5秒提示；不足购买可点，真实拒绝后才短暂提示。现装本地下拉点击即免费切换且可立即切回，无额外确认，同槽10游戏秒锁已按授权移除。

63–83当前21态及[84不足点击反馈](84-insufficient-click-feedback.png)、[85资源悬停示意](85-resource-hover-half-second.png)共23张已逐张实际查看。当前统一[审阅页](review-current-group.html)、[矩形卡账本](rectangular-card-manifest.json)与[导出源](build-rectangular-cards.py)。旧3946静态原审通过不覆盖本次矩形修订；历史账本保存在`host-return-*-3946-history.json`，不能作为当前文字/控制节点不变的声明。

真实Godot4.7.2/native/config同线程GUI流程在最后MAX准入及退出清理后已执行，随后因目视发现下拉图标撑大，修正TextureRect初始化顺序并再次执行：退出0、failures=0，含MAX材料禁用及下拉图标边界断言，退出无ObjectDB/资源泄漏警告。新下拉已实际看图；完整运行证据与源码hash见[本轮真实证据账本](wip-inline-native-patch-ledger.json)、[操作JSON](wip-inline-native-patch-operations.json)、[原始日志](wip-inline-native-icon-fix.log)和`wip-inline-native-patch-*.png`。中后期使用明确受控Owner恢复；未知回执保护采用显式publisher故障注入，不称自然故障。旧视频`wip-inline-native-wip.mp4`保全，早于本轮图标修正，不作为同版新视频。

当前公共宿主仍是旧main，缺正式导航/等比战场宿主，所有本轮实机证据明确为WIP。最小宿主闭包已报根协调：公共区域挂载和装备选中导航、战场视觉/输入同变换、共同字体按钮/浮层角色及其必要资产；不得把整体混合分支的反应堆/星球实现整包带入。正式宿主接入后仍须固定同版2/5/8顶底及真实长MAX整屏和操作视频，再交根/原审。更多未见极端字段须装备域真源，不造额外资源。

本执行者尚未实际平台压缩；原工作区/分支继续，无等待用户授权、权限拒绝或未知执行结果。当前无Godot/ffmpeg后台进程，不合main、不新建工作区或子代理，原untracked .import/.uid及缓存保全。精确现场见[NATIVE-WIP-HANDOFF.md](NATIVE-WIP-HANDOFF.md)、[pending-work.json](pending-work.json)。下方为历史来源说明，以本段当前事实覆盖历史待办。

---

# 前版e154：42–62共同源构图候选

当前仅桌面1440×900静态设计，SVG为精确文字／控件排版源，PNG是其静态渲染；背景插画使用ImageGen，不能称整图为ImageGen精确输出、实机、完整宿主或用户已接受版本。原分支`art/equipment-materials-main-20261029`，不改运行代码／Owner／config，不合main，不运行新复测。

## 当前整页一体感修订42–62待审

用户要求整页一体感，不照抄参考的深色空底或常驻候选半页。当前背景、船、既有武器模型与逐槽操作共同构图，不能把露出背景面积增加当完成。消费整体固定 **b17db8d2fef26009515df75b5759b6b1ac7ca3fb** 的实际公共材质／按钮／浮层／导航来源，详见[共同源账本](shared-source-b17.json)。继续采用已认可61c9 R3的Noto400／500／600角色；没有复制b17中450加合成增粗的新字体实现，也未编辑公共源。

已制作早期短台、中晚期长台两种房间插画：舰体下方左圆台、右阅读面和下部支撑在同一房间中生成；旧双操作台背景及叠在其上的不透明平表框在新分支中不再使用。精确文字、资源、选择、费用和按钮直接落在实体台面，背景不烘焙船／武器／槽文字／按钮。早期舰名牌靠近舰首；舰图和操作台保持同一观看区。原舰图显示比例及既有武器mount／anchor不改，背景本身非物理几何。五次插画过程及原输出全部保留，[来源与失败过程](coherence-imagegen-provenance.json)，[背景交接](background-composition-handoff.json)。这是当前整页适配候选，**仍需整体／根／原独审判断一体感、比例和右宿主过渡**。

| 当前整屏 | 状态 |
|---|---|
| [42早2](42-coherent-early.png)／[43中5](43-coherent-middle.png) | 无滚动的少槽与中期组织 |
| [44晚8顶端](44-coherent-late.png)／[45晚8底端](45-coherent-bottom.png) | 五武器完整顶端／底部三防御；边缘仅被动身份 |
| [46防御选中](46-coherent-defence.png) | 防御仅行内信息与操作 |
| [47 MAX](47-coherent-max.png)／[48材料未开放](48-coherent-material-locked.png)／[49可购](49-coherent-affordable.png)／[50单费](50-coherent-single-fee.png) | 同94px行容量的费用／数量／原因状态 |
| [51防御下拉](51-coherent-defence-dropdown.png)／[52独立比较](52-coherent-defence-comparison.png) | 名称／图标本地下拉，比较独立；无确认 |
| [53武器下拉](53-coherent-weapon-dropdown.png)／[54独立比较](54-coherent-weapon-comparison.png) | 四武器候选及同口径比较 |
| [55 hover](55-coherent-purchase-hover.png)／[56 pressed](56-coherent-purchase-pressed.png)／[57 focus](57-coherent-purchase-focus.png)／[58 hover_pressed](58-coherent-purchase-hover_pressed.png) | b17共同绘制角色静态状态，无输入或焦点运行证明 |
| [59启用空槽](59-coherent-active-empty.png)／[60休眠详情](60-coherent-dormant-details.png) | 空武器槽不画对应舰上模型；休眠按需只读详情 |
| [61真实长MAX](61-coherent-long-max.png)／[62同报价不足](62-coherent-long-max-poor.png) | 实际历史字段的长值／双费及静态不足对照 |

以上21张整屏与15张`*-native-detail.png`原像素局部已经作者实际看图；非作者自判通过。每张SVG同名，源[build-design-plates.py](build-design-plates.py)，精确文件hash见[manifest](manifest.json)及[SHA256SUMS](SHA256SUMS)。顶部x0–808/y0–85与b17公共导航截图逐像素一致；右侧x808–1440与原上下文图逐像素一致。它们是视觉上下文，**不与槽内历史数值构成同次经济／运行快照**。

## 行内容、容量与可操作边界

保留04149原审认可的2／5同屏、晚8边缘只读身份和真实武器关联范围。每行固定94px，身份基线24、当前主值46、升级后主值66、费用86；两行对齐主值解决长MAX横排相撞，不加行高、不缩字体。费用标题“费用”均属该槽当前装备升级，绝非安装费。数量键循环×1→×10→MAX，独立购买在同槽就近；余额、原因、模式与单双费不会推后续槽。普通行无多余第二费用空带。

早期内容226／视口226，中期508／508，晚期790／510、静态滚动范围0–280。只有完整可见行绘制属性／报价／比较／数量／购买目标，部分行**实际源只画不可操作身份**，不是在文档中补一条焦点规则。边界与目标坐标见[行记录](compact-row-boundaries.json)、[逻辑目标](target-boundaries.json)。目标是设计分配，非运行点击／焦点测试。五组报价对照在下一行起y406后的像素差均为空，证据仅限所画状态。

61取原`workbench-rebuild-preview`受控预览的真实长MAX记录：paidLv19，9,300→1.556×10^43，购444级，铁1.145×10^39＋简并物质2,760。原记录与固定 **4f18eee875a046f220b5c3cf755b7c409fb9f2b5** 的equipment SHA及字段绑定保存在[真实长值来源](legacy-long-max-source.json)。62只静态翻转同报价的不足原因，不冒充新Owner运行采样。费用按实际500字重测宽，资源组间10px并实际看局部；当前两费配置不等于Owner永久限两费。尚未覆盖任意更长paidLv／名称／原因或未经来源证实的三资源。

## 最新舰上呈现约束（用户已定）

舰上仅已有武器模型与对应武器槽；实际mount／anchor与独立武器图层见[ship-weapon-layout.json](ship-weapon-layout.json)。防御只保留信息和操作，**不实现防御模型／代理徽章／引导线／指船身，不为对称补表现**。锁定武器只留原空位，无卡图文交互。下拉候选点击即换、无确认无成本且可立即切回；可选比较独立不挡切换。不恢复记录／最近结果／卸下／教学。

## 当前全部待办、衔接依赖与执行边界

完整机器清单见[pending-work.json](pending-work.json)。b17共同材质现已可用并在本候选实际接入，单一承托背景也已制作，不再沿用“全部等公共源／真实长值全缺”的旧依赖。

1. **整体／根／原独审的整页判断尚未完成**：取本组模块`[0,85,808,815]`，以42／43／44／45＋61／62与b17 B01完整宿主比较，判断小舰名牌／船台比例、实体承托、按钮信息层级及x808过渡。明确来源是本次短／长背景和b17共同角色，不需要泛称“另等材质”；本组不自行批准新背景或宣称跨模块风格统一。
2. **真实宿主组合与运行实施尚未做**：当前仍公共导航截图＋原右战场上下文，非同版完整原生宿主。连续滚动、输入焦点、真实切换／支付均无实施或新验证。后续获授权实现即时切回，须配套移除现Owner同槽10游戏秒锁；本设计不改该规则／代码，不牵连其它冷却。
3. **未见真实极端字段仍不报覆盖**：已有真实paidLv19／MAX444长值可用；更多长名称／paidLv／原因或真实额外资源须对应域来源，不能造第三资源、业务参数或把当前样例泛化为所有内容。

本轮发生实际平台上下文压缩，已向根据实报告；只完成当前自然项的导出／来源／文档／Git固定，随后handoff停止，不新扩批。无权限拒绝或不明执行结果；剩余为上述具体审阅／阶段依赖，不能说已获用户完整版本通过或等用户验收。

## 历史与保全

[04149原入口原文](README-04149-history.md)保留旧29–41状态与审阅上下文；原01–41 SVG／PNG本轮字节未变。c9全108是被退回的容量提案，不是定稿；24–28为临时插画过程，不作当前主稿。历史文档的“尚未有材质／长字段／focus”由本入口当前事实覆盖。原WIP、untracked导入元数据及tmp/cache原样保全。运行源码304／信息3916及取消806不恢复、不擅改。来源边界见[source-boundaries.json](source-boundaries.json)；无游戏运行／独立复测／main集成。
