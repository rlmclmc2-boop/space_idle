# 敌情页实际场景验收

- 基准：`main@c6619009`；Godot 4.7.2，1920×1080，实际 `main.tscn` 和关卡/敌人表。
- 执行：`Godot_v4.7.2-stable_win64_console.exe --path . --script res://docs/tasks/enemy-intel-polish-20261017/capture.gd`。
- `overview.png` / `details.png`：主界面和详情原始截图；同名 JPG 为同尺寸预览，分别 133550 / 152264 字节。
- `alternate-point.png` / `alternate-ship.png` / `stage-2.png`：手动浏览、换舰、换关截图。
- `checks.txt`：脚本断言当前战点跟随、手动浏览不抢选、隐藏态不重建、换关重建，以及无变化时不重建。
- 限制：右侧平级页签的容器在 1440×900 下超出窗口；本次页面在 1920×1080 验收。关卡 1 第 3 战点有不同敌人记录同名同舰图，数据表由数值线程负责。
