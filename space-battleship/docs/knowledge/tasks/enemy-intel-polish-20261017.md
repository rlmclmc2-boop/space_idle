# 敌情页视觉打磨

- 目标：敌情页达到现有游戏美术的正式质量，保留当前战点跟随和真实表数据。
- 范围：`scripts/enemy_intel_page.gd`、必要的页面文案与页面证据。
- 禁止：不改敌人表、关卡数值、教程、main 接线，也不合 main。
- 基准：`c66190090c3bded4e09beb347acad59e589910c2`，独立分支 `art/enemy-intel-polish-20261017`。
- 停止条件：影响其他页面或数值，需要向父线程报告；GUI 使用需获窗口分配。
- 定位：`scripts/enemy_intel_page.gd` 的 `setup`、`show_point`、`show_entry`；`scripts/main.gd` 的页签 11 接线。
- 已知风险：现有舰图为多种来源，视觉须用页面框架统一；需要 GUI 截图确认窄窗口布局。
- 下一动作：重整页面层级，按最小范围验证并提交证据。
