# AI 连续研发与开场暂停候选证据

最终候选把开场说明改为 `intro → equip → defence → upgrade → progress` 五页；前四次“下一步”后仍暂停，最后点击“完成指引”才启动。首版只暂停第一页的取证保留在下方，**不是最终行为**。

- 基准：`main@51a7e1b9bc5784927e7d5b232a112194d990a41c`。
- 独立分支：`feat/ai-tech-continuous-tutorial-20261018`。
- Godot：`D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64.exe`（GUI）及同目录 `_console.exe`（headless）。
- 全程使用独立 `APPDATA`/`LOCALAPPDATA`；这些目录含测试存档与缓存，不入库。

## 受影响验证

| 原始日志 | 结果 |
| --- | --- |
| [test_ai_tech_tree.log](test_ai_tech_tree.log) | 科技树 49/49。 |
| [test_continuous_badge.log](test_continuous_badge.log) | 同一科技连续完成两级、资源按秒扣减、未读位与读取后的清除。 |
| [test_ai_tech_continuous_ui_v4.log](test_ai_tech_continuous_ui_v4.log) | **Headless 主场景脚本测试**：同一科技前两级各完成后工厂红点可见；每次进入工厂清除；留在工厂期间第三级完成不留未读。此项不是普通 GUI 连续研发证据。 |
| [test_intro_pause_v5.log](test_intro_pause_v5.log) | Headless 主场景新档：五页开场逐次确认，开场“暂时收起”不能绕过；前四次战点、距离、掉落不推进；最后一次后航行。 |
| [test_ai_tech_tutorial.log](test_ai_tech_tutorial.log) | UI 文案契约与科技页提示 6/6。 |
| [ui_catalog_v4.log](ui_catalog_v4.log) | 最终文案表 2387 行有效。 |

## 最终五页正常 GUI 新档

新档 `gui-new-save-v3/frames/frame-000000.jpg` 至 `frame-000359.jpg` 共 360 张[连续原帧及 SHA-256 清单](gui-new-save-v3/frames.sha256)。[逐次实际点击记录](gui-new-save-v3/input.log)：[000191](gui-new-save-v3/frames/frame-000191.jpg) 第一页仍暂停，后续 [000193](gui-new-save-v3/frames/frame-000193.jpg)、[000218](gui-new-save-v3/frames/frame-000218.jpg)、[000243](gui-new-save-v3/frames/frame-000243.jpg)、[000269](gui-new-save-v3/frames/frame-000269.jpg) 四页均为第 1 关 0/5、资源 0/0、已暂停；[000301](gui-new-save-v3/frames/frame-000301.jpg) 末页仍暂停；最后确认后 [000303](gui-new-save-v3/frames/frame-000303.jpg) 航行，[000335](gui-new-save-v3/frames/frame-000335.jpg) 进入 4/5 战斗并有掉落。

随后只修正末页把“正在”改为确认后时态。最终文案短 GUI 原帧 `gui-opening-copy-v4/frames/frame-000000.jpg` 至 `frame-000173.jpg` 共 174 张，[SHA-256 清单](gui-opening-copy-v4/frames.sha256)与[点击记录](gui-opening-copy-v4/input.log)俱在。[000107](gui-opening-copy-v4/frames/frame-000107.jpg) 显示“完成指引后战舰会自动交战”，仍暂停 0/5；[000146](gui-opening-copy-v4/frames/frame-000146.jpg) 仍暂停；确认后 [000148](gui-opening-copy-v4/frames/frame-000148.jpg) 开始航行。

两次 GUI 均使用的只读[截帧脚本](gui-new-save/capture_script.gd)每秒从真实窗口视口保存 JPEG；所有游戏点击均为可见窗口上的普通鼠标消息。没有在各自最后确认前购买、升级或取得资源。存档与 Godot 缓存只保留在隔离目录，不入库。

## 首版第一页暂停证据（已由五页候选替代）

实际 Windows 窗口逐秒截图保存为 `gui-new-save/frames/frame-000000.jpg` 至 `frame-000252.jpg`，共 253 张，顺序完整；[SHA-256 清单](gui-new-save/frames.sha256)。使用的只读[截帧脚本](gui-new-save/capture_script.gd)每秒从真实窗口视口保存 JPEG。没有在确认前发送任何游戏输入。

| 帧 | 可见状态 |
| --- | --- |
| [000019](gui-new-save/frames/frame-000019.jpg)、[000081](gui-new-save/frames/frame-000081.jpg)、[000142](gui-new-save/frames/frame-000142.jpg)、[000166](gui-new-save/frames/frame-000166.jpg)、[000191](gui-new-save/frames/frame-000191.jpg) | 教程待确认；第 1 关 0/5，显示“已暂停”，资源 0/0、生命 1K/1K。超过旧复现的第 146 秒仍不推进。 |
| [点击记录](gui-new-save/input.log)及[000193](gui-new-save/frames/frame-000193.jpg) | 在 `000191` 后向“查看装备”按钮发送一次普通点击；随后显示“航行中”。 |
| [000222](gui-new-save/frames/frame-000222.jpg) | 第 1 关 4/5 战斗中、出现掉落与资源增长。 |

截图为真实 GUI 过程原帧；第 193 帧后的战斗只是确认解锁后正常启动，不构成进一步试玩或评分。

## Passive tutorial cue correction (2026-10-18)

The earlier GUI frame 000148 predates this correction and shows the repeated waiting cue. After the fifth opening confirmation, passive waiting/travel states now leave the guide hidden. A future affordable slot upgrade remains actionable, and Help can reopen the waiting explanation without recording a purchase. The real-main-scene headless assertion is [test_intro_passive_v6.log](test_intro_passive_v6.log), exit 0. No new GUI playback was made for this correction; visual acceptance is pending the parent's serial GUI window.
