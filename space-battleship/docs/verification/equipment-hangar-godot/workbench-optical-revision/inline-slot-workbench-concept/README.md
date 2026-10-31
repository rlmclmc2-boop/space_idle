# 当前：已认可R3方向的原生材质适配候选（未实际平台压缩）

运行源码 `81744e5a7da14577ea5792a621529f304ed82b3c`。已按用户认可的共同方向消费固定 `6e0e86c80d7cc7ee4f8623fca929c2f4828b6215`（实现059ac56b）最小运行材质，在原卡／信息面／下拉／按钮上替换旧样式；旧EquipmentSurface及灰化面初始化已删除，无新外框盖板或设计整屏贴图。**当前交根／原审看最新完整实机，未自判验收、未合main。**下方“材质源待到／仅诊断”是历史，依赖现已解除并完成。

- [最新完整审阅入口](review-r3-native.html)、[同版账本／源码hash](r3-native-adaptation/evidence/ledger.json)、[24.7秒真实动作](r3-native-adaptation/evidence/session-actions.mp4)、[41.05秒原录屏](r3-native-adaptation/evidence/session-raw.mp4)。真实main/native/config1440×900同一原驱动，最终exit0／failures0，无脚本错误或退出泄漏；19完整图逐张view，原／动作视频完整解码并顺序5帧view。早2自然，后5／8受控Owner恢复＋真实装备安装；unknown仍显式publisher注入，不声称自然故障。
- 原节点卡面使用operation_plate；普通键secondary、购买commit、选择键同源selected漆面与stepper-down SVG。原选择器是Button＋Owner真实弹层，故调用apply_operation_button(selected=true)与共享箭头，保原立即免费换装／切回，不强改OptionButton。compact只调每控件新建style上下内距1，保26px实尺寸；16px名称／属性／费用、单行当前→升级后、整卡操作与原裁剪／排序保。共享深浅文字角色与逐费数字红保留。
- 图标根因已闭合：42ea静态源从旧整屏裁图，携带不透明卡面；共同6e0e另存transparent-icons修订源按ID直接绘原纹理，14:52已投图字节保留。本真实UI本就走manifest Texture／ResourceVisuals.icon，此次继续统一原透明路径，无逐图手裁／mask／每帧去底。实际进口图像记录四武器及铁／铀／简并24px图四角alpha均0；完整浅卡图未见静态矩形底。见[原始诊断＋闭合来源](r3-native-adaptation/icon-source-diagnosis.json)及新账本实际记录；不把透明角点当所有内部像素均正确的证明。
- 最新 `f9244a30ad1843128aaa0a620c4dc3e4866685b2` helper原字节已经真实运行，装备报价／钱包支付必要边界保持；Equipment／Economy源相对a83不变，Session／Hyperspace奖励与chrono非本组闭包未强塞。父转同一Astra限定复核通过不冒全局整数／main验收。[精确必要范围](r3-native-adaptation/integer-source-f924.json)。
- 首轮compact复制自定义StyleBox丢script纹理字段，虽然业务断言0但日志有null texture，未报通过；现直接调整每控件工厂新建的独占style后整组重跑，首轮日志／JSON保留。新金属边曾令旧深色阈值把边框误当字，修辅助测量为语义核心字色后21卡为名称框→属性最小13px、费用字→卡底最小5px、起线差≤1px，仅辅助完整图判断。

当前授权的本组独立实现与受影响同版证据已完成，无公共材质／图标处理技术依赖；剩余是根／原审对当前真画面的裁定和各模块组合终审，不等旧用户意见。本人未实际压缩，无拒绝／未知结果或后台进程，原WIP／untracked.import／.uid／cache保全。原背景字节／变换与等比战场几何保持，不声称整张静态R3与实机逐像素相同，也不冒其它模块、性能或全局资源结算验收。

---

# 当前继续：用户已认可R3共同方向，原生适配进行中（未实际平台压缩）

本节覆盖下方“独立项完成／跨模块待方向”的旧状态。用户认可14:52实际送达R3，现同项继续适配，旧22395排版证据保留但不称新R3实机。已定位图标矩形底为R3静态源直接裁整屏截图、把旧卡面当图标；统一改为按稳定ID用原透明Texture／ResourceVisuals.icon，不逐图裁原图、不每帧去底。当前真实控件本已用原纹理。精确证据／当前材质依赖见[r3-native-adaptation/README.md](r3-native-adaptation/README.md)及[诊断JSON](r3-native-adaptation/icon-source-diagnosis.json)。现HEAD2fe87f93无新产品代码，本人未实际平台压缩；继续原目录／分支，不main。

---

# 2026-10-31 同卡字号／数字角色／真实裁剪修订候选（未实际平台压缩）

本节覆盖下方“恢复调查／实际压缩交接”与旧等待意见状态。用户新反馈已在原目录、原 `art/equipment-materials-main-20261029` 实施；当前运行源码 `22395e3aa67f9684bbf0d05fb503b6f770b77405`，保留原90px矩形卡／94px行、单行当前→升级后、整卡费用与数量／购买在框内。**交根／原审重新判断，未自判验收、未合main。**

- [本轮完整审阅入口](review-card-alignment.html)：早2／中5／晚8、长MAX、两种单项不足、上下完整端接、下拉／空槽／按钮／提示等19张同版1440×900原整屏；[23.2秒动作](card-alignment-revision/session-actions.mp4)、[43.55秒原录屏](card-alignment-revision/session-raw.mp4)、[ledger及版本／hash](card-alignment-revision/ledger.json)、[原驱动](card-alignment-revision/driver.gd)。均为真实main/native/config同线程，最终exit0/failures0，19整屏逐张view、整段视频解码与5帧检查。早期自然，后期Owner受控恢复／真实安装，不声称自然解锁；unknown回执用显式publisher注入。
- 名称、攻击力／容量标签、费用标签／资源名／消耗值统一16px，保既有字体角色；当前值、升级后收益、普通费用、不足金额消费 `190a21b47574a0a4f5c9c7be798f7ec38224d5dd` 的 `BridgeTheme.number_role_color/apply_number_role` 浅面角色。只取两函数／源注释，不覆盖整棵主题。图标原色，资源名身份色；不足仅对应数字红。费用同一24px行同基线，20px图标居中，图标→字／名称→数各4px、资源组12px；长MAX双费省名保完整数与0.5秒native精确原文提示。
- 名称、属性、费用共文字左沿，图标独列其下无内容；名称框下缘→属性墨迹21完整卡实测最小13px，费用墨迹→卡底最小5px，左沿差0。[墨迹支持记录](card-alignment-revision/glyph-spacing.json)只辅助判断，完整图才是可读性证据。
- 灰“舰炮 Lv.1”根因是原 `_create_card/_refresh_card/_update_visible_cards` 特意绘制的fragment身份续条，已删真实节点／分支；不是证实几十层、底图残字或重复整页。删除“逐槽工作台”、滚动提示和带数量组条的原节点，保武器→防御顺序、部分卡不可操作／聚焦及真实滚轮焦点释放。
- 底边根因是原滚动区 `(340,294,450,510)` 延至x790／y804，内容／滚条跨到原背景右内壁约x775和下斜角收口约y778。现原容器宽434／高484、卡与内容424、尾键左收8；晚8实测滚条 `(766,294,8,484)` 止于y778，末卡止于y774。[本轮前态底整图](card-alignment-revision/before-inline-native-bottom.png)／[本轮后态底整图](card-alignment-revision/inline-native-bottom.png)均保上下边界；原背景字节／变换保，未新增遮板／外框／mask，未全量刷新。
- 资源展示逐字消费 `36258b1eb8a2beca7ef9641477be05a7991031ed` 的 `player_text.gd`；费用和公共余额仍从既有native十进制原文调用 `resource_number`，属性仍 `number`，native tooltip不改精度。装备整数报价／支付必要域消费 `a83ad9c83aebdfc18ac98f4f784aeb16eca16da4`：helper原字节、Equipment最终费用whole_map、Economy钱包restore/accept及can_pay/payment边界。未取旧树或Research／Session／Hyperspace／产出／掉落等非本组变化；Owner极大整数 `×10^` 文本不拿来二次解析。**不声明全局资源整数化完成**。[精确消费范围](card-alignment-revision/sources.json)。

当前独立实现项与上述必要接线已完成；剩余为根／原审对本轮整屏及动态的裁定、跨模块整体风格和后台全局资源整数整合／双审，不等旧用户授权。无权限拒绝、未知结果或后台进程；本人未实际平台压缩，原WIP／untracked.import／.uid／cache保全。首次删组条曾显露Owner交错槽序，完整图检查后已修并重录；前轮图视频保留/tmp，不冒充本版。

---

# 2026-10-31 用户新反馈恢复调查／实际平台压缩交接

本节覆盖下方“等待用户意见/无独立未完项/未实际压缩”的历史状态。用户13:46反馈已结束等待，恢复同一排版项；本执行者随后发生**实际平台压缩**，按父既定要求在当前调查自然点保全并停止，供原地替换。接管核查HEAD为 `f6b0c6fa2bdcf019d5823ce3cbd5d645254a3ac7`，原 `art/equipment-materials-main-20261029` 分支；本轮尚无产品代码修改、采图或实机运行。tracked原先干净，既有大量untracked/import/uid/cache原样保留；无Godot/ffmpeg后台，无权限拒绝或未知执行结果。环境此前正常可用，本次仅核现场未重新启动引擎。

运行源码仍 `75b7a1918b2c988e81ebdb64e7006369189c77cc`，证据仍 `0f981d19658d2b7ce020d8de5e7fec1c50ee7841` 的19整屏/23.4秒动作；这些是反馈前候选，不能声称已解决本轮问题。共同数字源仍 `f688ea7c8856ad87775b0853044b9020303b8137`；退回的4bdea风格未消费。本次仅状态三文档及/tmp交接镜像，代码/图/视频/账本/旧SHA256SUMS快照不改，不main。

## 已准确定位，尚未修复

- 灰“舰炮 Lv.1”源于 `src/ui/equipment_panel.gd`：`_create_card`第362行为每槽创建独立fragment Label，`_refresh_card`第424行写装备名/Lv；`_update_visible_cards`第498–506行在卡非完整且overlap>=16时显示被动身份续条。原晚8内容高790、视口510、底部scroll280，weapon:2末约20px进入续条条件。这是明确的身份续条实现，**不是已经证实的旧层叠加、底图文字或重复整页绘制**。用户认为残字混淆对象，后续应删除无用续条实际节点/分支，保部分卡不可操作/不可聚焦。
- 原“逐槽工作台”来自第265行_heading；“↑ 返回武器/↓ 防御还有N槽”来自第511行_scroll_hint；武器/防御·数量组条来自_refresh_structure第327行起的真实Panel/Label。应按导航价值清理原节点/绘制，不能盖板遮住。当前没有取得运行时节点计数，不把源码推导数量冒充实测。
- 底部外漏需继续实际核边界：原ScrollContainer为(340,294,450,510)，名义右790/下804；内容宽440、卡宽432。用户图指向浅底板/侧条及滚动条越金属端接。**目前仅已核源码名义范围，尚未采本轮前图或实测底图可见收边**，不可把具体材质边缘坐标/唯一根因定案。后续从原裁剪/容器结构收紧，不新增外壳遮挡、不全页重建。
- 当前字号：名称16、属性18、费用标题/资源名/数字15。费用标题y64，资源名/数字在费区local y=-2，真实基线存在不同；图标到名3px、名到数值没有固定间隔。当前属性是单色Label。需统一装备名称、攻击/防御/容量标签、费用文字及数字字号和对应行落位；费用标签—图标—资源名—消耗值单行同文字基线、图标垂直居中、固定小空隙。以真实字形/可见边缘验证，长MAX/双费不得缩字号或丢量级。

## 下一执行者精确剩余

1. 在原目录/分支复用现有环境，先对原bottom及上下边界取同项前态和必要节点/边界证据，再最小改原equipment_panel布局：统一字号/费用基线/固定小间隔、语义数字层级、清续条及无用文案、结构修底部越框。没有已实施的新坐标方案，勿把讨论值当已验证结果。
2. 数字按当前稳定→升级收益醒目→费用清晰→不足仅对应消耗数字红的读序；图标原色，不全高亮。沿公共语义角色，父尚未给本轮新的字体/颜色共源固定入口，不自建公共体系；若需新增共同角色，列最小点由父协调。native tooltip仍精确原文，非一位小数。
3. **明确依赖**：用户资源展示及实际值整数（必要向上取整）由后台经济契约/整体资源显示共源交付；目前尚无资源专用接口及完整固定SHA。equipment `_render_fees`第435行仍集中调用PlayerText.number，便于最小消费；不可UI ceil、不可全局改通用PlayerText.number、不可重算Owner金额。等待权威费用预览/执行契约与资源专用formatter最小文件范围，其他排版项不以此全停。
4. 改后同一执行线程仅受影响的真实1440×900整屏/动作：既有2/5/8、上下边界、武器/防御、长MAX、双费/不足/按钮及必要滚动/焦点。复用 `/tmp/space-idle-workbench-rebuild/text-column-native.gd` 与当前name-column-revision驱动，注意其fragment、旧内容高度/scroll280和字体断言随结构变更须同步。后期沿既有Owner受控恢复，新增装备必须真实Owner换装几何事务；勿复发只restore装备ID造成左右不一致。保所有既有支付/切回/未知回执/局部刷新规则，不另开复测线程。
5. 新代码+同版图/视频/操作/状态账本固定普通Git推原分支，更新唯一入口交父/原审；当前既不是待用户，也不是本轮完成或main验收。跨模块新风格仍待整体，已退方案不接。

可复用Godot/native/config及历史证据详情见下方和 `name-column-revision/ledger.json`。`environment.md`原来未找到，勿杜撰。停止原因是**实际平台压缩后的交接要求**，不是权限或技术拒绝，也不表示上述未完项失去授权。

---

# 当前名称文字列与共同数字修订：同版实机候选

用户对19a2的新反馈已结束此前等待：名称框下缘与攻击力粘连、费用落在图标下方、卡名含槽序号需修正。本版运行源码固定 `75b7a1918b2c988e81ebdb64e7006369189c77cc`，在原90px矩形卡/94px行内让图标独占左列，名称只写装备名；属性、费用标题与名称真实字形左沿同列。名称框→属性留真实空隙，底部两键实际高度落实到26px且完整在卡内，替换原绘制/控件尺寸，不叠盖板。空槽仍仅实际选择入口，无假等级/属性/费用或购买。

数字直接消费整体 `f688ea7c8856ad87775b0853044b9020303b8137`：`PlayerText.number`共享k/m/b/t/kt及1e18起e指数、一位小数/跨档舍入；公共余额的Economy只读raw字段及ZoneShell同步共源，未另造格式器，未改Amount/Owner支付/装备规则。13及14§1按该固定规范同步，保原装备即时切回等现行契约。辅助悬浮保留native精确原文，不将悬浮也称为一位小数显示。长值实机为 `9.3k → 1.6e43`、双费 `1.1e39 / 2.8k`，对应原生真报价仍为MAX444。费用资源名中性、只有不足数字红、图标原色；数量切换不提交/不弹失败，实际单槽或批量执行拒绝后才短暂提示。

[本版19张完整实机整组](review-name-column.html)均为Godot4.7.2正常main/native/config的1440×900原始截图，作者逐张实际查看，含自然早2、中5/晚8空槽与装配、单双不足、长MAX、底部、材料未开放、hover/pressed/focus、原地下拉及真实拒绝。自然早期之外的阶段/钱包/等级明确使用既有Owner受控恢复；新增装备经真实换装几何事务，左右五武器一致。未知回执为显式publisher故障注入，不称自然/native故障。

最终同线程受影响流程退出0、failures=0，无脚本/资源泄漏错误；[账本](name-column-revision/ledger.json)、[操作JSON](name-column-revision/operations.json)、[驱动](name-column-revision/driver.gd)、[原始日志](name-column-revision/runtime.log)绑定源码/共享源/native/config与原图hash。[同版动作录像](name-column-revision/session-actions.mp4)23.4秒来自[原始42.6秒录像](name-column-revision/session-raw.mp4)18.7–42.1秒，仅去启动/退出时长，不裁图/叠画/变速；完整解码并实际抽看五帧。前两轮真实按钮越卡的48项失败原日志/状态保全，未用旧0失败覆盖最后补丁。

真实整屏之外，[字形像素辅助记录](name-column-revision/glyph-spacing.json)在21个完整卡的原图区域测得名称框下缘→属性字形最小12px、费用字形→卡底最小6px，名称/属性/费用字形左沿偏差0px；只作原图支持，不以Rect/数值代替本版整屏审。此前23静态稿、19a2五图和04ae视频均保历史，不作为本次新排版/数字通过结论。

父新审结事实：既有原审已整看证据 `0f981d19658d2b7ce020d8de5e7fec1c50ee7841` 的19整屏，并按每0.25秒顺序抽帧查看23.4秒动作；根亲看early/bottom/long，认为本轮排版具用户评价条件，已实际发送这三图请求确认。**当前本轮排版等待用户意见；跨模块风格尚未通过，待整体新方案**。这不是全游戏、最终或main验收，无独立原未完实现项，保留候选不重复设计/测试。无公共源/技术依赖、权限拒绝、未知结果或后台进程，未实际平台压缩；原工作区/art分支/WIP/untracked/import/uid/cache保全，不main、不新任务。更多未见极端字段仍需域真源。本次仅同步状态三文档；`SHA256SUMS`保留0f981证据快照，代码/图片/录像及账本不变，状态文档旧hash不代表当前未变。以下为历史版本，本节优先。

---

# 当前公共资源条修复：同版用户确认图

父已转达04ae5710装备候选获原审限定通过：2/5/8、空槽、长MAX、左右五武器及底部操作成立；不代表main或用户最终验收。当前只消费整体固定 `459df59315e20708075bda5fafe9ef8408b69a7d` 的 `src/ui/zone_shell.gd` 资源条净宽/数值格式化落位修复，运行代码固定 `d354e60f1530435a6790cca0814ddc7e76f84f82`；相对04ae，src/assets仅此一个文件有差异，装备内部与共同资产原字节保持。

[五张同版完整确认图](review-resource-rail.html)：自然早2、中5真实空槽、晚8顶/底、真实长MAX444。全部Godot4.7.2正常主入口原始1440×900实图，已逐张实际查看。普通铁 `9.99万`、长铁 `1.235e39` 直接读出量级，悬停仍保官方完整行 `铁：1.235×10^39`；各格实际字体墨迹宽均不超过可用宽。金额/Owner/业务算法未改，后期仍用明确受控Owner状态和正常换装几何事务。

本轮只运行资源条受影响确认，退出0、failures=0，无脚本/资源泄漏错误；[源码/证据账本](resource-rail-confirmation/ledger.json)、[操作状态](resource-rail-confirmation/operations.json)、[驱动](resource-rail-confirmation/driver.gd)、[原始日志](resource-rail-confirmation/runtime.log)齐全。未重跑完整交互链或重录视频；04ae完整操作/滚轮/未知回执视频继续只绑定此前公共条版本，不冒作当前公共条新视频。整体459共享五图也不替代本分支这五张。

父最新转达：证据固定 `19a2ba967cd265673a40b9d526db88671b5f1924` 的五态正式实机整页已由根亲看，并获既有独审对当前可评价范围的限定通过；根已实际向用户发送五图请求确认。**当前仅此候选等待用户意见**，不表示全游戏完成、最终验收或main接纳。无独立原未完实现项，保全现场，不再微调或运行检查。当前无公共源依赖、技术阻塞、权限拒绝、未知结果或后台Godot/ffmpeg；未实际平台压缩，原工作区/分支及untracked/import/uid/cache保全，不main。更多未见极端指数仍须同域真实来源，不扩称无限域覆盖。本次仅同步已发生的审阅/投递状态；`SHA256SUMS`保留19a2证据快照，运行/图/视频及其账本均未改，当前状态文档不借该旧hash声明未变。下方为04ae整组及历史证据，当前状态以本节为准。

---

# 装备矩形卡与正式公共宿主：同版实机候选

已在原工作区/原分支完成正式公共宿主最小闭包接入，运行源码固定 `8430cd9c8cd84372e0218762daab986e989f3fbe`。按0fccb579交接只取bfe5a193公共壳/主题/资源身份与必要资产；main保原e3、仅窄接公共挂载/导航/状态，原战场投影和输入路径保持。反应堆/星球独立页禁用，未带入其内部实现。精确来源见[公共闭包](formal-host-source.json)，不再等待旧缺源。

[同版真实整屏审阅页](review-formal-native.html)包含15张1440×900原始Godot截图，以及[操作视频](formal-native-actions.mp4)和[原始全程录屏](formal-native-raw.mp4)。[源码/证据账本](formal-native-ledger.json)、[操作JSON](formal-native-operations.json)、[驱动](formal-native-driver.gd)、[原始日志](formal-native.log)绑定同版源码和本地native/config哈希。最终补齐滚轮/Owner几何同步后的真实流程退出0、failures=0，无ObjectDB/资源泄漏警告；15张最终整屏均实际查看，视频完整解码并抽看原帧。本轮原始录屏33.6秒，操作段17.7秒，仅从原始15.2–32.9秒截取，原始录屏含启动和退出空白，不裁图、不加速、不美化。

早期2槽为自然启动；中5/晚8为既有Owner公开恢复/真实换舰形成的明确受控状态，含原生发布与真实支付。后期只恢复付费等级，新增装备经五次真实Owner换装事务安装，右战场与左预览均已实际显示完整五武器；此前直接恢复装备ID未触发右战场挂载几何的取证方式已替换，9818145d证据只作历史。中晚空槽完整保留，不只交满装图：空槽卡只留装备选择，无现装Lv、—→—、费用、数量、购买、比较假对象；点击旧购买位置不发命令，真实免费装配成功后才恢复现装升级控件。Owner本来保存并允许购买空槽的“槽位等级”，未改规则；批量仍走原Owner全槽命令，界面准确称全部槽位升级/槽位Lv。静态80也同步此语义，另22态SVG/PNG字节保持11632386。

完整矩形卡、单行当前→升级后、逐费不足红、图标数字/0.5秒资源提示、不足可点且真实拒绝后短暂反馈、数量循环、免费即时切回、MAX材料禁用、局部刷新焦点、真实滚轮连续顶底输入与残行不可操作、底部下拉与公共导航互斥均有本轮受影响实机证据。材料未开放明确显示真实领域原因并保持控件净空。未知回执保护使用显式publisher故障注入，不称自然/native故障。无新业务公式、config或其他战斗规则变化。

[23张静态审阅](review-current-group.html)、[静态账本](rectangular-card-manifest.json)仍与真实运行分别标注。旧3946静态通过、旧宿主wip图/视频及a5da组合参考都不替代本版审结论；原始过程日志和一次驱动数组索引错误保全并解释，不冒充全程无失败。

当前实现及其受影响证据已完成，交根/原审判断新矩形卡、空槽和正式整屏；不自判验收、不合main。更多未见极端字段仍需对应装备域真源。尚未实际平台压缩，无权限拒绝、未知结果、后台Godot/ffmpeg或未完成技术接入依赖；原WIP/untracked/import/uid/cache保全。精确交接见[NATIVE-WIP-HANDOFF.md](NATIVE-WIP-HANDOFF.md)、[pending-work.json](pending-work.json)。下方为历史来源，旧缺源/未实施状态由本段覆盖。

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
