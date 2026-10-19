# Reactive三块装甲辨识版本

基准3b853209。sentry保留，reactive通过imagegen重做为三块大装甲围绕小核心、细支撑和清晰开放缝隙、短平头。配色继续为白灰装甲/暗红骨架/橙亮部。原图及完整提示在art_sources/enemy-fleet-20261019/reactive-three-plates*，没有用Godot或程序几何重画舰体。

- `reactive-compare.png`：实际主场景同一行的sentry与reactive，两者同一1×1框并以0°姿态比较，原始1372×883默认窗口PNG。
- `ordinary-eight.png`：同一8舰单格预览替换reactive后的实际场景，保留舰名、格线和血盾。
- `before-eight.png`：直接保存自基准3b853209的原8舰截图，供对照。

显示框仍114.4×133.333逻辑，舰体fit上限90.4×79.333；没有为外圈缩船、改尺寸参数或改生产外圈。两舰比较高度79.210/79.333逻辑（相差0.123），因新三叶轮廓比例不同，reactive等比宽度86.809，sentry90.4；未使用横向拉伸。默认窗口二者高度约56实际像素。透明缝隙来自imagegen源图，导入仅做alpha清理、等比缩放和居中。

331项实际主场景检查零失败；透明/比例/组件与原几何来源检查通过。sentry及其余6舰逐字节未变，全部生产scripts/data/config_excel/addons不变，geometry_texture和中心/防御数值保持原样。外圈的去留没有在此版本决定，编队重设计仍暂停。战场PNG均为原始窗口输出，没有裁切缩放或拼贴；QA先实际交火，再暂停并清理瞬时弹道/浮字用于尺寸观察。本地Godot4.6.3 Linux/GDS路径。

复现：运行prepare_assets.py生成runtime；隔离项目导入后，test/test_enemy_grid_layout.gd使用GRID_CASE=reactive-compare或ordinary-eight，GRID_OUTPUT指定目录，图形模式和隔离XDG。
