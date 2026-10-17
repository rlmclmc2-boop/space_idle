# AI 科技工厂页面验收证据

Godot 4.7.2 GUI 用 `capture.gd` 生成第二版静态资产页面的原始 PNG。快照为页面契约测试数据，不代表玩家存档或实际研发数值。

- `device-*.png`：八项科技的首代设备；`condenser.png`：凝聚装置及内部晶体。
- `main-idle.png`、`main-active.png`：无研究及研究中状态；只有快照提供的一条进度。
- `drawer.png`：鼠标输入打开覆盖抽屉；脚本再点击收起并断言状态。
- `motion-00.png` 至 `motion-11.png`：连续原始帧；`motion.png`：由这些帧封装的 1.2 秒 APNG。
- `events.txt`：选择研究和投入信号的记录。
- `main-active-preview.jpg`、`drawer-preview.jpg`：原始 PNG 的 1344×1160 JPG 审阅副本，分别 201 KB、146 KB；未替换原件。

脚本还断言美术开关关闭、页面隐藏、抽屉覆盖时动画停止；恢复时设备节点不重建；抽屉首次打开前不创建八个图标。这是页面行为验证，不是高负载性能结论。高负载增量由集成线程实测。

运行：`Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://docs/tasks/ai-tech-art-20261017/capture.gd`。运行目录为 `space-battleship`；`python docs/tasks/ai-tech-art-20261017/make_motion_apng.py` 生成短动画；`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://docs/tasks/ai-tech-art-20261017/make_previews.gd` 生成 JPG 副本。素材由内置 `image_gen` 生成，提示词及消费尺寸见 `assets/ai_tech_factory/README.md`。
