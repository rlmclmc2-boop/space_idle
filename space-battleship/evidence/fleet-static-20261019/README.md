# 五档静态舰体接入证据

基准 main：`8ff9a7bd`。父线程资产：`abdd8d1d21847e99ce876acaa7426e8275de9994`。

| 档位 | 满武器全屏实际战斗 | 满武器近图 | 实际显示宽×高（战场内部像素） |
|---|---|---|---|
| 1 | [Frigate](battle-frigate-full.png) | [近图](frigate-full.png) | 98.124 × 133.042 |
| 2 | [Destroyer](battle-destroyer-full.png) | [近图](destroyer-full.png) | 107.338 × 151.470 |
| 3 | [Cruiser](battle-cruiser-full.png) | [近图](cruiser-full.png) | 162.792 × 213.792 |
| 4 | [Battleship](battle-battleship-full.png) | [近图](battleship-full.png) | 212.602 × 242.216 |
| 5 | [Heavy Battleship](battle-heavy_battleship-full.png) | [近图](heavy_battleship-full.png) | 247.996 × 291.788 |

全屏图来自实际主场景 framebuffer，五舰同一窗口尺寸；近图使用原有 `test/capture_player_hardpoints.gd`，统一 550 高，仅用于安装座/武器细节，不用来比较大小。

验证：

- 原图五个主体分离，3/4 边缘按最近主体分配；清理孤立低透明杂点。五张运行贴图透明边距均为 16 像素，挂点均位于不透明主体。
- `test/capture_player_hardpoints.gd`：1/2/3/4/5 个独立武器全部呈现，挂点与真炮口检查通过；第 5 档低锚点仍完整可见。
- `test/verify_player_hardpoint_geometry.gd`：五舰、两种位置、全部槽位与双炮口，最大显示/逻辑误差 `0.0000682393802` 像素，详见 `geometry.log`。
- `test/capture_battle_hardpoints.gd`：每舰 180 帧，五档均有 native 开火和实际命中；全部 15 槽都已开火，炮台均转向；真炮口/弹体起点误差最大 `0.097735` 像素，小于现有 `0.1` 断言；逻辑炮口误差最大 `0.0001221`。每舰 `battle-*-result.json` 及 `*-battle.log` 保留原始结果。
- UI 当前/候选、锁定、图片来源、1–5 槽映射与按钮位置：原 `test_ship_preview.gd` 在旧八槽段之前的受影响检查共 153 项，0 失败，见 `verify_static_hull_ui.gd`、`static-ui.log`。完整旧脚本在 `weapons_7` 硬编码处报错，原日志 `ship-preview.log` 留存；未改动该旧夹具或槽位玩法。
- 显示宽高均严格递增；`geometry_texture`、原显示尺度配置及船中心判定来源不变。源图/拆图报告见 `art_sources/fleet-20261019/`。

环境与复现：本机只有 Godot `4.6.3.stable.official.7d41c59c4`，图形为 Xorg dummy + Mesa llvmpipe OpenGL Compatibility。测试项目与用户目录均隔离在 `test/work/player-hull-static-20261019/`。原生组件采用仓库同一源码、固定 godot-cpp `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`，仅在临时构建目录用本机导出的 API 编译 Linux `.so`；兼容版本/加载路径仅写入隔离项目，不进入交付。官方 Windows/Godot 4.7 包未执行，仍需父线程在正式运行环境复核。

原有脚本执行方式：设 `HARDPOINT_CAPTURE_DIR` 为证据目录，`HARDPOINT_ONLY` 为对应舰名，再运行 `godot --path <隔离工程> --rendering-method gl_compatibility --script res://test/capture_player_hardpoints.gd`（隔离复制时按脚本实际位置调整）。几何检查用 `--headless --script res://test/verify_player_hardpoint_geometry.gd`。此目录保留战斗捕获脚本副本，仅增加输出舰体尺寸/单独透明层，不更改原断言。
