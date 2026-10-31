# 当前：已认可R3方向的原生材质适配候选（未实际平台压缩）

运行源码 `81744e5a7da14577ea5792a621529f304ed82b3c`。已按用户认可的共同方向消费固定 `6e0e86c80d7cc7ee4f8623fca929c2f4828b6215`（实现059ac56b）最小运行材质，在原卡／信息面／下拉／按钮上替换旧样式；旧EquipmentSurface及灰化面初始化已删除，无新外框盖板或设计整屏贴图。**当前交根／原审看最新完整实机，未自判验收、未合main。**下方“材质源待到／仅诊断”是历史，依赖现已解除并完成。

- [最新完整审阅入口](../review-r3-native.html)、[同版账本／源码hash](evidence/ledger.json)、[24.7秒真实动作](evidence/session-actions.mp4)、[41.05秒原录屏](evidence/session-raw.mp4)。真实main/native/config1440×900同一原驱动，最终exit0／failures0，无脚本错误或退出泄漏；19完整图逐张view，原／动作视频完整解码并顺序5帧view。早2自然，后5／8受控Owner恢复＋真实装备安装；unknown仍显式publisher注入，不声称自然故障。
- 原节点卡面使用operation_plate；普通键secondary、购买commit、选择键同源selected漆面与stepper-down SVG。原选择器是Button＋Owner真实弹层，故调用apply_operation_button(selected=true)与共享箭头，保原立即免费换装／切回，不强改OptionButton。compact只调每控件新建style上下内距1，保26px实尺寸；16px名称／属性／费用、单行当前→升级后、整卡操作与原裁剪／排序保。共享深浅文字角色与逐费数字红保留。
- 图标根因已闭合：42ea静态源从旧整屏裁图，携带不透明卡面；共同6e0e另存transparent-icons修订源按ID直接绘原纹理，14:52已投图字节保留。本真实UI本就走manifest Texture／ResourceVisuals.icon，此次继续统一原透明路径，无逐图手裁／mask／每帧去底。实际进口图像记录四武器及铁／铀／简并24px图四角alpha均0；完整浅卡图未见静态矩形底。见[原始诊断＋闭合来源](icon-source-diagnosis.json)及新账本实际记录；不把透明角点当所有内部像素均正确的证明。
- 最新 `f9244a30ad1843128aaa0a620c4dc3e4866685b2` helper原字节已经真实运行，装备报价／钱包支付必要边界保持；Equipment／Economy源相对a83不变，Session／Hyperspace奖励与chrono非本组闭包未强塞。父转同一Astra限定复核通过不冒全局整数／main验收。[精确必要范围](integer-source-f924.json)。
- 首轮compact复制自定义StyleBox丢script纹理字段，虽然业务断言0但日志有null texture，未报通过；现直接调整每控件工厂新建的独占style后整组重跑，首轮日志／JSON保留。新金属边曾令旧深色阈值把边框误当字，修辅助测量为语义核心字色后21卡为名称框→属性最小13px、费用字→卡底最小5px、起线差≤1px，仅辅助完整图判断。

当前授权的本组独立实现与受影响同版证据已完成，无公共材质／图标处理技术依赖；剩余是根／原审对当前真画面的裁定和各模块组合终审，不等旧用户意见。本人未实际压缩，无拒绝／未知结果或后台进程，原WIP／untracked.import／.uid／cache保全。原背景字节／变换与等比战场几何保持，不声称整张静态R3与实机逐像素相同，也不冒其它模块、性能或全局资源结算验收。

---

# R3 已认可方向：同项原生适配进行中

用户已认可14:52实际送达的42ea4ffc R3共同方向并要求解决图标底色；本轮恢复原任务，保2fe87f93的16px字号、共享数字角色、费用同排／逐费不足、原裁剪和武器→防御顺序，不main、不新工作区或独立复测线程。本人未实际平台压缩。此页仅当前调查，不把旧22395运行证据称R3新实机。

已读共同最新681a07fd入口、42ea4ffc原R3绘制源和完整晚图。**图标方底的直接来源是把旧整屏图裁区当成图标**：equipment_row第78行装备、第92／96行资源都用source截图draw_texture_rect_region；导弹42×48裁区2016像素alpha全255且角点为旧卡RGB(220,226,215)，双费19×19裁区361像素alpha全255且角点为旧选中卡RGB(210,221,211)。这比原PNG角点透明更直接；原图透明不代表截图裁片透明。具体源SHA／范围／alpha统计见[诊断JSON](icon-source-diagnosis.json)。

统一路径应由稳定装备／资源ID直接绘制原alpha Texture2D或ResourceVisuals.icon；不手工逐图裁原图、不为每图造mask、不每帧去底、不把modulate或导入开关当去不透明底。当前真实装备控件已经用manifest透明纹理和缓存ResourceVisuals.icon，不使用整屏截图图标；正式R3接入将保留这一路径。原资源图集裁区属于已有共同身份源，本组未擅改其边界。Godot导入配置仍alpha通道、lossless、premult_alpha=false；官方[导入说明](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html#process-fix-alpha-border)指出Fix Alpha Border处理滤波边缘，不能消除已烘入的不透明底。

整体正在固定最小R3材质源；本组需精确plate／card九宫格源矩形与边距、ordinary／primary／select各normal／hover／pressed／disabled／focus和选中态材质／文字角色。当前可用数字角色190a已接；不整棵覆盖BridgeTheme或从设计截图提纹理。源到后在原EquipmentSurface、原card、原select和原buttons替换材质，不新增层盖旧控件，复用现有真实2／5／8及长MAX／双费／不足／tooltip／边界驱动采同版完整图与动作。

后台a83最新共同入口称奖励恢复校验和chrono分帧仍待修，不把它称最终全局整数源。本分支此前仅接装备报价／钱包支付必要域，未接上述奖励／chrono方法；该窄接事实和原运行证据保持，新后台源由父／原组固定后再核本组必要范围，不自主扩整棵Owner树。

后台新固定修复 `f9244a30ad1843128aaa0a620c4dc3e4866685b2` 已按本组必要域接入：只更新原字节 `resource_amounts.gd`（valid_id共用谓词；whole_map原非法键条件不变），Equipment／Economy源相对a83无差。GameSession chrono／超空奖励与Hyperspace奖励恢复方法未在本组旧闭包接入，不强塞无关两文件。父提供同一Astra限定复核已过事实，非全局／main验收；精确范围见[整数源记录](integer-source-f924.json)。当前只解析核，旧22395图hash仍属历史，最新R3实机将绑定本helper。
