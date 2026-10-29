# 装备整体材质打磨候选：玻璃、漆面按键与原壳同族（待原审）

当前同版源码 `a8467d65653b33e818f79bbe33fae59b0df4d795`；基线 `67b1ed3a89d25e48d3374b6e3c2c5a4241070501`。67b1只完成资源家族同步，标题/图标局部可接受从未等于整体质感通过；原SOL此前把“等具体反馈”写成没有未完问题而停止了原目标，已纠正唯一入口和HANDOFF。原整体目标仍未闭合，本候选供原Astra与根判断，**不自判整体艺术完成**。

## 同版实物

[常态整屏](01-double.png)／[原像素工作台](01-double-local.png)、[异候选整屏](02-different.png)／[局部](02-different-local.png)、[Batch整屏](03-batch.png)／[局部](03-batch-local.png)全部实际view_image。三整屏1440×900；工作台/Batch局部由同一个根viewport真实控件rect扩4px截出，不缩放、不补绘、没有预览图上的人工美化。

同版[原生状态审阅视频](native-control-states.mp4)长15.52秒，来自24个实际根viewport原帧，包含普通、鼠标悬浮、悬浮按下、按住移出、释放后键盘焦点、Owner当前报价不足的禁用态。六代表局部也全部实际view：[普通](state-normal-local.png)、[悬浮](state-hover-local.png)、[悬浮按下](state-hover-pressed-local.png)、[按住移出](state-pressed-outside-local.png)、[键盘焦点](state-keyboard-focus-local.png)、[不足禁用](state-disabled-local.png)。[原状态/时钟/前后事实](visual-operations.json)、[24原帧hash/时序索引](frame-index.json)、[驱动](capture-driver.gd.txt)、[原日志](runtime.log.txt)保留。

图片是受控Lv19/availability/钱包场景，不证明自然解锁或全目录准入；disabled只将钱包受控设为0并消费Owner报价，没有假装第三生产费用。原帧写PNG影响采样间隔，视频按实际采样时序编码，不能当帧率、输入延迟或长期性能证明。作者已实际查看当前整屏与全部代表状态原像素图，视频提供原审连续查看，不以编码成功代替艺术判断。

## 原来未完成的点与实际替换

67b1的仪表只是单色灰矩形，候选只有平片，按钮是平填+5%微粒，标题为独立平填；它们覆盖手绘壳，而没有同一设备的材料/光向/接触关系。本次不改结构和信息位置，直接替换这些原StyleBox的绘制消费：

- 仪表和候选承托使用同源玻璃内面，保有宽缓、低对比的玻璃反射与滚光；原StyleBox内按真实软轮廓绘制、单一2px轻接触阴影。撤旧灰片，没有新Panel或硬凹框。
- 主操作为暖香槟漆面键，数量/全部升级/Batch模式键为海军蓝漆面键；都有可见上肩、面与窄接触唇，属于机库同一手绘家族。原生Button文字、点击区和state缓存保持；按下只下沉1px并适度压暗，不做厚斜面。
- 原标题六边形切角几何完全保留，改以同批海军蓝漆面直接填充裁切轮廓，替换原平色，不加盖角或第二背景。外壳仍唯一原壳、32px固定角部、连续九切片中心，船/机库源完全没改。
- 旧satin微粒消费、平填skin及闲置的皮肤分支撤除；旧源资产保历史，不在新控件皮肤上再叠噪点。当前变化不是只改颜色、加噪点或加厚框。

首轮实际看图发现生成玻璃带的外框/深色角进入小控件，形成黑色硬角；原/tmp/equipment-material-polish保留，最终仅取玻璃内面、原绘制用软轮廓收边。随后真实状态图发现默认键盘焦点白字在金面上对比不足、按下压暗过多；当前源显式保持主键INK焦点字色，按下调制改0.84/0.86/0.88，再取完整同版证据。原单笔“购买1级”hover重复tooltip会挡邻近内容，现只有动作文字实际超出安全宽时才补完整tooltip，付款失败理由/费用tooltip仍保留；没有删实际代价或新建记录。

作者观察到材质面/边、玻璃与承托、按键与标题的笔触已相互衔接，且焦点/按下字形可读；这些是候选变化说明，**机库整体统一、精致度和整体艺术是否达标仍须原审**。

## 单批素材及实际消费

本批只生成一张[空白三材质源](../../../../../assets/ui/equipment/materials-20261029/control-materials.png)，实际image_gen.imagegen；原图 `/workspace/generated_images/exec-b5bf049a-61ff-4974-9a8c-98b23b56a8d2.png`1448×1086透明PNG原样保留。源SHA256 `707d137c2201aa0e9f33d730675402cff2b9195d26282d6305a66b22e37e5d6c`；[完整prompt](../../../../../assets/ui/equipment/materials-20261029/control-materials-prompt.txt) SHA256 `80dfe0a43a921fc53ef3ed755df14b593c150ed74cfabfe4850df44a62a9b6fd`；[参考图/hash/采样元数据](../../../../../assets/ui/equipment/materials-20261029/control-materials-sources.json)。不含文字、数值、图标或烘焙交互状态，不新造舰船、机库或资源身份。

初始化取glass `(94,180,1260,172)`，primary `(42,472,1366,224)`，navy `(42,772,1366,204)`，header `(120,800,1200,130)`；统一按每角色自身比例缩到64/36px高后缓存。玻璃明确排除生成源的结构外框和角块，只消费内材料；原生软轮廓与薄接触阴影负责真实控件边界。两个键面6px固定原尺寸边片/角部，中心伸缩；文字仍原生、布局仍原rect。没有把完整图集跨比拉伸覆盖工作台，也没有在更新时裁图/采alpha或创建新控件。

## 版本与功能边界

原生质感主源b4ccb834，4135a122只去可见短动作重复tooltip，当前a8467d65再修真实焦点字色/按下亮度；**本目录所有图、视频、操作都属于当前a8467d65**，不把前版预览冒充当前。原前序预览、原单壳/67b1证据均保留其真实版本含义。

[source-boundaries.json](source-boundaries.json)核25个逻辑/布局函数逐字67b1，包括两键/费用/资源、数值精准刷新、选项与批量、独占生命周期；comparison除tooltip显示条件外逐字一致。main/Session/Equipment Owner/Economy/CampaignView/project/机库/原壳/08e资源helper与两个资源图集逐字67b1。当前仍266/288px工作台、原27/17/16等字号、同样点击区与船主体/投影；归档重排/按需详情/压缩提案没有实施，也未接共享宿主或其他模块。

Godot4.7.2 check-only通过；正式当前main.tscn/Session/native同版视觉过程exit0，`EQUIPMENT_MATERIAL_POLISH_FINAL_COMPLETE no_purchase=true frames=24`。鼠标按住移出后释放，记录的Owner槽事实/预算/last_result前后完全一致；只是本次取消动作没有购买，不能冒称新交易全保护通过。旧36项仍只绑定89ac5d0a，同预算未新测、没有新36/交易全链/全舰/自然发展/完整保存/长期性能。非raw源码/文档diff-check通过，Godot原始check.log尾空行保留。

当前整体质感目标仍未获原审通过；本组应依同一原审具体品质意见继续原项，不能因图标或标题局部接纳就宣布原目标完成。普通Git候选只供原审，不pushmain。原workspace/分支/cache/未跟踪/所有tmp保全，本SOL截至本自然项归档未实际上下文压缩，无运行任务/权限阻塞；无新任务/子代理/工作区/Library/Space。
