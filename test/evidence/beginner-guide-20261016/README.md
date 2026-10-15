# 开局指引短验（2026-10-16）

在当前平衡分支、Godot 4.7.2 图形窗口 1373×883、D: 隔离用户数据中运行 `test_beginner_guide.gd`；游戏进程暂停，截图中的 FPS 不作性能证据。结果：54 checks，0 failures，原始输出见 `guide-visible.txt`。

测试从新档开始，逐个补满三个武器槽，再补第二防御槽；铁为0时显示当前实际升级费用，资源足够时切换到升级提示。还核对关闭后不自动重开、帮助入口手动回看、解锁通知优先接管引导。截图见 `equip-first.png`、`defence-before-upgrade.png`、`waiting-cost.png`、`affordable-upgrade.png`、`help-entry.png`。图形截图确认提示框、数值卡与操作按钮可读；这不是玩家自行理解或正常开局节奏验收。
