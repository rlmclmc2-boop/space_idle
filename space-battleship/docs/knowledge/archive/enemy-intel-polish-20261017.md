# 敌情页视觉打磨

- 目标：敌情页达到现有游戏美术的正式质量，保留当前战点跟随和真实表数据。
- 范围：`scripts/enemy_intel_page.gd`、敌情页必要的 `main.gd` 尺寸入口与页面证据。
- 禁止：不改敌人表、关卡数值、教程、main 接线，也不合 main。
- 基准：`c66190090c3bded4e09beb347acad59e589910c2`，独立分支 `art/enemy-intel-polish-20261017`。
- 停止条件：影响其他页面或数值，需要向父线程报告；GUI 使用需获窗口分配。
- 定位：`scripts/enemy_intel_page.gd` 的 `setup`、`show_point`、`show_entry`；`scripts/main.gd` 的页签 11 接线。
- 已知风险：现有舰图为多种来源，视觉须用页面框架统一；需要 GUI 截图确认窄窗口布局。
- 结果：复用舰图和星空资产，重整战点航线、编队、静态扫描展台和折叠详情；敌情页按视口收缩，其他页尺寸恢复；只在换关或手动选择时建内容。
- 验证：Godot 4.7.2 实际场景 1920×1080 与 1440×900；战点跟随、手动浏览、详情开合、换关、隐藏态及页签尺寸断言通过。原图与同尺寸 JPG 位于 `docs/tasks/enemy-intel-polish-20261017/evidence/`。
- 未决：`mon 271006` 与 `271007` 同名同 `intelVisualRef`，交数值线程确认。
