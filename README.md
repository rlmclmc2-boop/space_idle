# 站／炉下腹承力舱：同版局部证据

源码 `feat/planet-single-side-ui@0cbc1a4a52a4000866fdf65739effa6fc9260c50`，Godot 4.7.2，2048×768。四张 `planet-station-armor-{1..4}.png` 分别是累计 built 的站、站＋炉、再加工坊、完整态，固定相位 0；两张 `planet-station-side25-{1,4}.png` 是受影响的 25° 站单建和完整态。`stage14.gd`、`stage23.gd`、`side25.gd` 是对应脚本，日志同名前缀 `.log`。

`frames/planet-bays-local-{000..024}.png` 为完整态模拟相位 0–6.0 秒，每帧调用 `advance(0.25, false)`，脚本和日志为 `motion.gd`、`motion.log`。`motion.mp4` 由原图以 4 fps 编码，共 25 帧，播放时长 6.25 秒。此取样不是墙钟自然运行或自然建设进度。

所有原图已逐张以 2048×768 查看。四阶段归属与球后遮挡保持正确；局部连续区间内连接和遮挡无明显跳变。新舱格、受力端盖与较浅的下腹钢壳在两节点侧面可辨，但默认角度的站体深灰开口仍大，四节点材质与细节密度尚未达到整体一致。这里只是制作候选，不是完整相位、整圈或整体审查通过。文件哈希见 `SHA256SUMS`。
