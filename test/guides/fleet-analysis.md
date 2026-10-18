# 结果分析、定向复测与设计卡片

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 战斗结果分析 | `test_fleet_result_analyzer.gd --headless` 检查按样本加权、敌我标签、条件武器分析、区分度/候选、低样本和时间波动降级、旧文件兼容、重复记录拒绝与六文件导出。`test_enemy_fleet_ui.gd` 覆盖第四页读取当前批次、排序筛选、关联配对和不重跑战斗。 |
| 分析页定向复测 | `test_fleet_batch_retest.gd --headless` 检查低样本配对预算、只跑指定配对、原批次保留、合并统计及方差、分析重读；`test_battle_lab_standalone.gd` 检查同页启动复测并自动刷新。 |
| 关卡设计卡片 | 共用 `test_fleet_result_analyzer.gd` 验证设计分类、低样本不排名、强弱不重复；`test_enemy_fleet_ui.gd` 检查默认卡片/总览、中文标签、控件复用、滚动后详情点击以及原统计视图保留。 |
