# AI 科技工厂页面验收证据

Godot 4.7.2 GUI 用 `capture.gd` 生成原始 PNG。快照为页面契约测试数据，不代表玩家存档或实际研发数值。

- `device-*.png`：八项科技的首代设备；`condenser.png`：凝聚装置及内部晶体。
- `main-idle.png`、`main-active.png`：无研究及研究中状态；只有快照提供的一条进度。
- `drawer.png`：鼠标输入打开覆盖抽屉；脚本再点击收起并断言状态。
- `motion-00.png` 至 `motion-11.png`：连续原始帧；`motion.png`：由这些帧封装的 1.2 秒 APNG。
- `events.txt`：选择研究和投入信号的记录。

运行：`Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://docs/tasks/ai-tech-art-20261017/capture.gd`。运行目录为 `space-battleship`；`python docs/tasks/ai-tech-art-20261017/make_motion_apng.py` 生成短动画。
