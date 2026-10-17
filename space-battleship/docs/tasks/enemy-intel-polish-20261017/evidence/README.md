# 敌情页实际场景验收

- 基准：`main@c6619009`；Godot 4.7.2，实际 `main.tscn` 和关卡/敌人表。
- 执行：`Godot_v4.7.2-stable_win64_console.exe --path . --script res://docs/tasks/enemy-intel-polish-20261017/capture.gd`；加 `-- small` 验证 1440×900。
- 根目录为 1920×1080；`1440x900/` 为窄窗口。两组 `overview.png` / `details.png` 是主界面和详情原始截图；同名 JPG 是同尺寸预览，各小于 500KB。
- `alternate-point.png` / `alternate-ship.png` / `stage-2.png`：手动浏览、换舰、换关截图。
- 两组 `checks.txt`：脚本断言当前战点跟随、手动浏览不抢选、详情开合、隐藏态不重建、换关重建、无变化时不重建、页签与详情区位于视口内，及离开敌情页后其他页尺寸恢复。
- 数据待数值方确认：第 1 关第 3 战点 `mon 271006`、`271007` 均为“能量拦截艇”，`intelVisualRef` 均为 `interceptor`；保留两个独立表项。
