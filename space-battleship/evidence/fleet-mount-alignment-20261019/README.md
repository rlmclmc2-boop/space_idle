# 五档全部 15 点：底座与安装座复核

首轮炮口自洽检查不足以验收。根因在 `PresentedShipView.apply_direct_fire_alignment`：转向后为保持旧炮口像素位置，平移了整个 `TurretPivot`，旋转炮身因此离开固定的 `RotationBearing` 与静态安装座。修复取消该平移，持续恢复模型导入时的原始轴心，只改变转角。舰体贴图、透明边距、归一化挂点、体量、船中心及碰撞判定均未改动。

## 逐档实际局部渲染

每张图左/中/右依次是静止 0°、转向 −60°并接受开火反馈、转向 +60°并接受开火反馈。每档自己的全部挂点同时出镜。图像直接来自真实 `PresentedShipView` 实例的 Godot framebuffer，没有拼贴或重画。

| 档位 | 挂点数 | 无标记局部对比 | 安装座/底座/轴心标记对比 |
|---|---:|---|---|
| Frigate | 1 | [旋转前后](frigate-rotation.png) | [三个中心](frigate-marked.png) |
| Destroyer | 2 | [旋转前后](destroyer-rotation.png) | [三个中心](destroyer-marked.png) |
| Cruiser | 3 | [旋转前后](cruiser-rotation.png) | [三个中心](cruiser-marked.png) |
| Battleship | 4 | [旋转前后](battleship-rotation.png) | [三个中心](battleship-marked.png) |
| Heavy Battleship | 5 | [旋转前后](heavy_battleship-rotation.png) | [三个中心](heavy_battleship-marked.png) |

标记：绿色圆圈是独立原图安装座中心；青色点是实际固定底座网格的中心；品红叉是实际旋转轴。三个中心重合才通过。

[修复前第 5 档](before/heavy_battleship-marked.png) 保留相同转向与反馈输入下的脱座现象；全五档修复前数据另见 `before-all-seating.json`，并非只检查第五档。

## 独立测量方法与结果

原图全部 15 个安装座的人工核对像素坐标固化在 `test/test_player_mount_seating.gd`。测试不读取生产挂点作为期望值：将原图像素经过裁切起点及 16 像素透明边距换算到 PNG UV，再通过实际 PlaneMesh 的三角形 UV 插值到世界坐标。独立测量导入 `RotationBearing` 网格 AABB 中心和 `TurretPivot` 原点的屏幕投影，与安装座逐一比较，因此可以识别 UV 镜像、透明边距/归一化错误、父变换错误和旋转轴平移。

每点覆盖静止、左转、右转、左转开火校正、右转开火校正、解除校正，共 **15 × 6 = 90** 次。三档图中的导弹正常转向；实际事件不会给导弹附加直接射击校正。

- 修复前：固定底座中心仍贴合，但旋转轴最大偏移 **76.118233 px**；90 次中 36 次失败。
- 修复后：全部 **90 次通过**，安装座/固定底座/旋转轴最大误差 **0.000338801 px**，阈值为 0.05 px。
- 全部 15 点各自、各状态的误差见 [CSV](all-15-seats.csv)、[逐项原始数据](all-seating.json)、[汇总](summary.json)；`after-seating.txt` 保留原日志。
- 原有 `verify_player_hardpoint_geometry.gd` 仍通过五档、两种位置及全部炮口，显示/逻辑几何最大误差 `0.0000682393802 px`，见 `geometry.txt`。该检查与底座贴合检查分别保留，不能互相代替。

本轮明确移除了“把当前炮口平移回旧开火起点”的显示行为；历史弹体的已提交起点不应拖动当前旋转炮身。数值弹体、目标、伤害、原生源码/DLL 均未修改。

## 运行边界与复现

本轮使用现成 Godot 4.6.3、Xorg dummy、Mesa llvmpipe，局部图采用可重复的转向与开火反馈夹具，不冒充新一轮原生整场战斗截图。未重编、加载原生组件；正式 Godot 4.7 整场回归仍是环境验证缺口。首轮的原生战斗图已标为否决，不再作为当前验收依据。

在仓库根目录可用既有隔离执行器运行：

```sh
python test/run.py test_player_mount_seating.gd --headless --godot /usr/local/bin/godot
```

图形运行去掉 `--headless`，并设置 `MOUNT_SEATING_ONLY=Frigate`（其他四档同名）与 `MOUNT_SEATING_DIR=<隔离输出目录>`。同一回归会输出该档两张实际对比图与全部点的误差。所有本轮隔离工程和用户数据均位于自己的 `test/work/player-hull-alignment-20261019/`，未读写玩家存档。
