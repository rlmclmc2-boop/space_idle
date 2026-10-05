# 长区间日志控制

`benchmark_campaign.py` 支持 `--sample-seconds`（X1 秒，0 仅首尾）、`--max-samples`（默认256，至少2，包含首尾）、`--checkpoint-wall-seconds`（墙钟秒，默认30）。逻辑步长、原生策略和动作日志不变；原子断点独立于状态采样。首尾必记，中间样本达到上限后停止写入并计数，不声称未采样的每步均相等。短校准仍建议1秒采样；长段建议300秒并按时长配置上限。恢复会重新开始本次计数，继续保存输入来源和分支谱系。

配对结果比较采样步号、完整状态和原生操作序列；运行区间未完成或任一比较不同即失败。冻结的7f198cf提速候选不受此改动影响。

`benchmark_stages.py --resize-challenge --scenarios combat --modes full,cached --seconds 4` 在每个整数X1秒边界切换960×540、1920×1080、1373×883，并保持布局更新期间逻辑时刻和RNG不变。cached坐标与清缓存后的原函数重算比较；连续固定步状态也进行配对。不替代晚期原生玩家操作覆盖。缓存epoch包含原函数使用的有效屏幕比例。

阶段目录分别展示cleared、highest与保存journey的stage/group；保存位置不等同正式恢复后的实际战点。首次输出状态是该次实际恢复位置的证据，不能按save_reachN命名推断正在第N关战斗。
