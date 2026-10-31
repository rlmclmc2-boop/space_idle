# 标题条沿内壳切角收边候选（待原审）

源码 `d034de07571fa5866483ab852230143b46baa78c`，基线 `bcad25d0bfc6eb3c603cc53fad1df21f24ac3e53` / 原证据 `3ccb298a77aed8f736a32e1205f7e37d085c1982`。用户退回标题条右端矩形压外框；本轮只修这一处，并给[旧结构高度约束](height-feasibility.md)。后续用户新增“少内容占空间、完整信息拥挤”的核心判断，已补[常用/选择/完整详情的信息组织提案](information-layout-proposal.md)，作为推荐方向；仅评估、未实施。工作台主要布局/高度仍266/288，没有擅自实施压缩。

[异候选双费完整整屏](01-different-double.png)／[原像素工作台](01-different-double-local.png)及[同物单费完整整屏](02-single.png)／[原像素工作台](02-single-local.png)全部实际view_image。正式Godot4.7.2、main.tscn/Session/native固定源码后静态采图exit0，日志 `EQUIPMENT_HEADER_STATIC_COMPLETE`；只浏览真实候选，无购买或新全链/36项复跑。静态fixture延用前版受控availability/Lv19/余额，不当自然开放验证。作者看到右端压外框的矩形角撤除、原壳斜面外露；不代表原Astra/根/用户艺术放行。

根因：原 `EquipmentSurface.profile==header` 绘矩形local `(6,10,764,26)`，标题Panel与_workbench只做矩形裁切；原壳32px上角有斜切轮廓，矩形会穿过其实际内边缘。标题墨迹center18也落得太高。不是机库源图或共享宿主裁切错误。

直接替换原header填充的绘制源为同一底色六边形：local `(32,14)→(744,14)→(764,32)→(764,40)→(12,40)→(12,32)`。沿固定32px角区留出内壳斜面；原唯一ObjectHeader高度36→40，仍同一Panel/同一StyleBox，不新增盖角、遮盖片或另一个标题底层。现有两个Label仅调整光学墨迹位置：主标题左32、墨迹center26，等级间隔12px保持、同center26。只改equipment_panel 11增4删；报价、图标、按钮、台高、船投影及Owner完全不改。[几何与版本](geometry.json)、[源码边界](source-boundaries.json)与原驱动/日志归档。

正常只读fetch `origin design/clear-zone-host` 已取得固定共享控件规范 `c2ede10204784b68ebec8d8d49903e2e9793fbe6`，读取13§2.3“装备／反应炉等模块共享的控件语言”及14的两键关系同步段。本次落实“按真实轮廓与文字安全区、替换旧绘制源、不另叠遮盖框”；继续使用NotoSansSC常规/强调、原同家族模式/主执行键及报价顺序。该提交没有提供另一套已批准模块按钮像素资产；本窄修没有据此改公共样式、宿主或替换反应炉内部控件，不称两页质感/多态全部已统一。规范仅作固定Git只读引用，未另建规范或覆盖13/14。

核23个函数逐字前版，包括两键、费用/钱包身份、精准刷新、批量与独占；比较函数除两个标题位置外逐字一致，构造函数除原header高度外逐字一致；ResourceVisuals及5SVG/原壳/宿主/业务逐字前版。c4资源身份接入继续保留；三资源新资产尚无本轮固定交付，不造第三费用。旧36运行仍仅89ac5d0a，同预算未新测。4.7.2 check-only通过，非raw源码/文档diff-check通过，原Godot check.log尾空行原样保留。

原workspace/分支/cache/未跟踪/import/UID/全部tmp保全，无新workspace/worktree/子代理。本SOL本轮截至归档未实际压缩，无运行任务/权限阻塞。普通推非main，交同一原审；不Library/Space/main写入。
