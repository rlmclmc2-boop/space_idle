# 八槽模块化舰体原型

仅替换开发场景 `res://dev/toon_ship_test.tscn` 的我方舰渲染。当前只支持既有八槽重型战列舰；未接入正式主场景，不制作其他舰型或无人机。

## 预览与检查

双击 [preview_toon_ship.cmd](../preview_toon_ship.cmd)，或从项目目录运行：

```powershell
& 'C:/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' dev/toon_ship/preview.py --interactive
```

启动器只读复制项目 `.userdata` 中的当前开发存档至 `test/work/toon-ship-*`，再在隔离项目、隔离用户目录中运行。可用 `--snapshot PATH` 指定副本。Godot 不打开原存档，预览禁用保存；装备直接来自副本的真实槽位，不去重、不补装备。直接从编辑器启动本场景没有副本入口，会拒绝用初始护卫舰冒充八槽验收。

窗口为 1335×859，沿用游戏战场布局及顶视正交相机，左侧战场约 391×657。保持原重型舰不透明高度；显示位置按新舰体边界预留原 HUD 间距。C 近看只用于辅助检查，不作为验收。

| 键 | 操作 |
|---|---|
| T / R | Toon / Rim 开关 |
| S | 原型护盾开关 |
| V | 辨识检查 / 现有效果；辨识检查隐藏战斗动态画层、护盾与尾焰，保留舰体和完整 UI |
| B / C / P | 原 2D 舰对比 / 辅助近看 / 暂停 |

只做导入、挂点、转向与实尺寸图形检查：

```powershell
& 'C:/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' dev/toon_ship/preview.py --mode full-loadout --snapshot PATH
```

[full_loadout_check.gd](full_loadout_check.gd) 输出完整窗口、五向姿态、转向/现有效果逐帧 PNG 和 `facts.json`；`acceptance` 是同一检查的兼容入口。诊断转向覆盖侧后方，实战仍使用原有瞄准范围和速度。检查不运行全量测试；暂停姿态阶段核对玩法状态与 RNG 不变。现有效果阶段恢复原游戏处理，所有变化只发生在隔离内存。

## 资产与连接

[build_ship.py](build_ship.py) 用 Blender 生成同一舰体和本次四种必需武器，来源为项目程序化低模几何，无外部贴图。浅色装甲、深色安装区、少量青色发光；优先大块面。重建：

```powershell
& 'I:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python dev/toon_ship/build_ship.py
```

独立源文件在 `source/`，导出舰体为 `player_hull.glb`；`weapons/` 的 `pulse_laser.glb`、`missile.glb`、`cannon.glb`、`long_laser.glb` 分别是单发能量发射器、双舱导弹模块、单管火炮和叉形持续光束模块。按真实槽位重复实例化；旧 `pulse_laser.tscn` 仍包装同名 GLB。

[manifest.json](manifest.json) 是挂点、几何边界和轴向的唯一资产依据。Godot Y-up、前向 -Z；`WeaponMountNN` 对应逻辑槽 NN−1。两列四排由舰艏向后对应槽 6/8、1/7、2/3、4/5，持续光束前置以减少覆盖后排。没有增加逻辑槽位。

舰体无内置武器。`RotationBearing` 固定于安装原点，`TurretPivot` 绕局部 Y 旋转；炮管、根部、炮口结构保留独立网格，`Muzzle` 随炮塔转动。导弹两舱各有出口标记，现有单源效果使用第一舱。所有模块保持单位变换，不靠单独缩放塞入甲板。

[ship_view.gd](ship_view.gd) 负责逐槽装配、材质与相机投影；[toon_ship_test.gd](toon_ship_test.gd) 仅覆盖显示位置、挂点及炮口到原有特效的连接。索敌、CD、伤害、命中、RNG、装备参数与正式存档处理仍使用原脚本。Flexible Toon Shader 延续现有原型设置；没有新增 Shader 插件。

当前尺寸的容量取舍：完整八件可展示，细小炮口内壁及旋转座主要依赖动态轮廓辅助辨认；火焰、充能与弹道经过时会短暂覆盖局部。该原型不是任意装备组合、任意窗口尺寸或实战全角度的通用容量证明；继续扩展前须用目标组合重复实尺寸检查。
