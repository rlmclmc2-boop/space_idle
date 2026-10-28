# H2：Godot 4.7.2桌面设计预览

这是本任务内的宿主设计呈现，供整屏/字体审查，**没有实施运行接入、没有加载Session/native/配置或存档，也没有改变各组内部**。`main.gd`和`src/`未改。65px仍是候选；原组书面安装说明由根线程协调，不因这次预览批准。

## 本轮主审画面

- [Godot普通整屏](evidence/normal-1440x900.png)、[Xorg实际客户区](evidence/normal-x11-client-1440x900.png)。
- [更多展开](evidence/more-1440x900.png)、[收起](evidence/collapsed-1440x900.png)、[恢复](evidence/restored-1440x900.png)。
- [有限指数金额](evidence/large-values-1440x900.png)、[长指数完整公开文本](evidence/extreme-values-1440x900.png)、[保存失败完整说明](evidence/save-failure-1440x900.png)。
- [Godot原始尺寸/字体记录](evidence/godot-design-record.json)、[实际运行日志](evidence/godot-preview.log.txt)、[环境与hash](environment.json)、[同版可审源码](host_design_preview.gd)。

七张画面直接取Godot根Viewport纹理，没有经过拼图、裁切或改字；另保留X11客户区捕获。客户区/根Viewport/PNG均1440×900，窗口模式、X11、屏幕缩放1。HTML只留作历史排版探索，不是用户主交付，也不作为Godot字体或品质证据。

## 呈现边界

左模块根808×900、右区域632×900；真正的Godot SubViewport为572×960，SubViewportContainer位置(855.875,0)、等比0.9375，显示536.25×900。切换设计状态保持这些值，盾甲/航程/即时统计仍在该逻辑视口。没有因导航为背景扩宽或缩小模块。旧HUD的“空格暂停/G驻守/点击掉落领取”常驻教学文案已从本设计预览移除；Space、G和拾取功能在实际接入时保留，不改战斗逻辑。

占位身份必须一起审：

- 反应炉底板使用原组`4e1c4c2b`最新品质候选PNG，比例0.6与原点(96.8,20)不变；标签/控制台仅按该版位置作静态安装占位，没有重选59dd内部方向，没有业务/动态绑定。原组后续提供真实Control替换整个占位，宿主不保留这份复制展示为模块实现。
- 等级2放在左侧非设备带是待原组确认的协作建议；不能因本图已有等级便视为安装冲突关闭。装备、星球等其他内部尚未装入本预览，不宣称全部模块可装入。左右静态网格只作低对比环境占位，不能据此认定原巨缝已解决；背景边缘与等级仍待所有者安装确认。
- 战场使用既有背景、正式Frigate/laser原PNG作静态空间占位；保持逻辑视口和投影边界，但不是native舰船装配/炮口/战场动态验收，不把静态姿态当实际战斗状态。
- 余额/等级/进度/通知等全是设计样例；已有保存/驻守/暂停口没有被调用。更多、收起、恢复与资源详情仅切换预览自身Control；其他入口/模块动作没有业务绑定。没有新增后端或通用计算中心。

因此这里可以审Godot实际字体、顶部密度/外框/场景衔接与状态呈现；不能据此批准业务接入、自然开放、模块动态品质、输入全链或性能。

## Godot实际字体与按钮结果

仓库NotoSansSC字体直接读取，禁止系统回退；宿主450字重，模块占位400。实际TextServer RID坐标为`wght(2003265652)=450`，没有只核设置字典。设计字号16px，Godot字体行高24px（ascent19、descent5），不同于浏览器墨迹16px；先前HTML不能替代本结果。

首轮Godot呈现发现按钮创建时会被默认最小尺寸撑到32/33px，y34会越过65px边界。已修正预览装配顺序：控件入树/主题/图标就绪后设尺寸；最终九项均为y34、高30、底64，最小高度28，全部实际留在65px带内。没有把超过带高的首轮图记为通过。

| 项目 | Godot测量 | 结论范围 |
|---|---|---|
| 铁/铀有限指数示例 | 各143px文字 / 152px可用 | 名称和数量级完整；见实际整屏。 |
| 时空微粒有限指数示例 | 191px文字 / 200px可用 | 无截断；不外推所有金额长度。 |
| 九个顶部入口 | 实际80或96px宽、30px高，font_size16，最小高28 | 最小尺寸均能容纳，实际rect全部在65px带内；舒适度仍由视觉审。 |
| 无界长指数 | 明确的“完整值”入口＋完整公开文本详情 | 不截掉指数、不在宿主重算Amount；极值呈现策略仍待审。 |
| 保存待写入/失败 | 独立短状态＋完整故障说明 | 只审设计语义，实际状态需既有SaveFiles结果。 |

## 本次窄修：旧教学提示与缺字

此前长指数图中的`完整值 ▸`含U+25B8，原独审确认在仓库NotoSansSC cmap缺失、系统回退关闭时出现缺字框。该旧状态不记字形通过。现仅改为“铁：查看完整值 / 铀：查看完整值 / 微粒：查看完整值”，所有替代字均在同一字体cmap内；已用同版Godot重出[长指数状态](evidence/extreme-values-1440x900.png)，[修正记录](evidence/glyph-correction.json)保留原缺陷与替换依据。未改变字体、字号、既有布局或重新开放其他已认可排版。

同版图集另移除旧HUD常驻教学提示；这不删除实际功能快捷键，不改战斗逻辑。左右网格和等级仍标占位、待所有者确认，不以网格线认定巨缝解决。其余视图只是保持同版导出，不扩大视觉或实施审批。

## 固定环境及复现

沿仓库既有`docs/verification/equipment-hangar-godot/environment.json`取官方4.7.2 zip及SHA512。新下载同时匹配官方校验文件和原记录；可执行文件SHA256仍为`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`。Xorg dummy配置复用同来源，1440×900，OpenGL compatibility、Mesa llvmpipe。未替换系统4.6.3，未建新项目/工作区，工具继续保留于/tmp以复用。

在`space-battleship`运行现有工程中的设计脚本：

```bash
DISPLAY=:99 \
XDG_DATA_HOME=/tmp/space-idle-runtime472/data \
XDG_CONFIG_HOME=/tmp/space-idle-runtime472/config \
XDG_CACHE_HOME=/tmp/space-idle-runtime472/cache \
/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64 \
  --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --resolution 1440x900 --position 0,0 \
  --script res://docs/ui-redesign-plan/shared-host-shell/godot/host_design_preview.gd
```

默认在同一Godot进程呈现七个设计状态并导出后结束；加`-- --interactive`可停留审查更多/收起/恢复/资源详情。默认导出本目录evidence，`-- --output=/tmp/路径`可改到临时目录。该脚本只用于本次设计审查，不是新游戏runner或独立测试任务；没有工程导入、配置编译、native编译或业务运行。

4.7.2 `--check-only`通过，实际图形进程正常结束；日志只有dummy驱动不支持VSync的环境警告，不据此给性能结论。尚待整体视觉审、原组安全区/最小可读安装说明、用户确认；此前运行接入审批状态保持。
