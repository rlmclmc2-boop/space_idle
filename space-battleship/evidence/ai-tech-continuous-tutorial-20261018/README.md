# AI 连续研发与开场暂停候选证据

- 基准：`main@51a7e1b9bc5784927e7d5b232a112194d990a41c`。
- 独立分支：`feat/ai-tech-continuous-tutorial-20261018`。
- Godot：`D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64.exe`（GUI）及同目录 `_console.exe`（headless）。
- 全程使用独立 `APPDATA`/`LOCALAPPDATA`；这些目录含测试存档与缓存，不入库。

## 受影响验证

| 原始日志 | 结果 |
| --- | --- |
| [test_ai_tech_tree.log](test_ai_tech_tree.log) | 科技树 49/49。 |
| [test_continuous_badge.log](test_continuous_badge.log) | 同一科技连续完成两级、资源按秒扣减、未读位与读取后的清除。 |
| [test_ai_tech_continuous_ui.log](test_ai_tech_continuous_ui.log) | 真实主场景：同一科技前两级各完成后工厂红点可见；每次进入工厂清除；留在工厂期间第三级完成不留未读。 |
| [test_intro_pause.log](test_intro_pause.log) | 真实主场景新档：未确认保持 4 秒，战点、距离、掉落不推进；确认后航行。 |
| [test_ai_tech_tutorial.log](test_ai_tech_tutorial.log) | UI 文案契约与科技页提示 6/6。 |

## 正常 GUI 新档

实际 Windows 窗口逐秒截图保存为 `gui-new-save/frames/frame-000000.jpg` 至 `frame-000252.jpg`，共 253 张，顺序完整；[SHA-256 清单](gui-new-save/frames.sha256)。使用的只读[截帧脚本](gui-new-save/capture_script.gd)每秒从真实窗口视口保存 JPEG。没有在确认前发送任何游戏输入。

| 帧 | 可见状态 |
| --- | --- |
| [000019](gui-new-save/frames/frame-000019.jpg)、[000081](gui-new-save/frames/frame-000081.jpg)、[000142](gui-new-save/frames/frame-000142.jpg)、[000166](gui-new-save/frames/frame-000166.jpg)、[000191](gui-new-save/frames/frame-000191.jpg) | 教程待确认；第 1 关 0/5，显示“已暂停”，资源 0/0、生命 1K/1K。超过旧复现的第 146 秒仍不推进。 |
| [点击记录](gui-new-save/input.log)及[000193](gui-new-save/frames/frame-000193.jpg) | 在 `000191` 后向“查看装备”按钮发送一次普通点击；随后显示“航行中”。 |
| [000222](gui-new-save/frames/frame-000222.jpg) | 第 1 关 4/5 战斗中、出现掉落与资源增长。 |

截图为真实 GUI 过程原帧；第 193 帧后的战斗只是确认解锁后正常启动，不构成进一步试玩或评分。
