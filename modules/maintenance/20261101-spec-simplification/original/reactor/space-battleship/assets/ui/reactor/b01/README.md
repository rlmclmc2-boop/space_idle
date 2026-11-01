# B01 当前运行资产

唯一状态及视觉完成标准见 [B01 当前重做入口](../../../../docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md)。本目录仅保留当前运行闭包和可重复生成它的本地脚本；旧 R5 资产已固定在独立 Git 归档分支，不作为本轮源稿。

源画布为 1187×1326，运行舞台为 808×835。`reactor_ports.json` 是四设备入口、核心出口、三次贝塞尔管路控制点、端面半径/深度、设备/工作层裁图和管段图层裁图的唯一坐标源。`generate_reactor_devices.py` 在 Blender 中逐设备创建机械本体和内置可见接口，按照合同记录端口投影；`assemble_reactor_devices.py` 对齐该投影至合同中心并输出 `r6-*.png` 与 `r6-*-work.png`。`generate_modular_pipes.py` 使用同一端点与轴线生成管壳，`assemble_reactor_pipes.py` 按合同矩形裁图并断言渲染端实际可见。中间全画布图只生成在 `/tmp/reactor-r6-build`（可用 `REACTOR_BUILD_DIR` 覆盖），不放入制作树。

从 `space-battleship` 根目录执行：

```bash
blender -b -t 2 --python assets/ui/reactor/b01/generate_reactor_devices.py
python3 assets/ui/reactor/b01/assemble_reactor_devices.py
blender -b -t 2 --python assets/ui/reactor/b01/generate_modular_pipes.py
python3 assets/ui/reactor/b01/assemble_reactor_pipes.py
```

`reactor_stage.gd` 按合同放置设备及管段，静态舱室、玻璃核心、控制台、固定夹具仍是当前运行材质；核心和四设备的真实工作光由独立 shader 及工作层在 Owner 正载时驱动。控件文字、按钮、滑条及实际数字仍由 `reactor_scene.gd` 原生绘制。当前资产和脚本仍须以实机整屏、连续动态和端口细节判断，不凭接口数据自动认定视觉完成。
