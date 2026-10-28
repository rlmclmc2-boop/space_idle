# 反应炉设备厚体承载候选 R4

针对 R3 四壳仍像平面描线叠片的问题，先制作左上武器局部厚体并在真实整屏查看[单件代表](representative-weapons.png)，再依原右上盾甲蜂窝、左下铁产出竖栅、右下凝聚晶舱结构分别制作同类资产。四件透明静态图见 `assets/ui/reactor/ship-hub-r4/*-control-3d.png`，原高分辨率 ImageGen 输出存于 `art_sources/reactor-control-r4/`。四件在 Godot 为 216×140，壳体有暖象牙受光、深青侧壁/凹入读面和局部接触阴影；已去掉生成草稿里重复的整台盾甲/晶簇，仅以侧边纹理区别。它们只替读控承载，不改舱室/核心图、下两光路、业务或 `main.gd`。

[四设备真实运行](reactor-mount-r4-active.png)中原识别窗与核心留存；四滑杆各154×32在上沿深槽，增益18px、手动/有效16px分行。铁产出短效果末尾距右边框仍有间隔；等级从左上斜甲边移入中央深读面。中央主购级保持151×44，“供能已更新”位于台面底行。[四路鼠标草稿](reactor-mount-r4-four-mouse-preview.png) → [整组确认后](reactor-mount-r4-four-mouse-applied.png)显示四路25→1/0/1/0完整短值、预览与确认回执成功；草稿时核心仍显示确认前真实负载。购级[禁用](reactor-mount-r4-disabled.png)、[焦点](reactor-mount-r4-focus.png)、[悬停](reactor-mount-r4-hover.png)、[按下](reactor-mount-r4-pressed.png)、[购级后](reactor-mount-r4-purchased.png)及[状态日志](states.log.txt)供核。截图前通过公开 Session `dismiss_guidance` 与宿主 `_sync_guidance` 结束“反应炉已解锁”等提示。

[四路鼠标驱动](four-mouse-driver.gd.txt)/[日志](four-mouse.log.txt)、[购级状态驱动](states-driver.gd.txt)可复核。开放条件与购级预算由验证驱动经公开 Campaign/Economy API 临时给予，不代表自然进度；运行在 Godot 4.7.2、真实 native Session、1440×900 Xorg:99/llvmpipe。这里只回归受资产/位置影响的读控和鼠标；不重跑先前业务长流程，也不声称硬件性能通过。宿主顶部0..65共享导航仍归整体组。
