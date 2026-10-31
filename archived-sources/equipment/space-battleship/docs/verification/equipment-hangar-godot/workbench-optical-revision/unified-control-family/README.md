# 装备控件同族语言候选（原整体品质未过，待整体审）

用户退回e52/671整页：“每个控件的确都有质感了，但是分成好几套，没有统一标准”。本轮源码 `9625564c164406fdfb73801d5180e23f47a3cf73`，基线 `671215bb5f90a0a5c9c05445394572f46adb89fe`，原唯一SOL/工作区继续；没有把禁用窄修完成当原整体任务收尾。

当前[正常整屏](01-normal.png)／[局部](01-normal-local.png)、[异候选整屏](02-comparison.png)／[局部](02-comparison-local.png)、[资源不足整屏](03-disabled.png)／[局部](03-disabled-local.png)、[Batch整屏](04-batch.png)／[局部](04-batch-local.png)全部实际view_image。另看[主动作焦点](focus-primary-local.png)、[候选焦点](focus-candidate-local.png)、[弱操作焦点](focus-quiet-local.png)。4整屏1440×900、7局部均从原根viewport真实区域截取，不缩放拼贴。作者只确认这些是实际当前实现，**不自判整页统一或整体品质通过**。

## 原来为什么分套，本次实际替换

原台壳是磨损切角装甲；仪表与候选是软圆角亮玻璃；金/蓝键又有单独金属多描边切角；侧槽是平填半透明圆角；候选焦点是底线而其他键是圆角外框；Batch标题24px与工作台18px、弱关闭独立字色又强化差异。单独精致并不等于同页同族。

遵循已读固定c2ede10204784b68ebec8d8d49903e2e9793fbe6的13§2.3共用控件语言，本次替换原绘制源，不另造规范：

| 当前实现角色 | 共用处 | 合理差异 |
|---|---|---|
| 仪表/候选承托/主次键/侧槽/定位标签/标题 | 同一公共漆面纹理、同一EquipmentSurface绘制类、5px切角、单1px边、同上亮下暗/薄接触承托 | 主执行暖色，次操作蓝灰，事实面象牙冷色；不是所有控件同色 |
| 选中/焦点 | 同一切角可见轮廓；焦点统一8ab9b2，候选不再另用底线 | 选中用青色面，不冒充已安装或购买提交 |
| 禁用 | 同一冷暗面、低强调边、ccd6d0不透明字 | 保留清楚动作名，不像暖金可执行主键；Native disabled仍由原Owner事实决定 |
| 弱操作 | 同一材质/轮廓/焦点源 | 平时不画实面以保持弱层级；hover/focus用同一语言，不再独立皮肤 |
| 字阶 | NotoSansSC常规/强调；动作16强调、主要容器标题18强调、对象名称强调 | 保留27主值/17费用强调、12–15标签事实层级；Batch标题24→18，侧槽名称改强调字重，其他原尺寸保留 |

外层台壳仍是原唯一设备壳，不把每个控件都套32px装甲框；内部轻5px切角承接其轮廓语法。标题沿原切角裁切、台壳九切片及船主体/位置不改。页面上公共宿主“舰桥面板”、右战场等公共控件按边界未抢改；组合全屏跨模块一致性仍由整体组协调，不能据本页宣称公共壳已统一。

## 材料、状态和清理

不生成新资产。第一轮仅取原壳漫反射面显得偏平，原tmp预览保留；最终只从现有control-materials.png的navy键内漆面 `(120,800,1200,130)` 取一个298×64公共面材，排除原金属框；保其受光/磨痕，初始化用亮度中和成公共底材，再按角色着色。不是玻璃、金、蓝三份独立框皮。正常同源低幅受光、1–2px接触承托，禁用取消亮肩；没有新Panel/盖片/厚斜框，也不是仅给旧六套皮肤换相同颜色。

原PolishedGlass、四份独立面缓存、额外disabled纹理、多描边键的九切片控制皮、圆角平填侧槽/焦点、候选单独焦点底线、已无消费者的PopupMenu样式和_style帮助函数均撤。图片原文件与原生成prompt/来源继续保历史及本次内面来源，不覆盖旧资产字节。只有index/candidate保2个真实选择变体，其他控件只建1组状态；每个按钮的focus StyleBox在选择变体间复用，仍初始化缓存，无全局刷新。

[同版原生记录](visual-family-records.json)显示主/次/候选/侧槽/Batch/弱操作六角色实际同face texture，焦点都由Native Control确认，禁用仍Native Button.disabled=true、Owner返回InsufficientResources，完整1600铁/10简并报价与原因保留。记录里font_size是BaseButton文本设置；候选/侧槽实际名称仍是其原13/14px子Label，此次统一强调字重而非擅称所有名称16px。原5资源实体图继续icon_modulate保原色，不将资源身份染成控件色。

## 版本边界

源只改equipment_panel，未新建公共样式文件、宿主框架或规范。[source-boundaries.json](source-boundaries.json)核27个逻辑/几何函数逐字e52/671；构造只换原侧槽背景，Batch只改标题字级，侧槽刷新只在创建名称Label时设强调字重；Owner/报价/两键/精准刷新/独占生命周期/结构266/288/舰船绘制几何不改。12项main/Session/Owner/Economy/CampaignView/project/机库/原壳/资源helper与两资源图集/既有材质源字节不变。

Godot4.7.2 check-only通过，同版main.tscn/Session/native必要视觉过程exit0，`EQUIPMENT_UNIFIED_CONTROL_FAMILY_VISUAL_COMPLETE`。受控Lv19/availability/钱包只用于取图，没有购买或新36/交易全链/独立矩阵；当前没有重跑点击禁用/冷却计时或全舰/极端MAX，旧相关证据保持原版本含义，不冒称本版新测。非raw源码/文档diff-check通过，原check.log尾空行保留。

原整体任务继续未闭合，这是一页同族候选而非完成宣告，交原Astra/根看整页。布局重排/按需详情/压缩提案继续仅历史存档。原workspace/分支/cache/未跟踪/tmp/生成源全部保全，本SOL至本自然项归档未实际上下文压缩，无运行任务或阻塞；只普通推非main，不Library/Space/新任务/子代理/工作区。
