# 新静态炮台与脉冲光弹：供用户看实际效果

基准 `0bda17f2`；透明源图来自 `c59db3758a26723faca4c62c1937c85fed415ae7`。仅改视觉，不合 main。

先看 [四武器：静止 / 转向 / 开火](four-weapons-rest-turn-fire.png)。新舰体四角依次为磁轨、导弹、脉冲、持续光束；第三栏调用现有开火/飞行/光束 VFX。下方光弹为未经放大的实屏尺寸。此图直接来自 Godot framebuffer，使用真实舰体、炮台和 VFX 实例的可重复预览夹具，并非本轮原生整场战斗实拍。

## 五档新炮台局部旋转效果

每张左/中/右为 0°、−60°与+60°，沿用上一轮已修正的旋转轴及开火反馈检查。

| 舰体 | 无标记实际图 | 安装座/底座/旋转轴标记 |
|---|---|---|
| Frigate（1） | [查看](frigate-rotation.png) | [查看](frigate-marked.png) |
| Destroyer（2） | [查看](destroyer-rotation.png) | [查看](destroyer-marked.png) |
| Cruiser（3） | [查看](cruiser-rotation.png) | [查看](cruiser-marked.png) |
| Battleship（4） | [查看](battleship-rotation.png) | [查看](battleship-marked.png) |
| Heavy Battleship（5） | [查看](heavy_battleship-rotation.png) | [查看](heavy_battleship-marked.png) |

## 接入与必要验证

- 四个炮台贴图仅替代可见网格，挂到既有 `TurretPivot`；固定底座、炮口节点及其变换不改。拆图透明边距16像素，基座中心与炮口像素显式记于 `assets/weapons/fleet_20261019/manifest.json`。导弹双发射口使用X/Z显示适配；不改其数值发射位置。
- 新贴图锚点与旋转轴最大误差 **0.000015259 px**；贴图发射口与原炮口节点最大误差 **0.032166 px**。
- 五档全部15点×6状态共 **90次底座/轴心检查通过**，最大误差 **0.000338801 px**，原始结果 `all-seating.json` / `seating.txt`。
- 原显示/逻辑几何检查仍通过，最大误差 **0.000068240 px**，见 `geometry.txt`。
- 光弹普通路径由 `pulse_vfx.gd::flight` 采样新PNG；保留GPU路径由 `retained_flights.gdshader` 复用原脉冲首6顶点的quad，折叠原脉冲装饰几何。两条路径均按 **14×34** 内部像素取样同一张PNG，避免长尾变成光束。
- [CPU光弹](pulse-cpu.png) 与 [GPU光弹](pulse-gpu.png) 实渲染逐像素RGBA误差 **0**。GPU沿用原生实例的方向、出生时刻和速度：0.2秒×40单位/秒得到8像素位移，与CPU预期位置的图像透明轮廓误差 **0**，见 `pulse-gpu-clock-step.png`。
- 具体数值见 `visual-validation.json`；图形检查入口 `test/test_static_weapon_preview.gd`，15点检查入口仍是 `test/test_player_mount_seating.gd`。

射速、弹速、伤害、命中、目标、船中心、配置表、逻辑几何、原生C++/DLL均未改动或重编。原生GPU使用相同shader与拓扑协议，但本轮未加载正式原生扩展，GPU实渲染通过独立MultiMesh夹具验证；正式Godot 4.7整场验证仍未执行。当前交付用于先看视觉效果。

图形检查使用 Godot 4.6.3、Mesa llvmpipe、Xorg dummy。设 `STATIC_WEAPON_EVIDENCE` 为本次隔离输出目录，再以现有 `test/run.py test_static_weapon_preview.gd --godot /usr/local/bin/godot` 图形运行。玩家存档未读取或写入。
