# R5f 当前共享组合：正常 1× 工作态全屏录制（2026-10-31）

固定运行源码 `design/clear-zone-host@3504a52de1ba4dfce5101bc1932820db0e71bc3a`；反应堆 R5f `c0add846f2db273d0418d04077739de23093b981`、装备最终 main `e845ca58afd39184c3d4c5743021480e393adf74`、公共导航按住修正 `0049ed4c`。Godot 4.7.2 当前原生主入口，Xorg `:99` 上 1440×900 游戏窗口直接用 FFmpeg x11grab 录全屏，非原组旧宿主视频或研究合成画面。

`r5f-shared-live.mp4` 为 1440×900、12fps、120 编码帧、10.000 秒视频；实际 FFmpeg 抓取进程墙钟约 10.358 秒。Godot 同次运行 `Engine.time_scale=1.0`，清除主入口默认的 `user` 暂停后 `running=true`、无 pause reasons；观察窗口内 Godot 墙钟约 13.025 秒、游戏时间前进约 13.05 秒、引擎绘制帧数增加 168。视频完整呈现上部设备工作光、下台、公共资源/导航、右战场及模块边界。`frame-at-2s.png`、`frame-at-8s.png` 是该视频实际帧的完整尺寸参考。

该次为受控开放反应堆/凝结相关入口，结束时 core=1.0，weapons/defence/smelting/condensation 各 0.25；不是自然解锁证明。未注入预算或改游戏时钟，运行中预算随游戏自然变化。没有采购、全路由鼠标链或目标硬件性能测试。12Hz 抓屏并非逐 Godot 绘制帧保存；FFmpeg 未给出可靠的丢采计数，不能宣称零漏帧或将编码时长当每帧实际时间。抓屏与编码会扰动运行，不据此宣称 FPS/帧耗时通过。作者查看两张全屏参考帧，尚待既有整体审核者看完整当前动态；原组 R5f 的 250 帧上部审与本组合动态证据各自独立。

`runtime.json`、`capture-wall.json`、`ready.json`、驱动、runner、FFmpeg/Godot 日志、窗口信息及 manifest 保留实际来源与可核值。首次尝试因主入口默认 `user` 暂停而没有游戏时间前进，已废弃且未纳入本包；本包只保存解除暂停后的有效录制。
