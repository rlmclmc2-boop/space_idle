# main装备材质与循环数量候选：待视觉审查

用户最新判断：“装备用main这版继续做，不认为质感达标，只能功能没问题”。因此main `e3b38d7b6d8256f6031e1b086c7db7812b6a441f` 只作为功能/布局基线；本候选不是美术通过。新增统一规则亦在同批落实：单槽与批量由并排数量键/OptionButton改为单一循环数量按钮，购买独立执行。固定运行源码 `ba7afb2468ef74529e6dd57f68d183e70fbf9d22`，原目录原Godot/native/缓存继续，不pushmain。

## 从整屏问题到实际材质

先实际查看main-integration/04真实整屏：机库具有方向光、结构和磨损，工作台/候选/按钮却是平面浅底与单色框；它们缺乏共同表面与受光关系。当前用一张原始imagegen无字材质atlas实装搪瓷台面、涂漆金属控件、浅玻璃读数及绿金属选择态；没有替换正式舰船/武器/机库背景，也没有烘文字、数量或报价。

[原始atlas](../../../../../assets/ui/equipment/materials-20261029/material-atlas.png)、[完整提示](../../../../../assets/ui/equipment/materials-20261029/imagegen-prompt.txt)、[来源及hash](../../../../../assets/ui/equipment/materials-20261029/sources.json)随资产归档（路径相对本页见Git目录；资源绝对res路径为res://assets/ui/equipment/materials-20261029/）。实际生成工具image_gen.imagegen；无浏览器或HTML替身、无云端Blender假称。原生成PNG同时保留/workspace/generated_images，输出SHA256及提示SHA256可复核。

Godot初始化时将四象限缓存为两类消费：192×128细边控制面、去掉32px源边缘的512×336非交互面。原生StyleBoxTexture直接替换对应面，Button正常/hover/pressed/disabled/selected仍用原生输入选择缓存样式，焦点仍原生样式。读数/图标底/报价/标题采用去边缘面，避免重复黑框；顶部/台身/控件共用同材质语言和暖光取向。只有实际按钮与台体外沿保留细边，不叠旧SVG或另加无意义组件。原中文、数值27px字形组、报价/状态均原生。

作者首轮真实4图见/tmp/equipment-material-preview（原驱动/日志/PNG保全）：当时重复生成框及大面小采样显糊，实看后已收掉非交互面边缘并保细材质分辨率；它们不是最终源码证据。下方5图与视频全部采于上述ba7固定源码。

## 新的报价—数量—购买关系

左升级工位为一个实际操作组：逐资源报价在上，96px循环数量与292px独立购买在下，共用浅嵌入面；没有沿用旧三键空位或把购买机械拉满整条。右工位保持候选/异物比较与独立安装，和左侧同操作基线。首内容y70/左右标题/正式图/字体保持，单资源整台250px、双资源272px，更多真实行按22px增加；异物比较至少272px。所有价格来自Owner，UI只逐行放置。

单槽循环×1→×10→MAX→×1：仅标记_comparison_dirty，更新当前报价/可买，不重新读取全槽、不发购买。批量每槽×1→每槽×10→逐槽MAX→每槽×1，与独立执行/关闭同一操作行，列表上方只保当前槽等级；按实际槽数收紧窗口（本次2槽286px）。原OptionButton及所有get_popup/selected专属引用已清理；has_exclusive_ui仍持有Batch，普通隐藏拒绝、force回收保持。

Owner命令、价格/MAX搜索/顺序/准入、last_result/command_finished、当前等级与失败/未知状态语义不变。未恢复记录、最近结果、Toast、成交tooltip或成功提示条。装备切换10游戏秒冷却、未解锁纯空位、舰船主体、原真实武器/防御身份不变。

## 同版原尺寸与动态

正式main.tscn/Session/native Godot4.7.2、1440×900根窗口/808模块；独立临时设置存档，已有Xorg :99/native库。解析exit0、运行exit0：`EQUIPMENT_MATERIAL_AND_CYCLE_COMPLETE failures=0 frames=158`。[32条实际观察/操作](operations.json)、[原驱动](capture-driver.gd.txt)、[日志](runtime.log.txt)、[解析日志](check.log.txt)。

5张根视口原尺寸整屏已全部实际view_image：

- [真实新局、材质及资源不足操作组](01-fresh-materials-and-quote-group.png)
- [真实Owner双资源报价/循环数量/独立购买](02-double-quote-cycle-and-purchase.png)
- [异物候选/比较/安装及单资源不足](03-different-candidate-materials.png)
- [真实安装后当前装备与10秒冷却，无最近结果](04-installed-current-state-no-recent-result.png)
- [批量每槽×10及当前等级](05-batch-cycle-current-state-materials.png)

动态取自同一真实进程158张frame_post_draw帧，无重绘/拼图：

- [13.17秒加速审阅片段](materials-and-cyclic-controls.mp4)：同顺序158帧按12fps封装，仅为快速看材质/原生按下与模式关系，**不是实际操作时长或性能证据**。
- [96.88秒原采样时间片段](materials-and-cyclic-controls-realtime.mp4)：按[实际时间戳](frame-times.json)变帧率封装，PNG保存造成采样间隔较大，不能当运行帧率测试。原158 PNG保留/tmp/equipment-material-final/frames，逐帧[hash](frame-manifest.json)归档。

作者实际检查5整屏及视频来源中的模式/按下代表原帧，未把“编码成功”当视频品质或视觉通过。操作中单槽完整3次循环、批量完整3次循环都比对钱包/真实槽/native状态无变化；单槽独立×10成交count10，随后MAX成交count4与Owner报价一致；批量独立每槽×10两槽均count10，界面等级与Owner一致。切数量只更新报价且slot_fact_reads不增加。实际安装后冷却显示，Batch普通hide拒绝/force释放保持。解锁/Lv19/预算来自公开restore与发布口受控准备，不证明自然成长或自然收入。

## 边界

[保留函数/文件hash](preserved-boundaries.json)绑定main：main/Session/Owner/Economy/CampaignView/project、正式机库/manifest/共享几何逐字不变。运行改动仅equipment_panel.gd，新增材质资产及来源；没有主线、宿主、战场/逻辑输入、配置、业务公式改动。不重复原全保护/全舰满装/Windows-DPI/长期性能/完整保存替换/极端长金额专项。当前正式生产仍最多铁+简并物质两费，无真实第三费用，未造三资源fixture。当前重排已实看普通双资源与操作后的单资源；极端1e39新布局未重新取图，不冒充旧ce70图。

本候选仅完成可审实物；台面反差、金属细节密度、候选材质与整个机库的协调仍交原Astra/根实图把关，不自判美术达标。未实际上下文压缩、无额外任务/子代理/新workspace，不Library/Space，不直接pushmain。
