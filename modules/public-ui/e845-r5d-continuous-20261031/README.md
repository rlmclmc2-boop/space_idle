# 最终装备 ↔ R5d 真正连续取帧（2026-10-31）

源 `design/clear-zone-host@7bdf00627cc895636e37ab71802711e7e68ed408`；最终装备为已合 `main@e845ca58afd39184c3d4c5743021480e393adf74`，反应堆为 R5d `0c2abe55b8084ee0d73a229b615300ba64c7b19e`。Godot 4.7.2，原生主入口，1440×900，gl_compatibility。

`frames/frame-000.png` 至 `frame-035.png` 是同一 SceneTree 依次在每次 `RenderingServer.frame_post_draw` 保存的原图，Engine 已绘制帧编号从 69 至 104，逐帧 +1、无缺口。`timeline.json` 给每帧单调 `ticks_us`、事件点、路由、显隐、焦点和资源文字：样本 6 按下反应堆、8 释放并切入；样本 21 按下装备、23 释放并返回。全部 36 帧中两模块显隐互斥、公共资源文字固定，作者看了事件前后原图，当前受控路径未见闪白或双模块同显。

`route-sequence-preview.mp4` 只是把这些原帧按任意 8fps 编码供观看，**播放时长不是运行时长或性能数据**。原始 `ticks_us` 跨约 28.7 秒，保存每张 PNG 会延长帧间墙钟时间；当前证据仅确认这次采集中的逐已绘制帧连续性和受控原生点击路由，不能证明无采屏时的目标环境时序、所有输入组合、模块业务全链、自然解锁或用户验收。此为作者受影响观察，尚未交独立整体审核者看本序列。先前拼接后状态短片的纠正仍独立保留于 `e845-r5d-transition-20261031/CORRECTION.md`。
