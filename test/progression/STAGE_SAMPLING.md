# 长区间日志控制

`benchmark_campaign.py` 支持 `--sample-seconds`（X1 秒，0 仅首尾）、`--max-samples`（默认256，至少2，包含首尾）、`--checkpoint-wall-seconds`（墙钟秒，默认30）。逻辑步长、原生策略和动作日志不变；原子断点独立于状态采样。首尾必记，中间样本达到上限后停止写入并计数，不声称未采样的每步均相等。短校准仍建议1秒采样；长段建议300秒并按时长配置上限。恢复会重新开始本次计数，继续保存输入来源和分支谱系。

配对结果比较采样步号、完整状态和原生操作序列；运行区间未完成或任一比较不同即失败。冻结的7f198cf提速候选不受此改动影响。

`benchmark_stages.py --resize-challenge --scenarios combat --modes full,cached --seconds 4` 在每个整数X1秒边界切换960×540、1920×1080、1373×883，并保持布局更新期间逻辑时刻和RNG不变。cached坐标与清缓存后的原函数重算比较；连续固定步状态也进行配对。不替代晚期原生玩家操作覆盖。缓存epoch包含原函数使用的有效屏幕比例。

阶段目录分别展示cleared、highest与保存journey的stage/group；保存位置不等同正式恢复后的实际战点。首次输出状态是该次实际恢复位置的证据，不能按save_reachN命名推断正在第N关战斗。

可见强化页：cached继续按X1每1秒刷新生产指标，原生决策前额外刷新可见强化面板。放弃仅“游戏状态相等”推断展示全等；`enhancement_native_probe.gd` 留存实际导航、升级意图、可用性、逐秒指标与战斗状态供配对。夹具能源/碎片不足的拒绝意图不能当作成功购买覆盖。

近似粗筛：`benchmark_stages.py` 默认参考为full、否则cached、否则首模式，可用`--baseline-mode`明确指定；单模式输出unpaired，无比较不等于通过。配对报告除字段差异外，还记录逐样本敌HP/盾及我方甲/盾误差、命中事件总伤害/次数、唯一击杀、战点结束、败退、资源净增减、待领取掉落及新通关列表。命中伤害含吸收和过量，不能解释为截断后的有效HP损失；资源包含生产，应连同run_resources和pending_drops评估。零参考相对误差为undefined，保留绝对误差。无场景按已校准机体、武器、区段与误差包络选择，只可粗筛，临界胜负/耗时必须回精确模式。

显式QA A/B：`benchmark_campaign.py --no-new-manual` 设置保存选项 `allow_new_manual=false`。默认不覆盖原断点该选项；原断点未保存则默认true。策略子类只覆盖手动重试资格及待派遣查询，不清空历史、既有收益、待请求或监测记录；继承自动探索/领奖/装备/付费锻造/主线决策及当前手动退出预算。重载仍按正式规则处理已中断手动，开关不绕过保存事务。动作日志标注qa_policy_modifier，不能把A/B与原P2完整策略称为等价。父可用33619.58同档3600X1与既有基线比较主线占用和推进；本工具不直接修改当前守点或机体策略。可接入698/6ca冻结scene_driver（已校验hash），生产/数值/基础策略连续性仍逐文件拒绝不符。

实验性VFX分支（单独冻结，不合入已验证cached）：`--vfx-probe`在cached使用同原callbacks的计数场景；再加`--vfx-fast`在该QA子类令fast_mode_enabled为true，绝不修改game.speed。full始终原场景，默认cached始终原cached_battlefield。qa-vfx-counts记录每事件容器正净增长，不能等同临时分配总量/GPU时间。main.weapon_launch在快速返回前保留target/fired_at/recoil；连续beam_started跳过的是表现时间戳，需要按武器/档案做精确反证，不凭审查宣称全部等价。20关自然导弹档10.017X1秒实验只覆盖该段：12样本/原生动作/RNG同full与普通cached全等，speed1；相同计数开销cached4.135秒→fast2.895秒=1.428x，game_tick1.856秒→0.624秒。619事件，容器正净创建510→4。没有全战役/磁轨/持续光束/全部界面白名单。
