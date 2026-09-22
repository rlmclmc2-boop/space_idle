# balance_history

## 2026-09-21 19:06:41 / schema 2 / rules_v2 / RANDOM_VALID

- 版本：配置SHA-256 `0e3606f53b7cfc68a7091629b1b3a43c072de171799188afb7c5f0830d612c95`，与当前一致；Godot4.7.2，测试源码指纹缺失。
- 条件：10×2h，seeds12345–12354，100x、1/60秒、30秒采样，真实新局；两份中止批次排除。与旧BALANCED 1h不同条件，不作归因对比。
- 主要问题：P1第14关攻血×8.91、死亡22–38次；DPS全局离散被高关曝光放大；自动随机换装虚增决策；宝石9局未合成，策略覆盖待验。
- 修改参数：无。下一轮先扫 `levels/13/atkRatio` 10138/9124.2/8110.4，各10×2h同种子；lifeRatio和resRatio仅作后续独立扫描。
- 测试结果：最终18–19关；死亡234–260；DPS均值18.97亿、中位4.05亿。下一轮待测试。新Baseline保存于 `../../test/work/balance_review_20260921_190641/baseline_20260921_190641.json`。
- 详情：[最新复盘](balance_review.md)、[统计](../../test/work/balance_review_20260921_190641/statistics.json)。旧记录仅供历史追溯，旧第2关1.8参数建议不再直接适用。

## 2026-09-21 / schema 2 / rules_v2

- 版本：Godot 4.7.2；配置 SHA-256 `89b0de4a7e2a0ad2d136d568153e31856b4ee26c8c3776f36c04cf15457c2f1f`，已按 Lab 的 JSON.stringify 口径核对当前配置。代码为未提交工作区，HEAD `6be3bff` 不是测试源码版本证明。
- 条件：最新完整导出 2026-09-21 17:54:18（文件本地时间），BALANCED，10×3600 秒，seeds 12345–12354，100x，固定步长 1/60 秒，30 秒采样，真实新局。
- 主要问题：P1 第2关每局死亡32–35次；非重复选择代理空窗957–1046秒；10局均无宝石生成。METRIC ISSUE：重复升级计入决策、Boss TTK遗漏失败尝试。未证实P0、模拟分叉或策略程序错误。
- 修改参数：无。建议三个真实字段独立扫描：`levels/1/atkRatio` 1.8/1.62/1.44；`equipment/armour/0/para1` 1000/1100/1200；`levels/1/resRatio` 1.4/1.54/1.68。先做攻击倍率扫描，其余按结果分阶段进行，不组合改动。
- 测试结果：当前最终关卡均值7.6，死亡115.5，普通TTK 5.084秒；下一轮待测试。最新扫描只有2秒×2局/档，不用于平衡结论；无匹配的既有Baseline。
- 证据：[复盘及统计口径](../../test/work/balance_review_20260921/review.md)、[完整统计](../../test/work/balance_review_20260921/statistics.json)、[原报告](../../test/work/balance_lab/balance_2026-09-21T17-54-18_704533990.json)。当前批次已另存独立Baseline供下一轮使用。
