# 敌我组合生成

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 敌方舰队生成与标签 | `test_enemy_fleet_formation.gd --headless` 检查八类阵型、奇数核心、结构分数/阈值、去重、数量/强度与重放；`test_enemy_fleet_simulator.gd --headless` 覆盖旧基础分析（含固定数值夹具）；`test_enemy_fleet_ui.gd` 检查游戏 F9。独立工具布局预览由 `test_battle_lab_standalone.gd` 检查。原生光标不可用时，UI 夹具使用内嵌窗口路由鼠标事件。 |
| 我方测试组合与配对 | `test_player_loadout_generator.gd --headless` 检查原规则合法性、四类覆盖、seed/JSON 复现、属性投影、去重和配对加载；共用 `test_enemy_fleet_ui.gd` 检查双页独立更新、武器/标签筛选、配对预览与清空。 |
