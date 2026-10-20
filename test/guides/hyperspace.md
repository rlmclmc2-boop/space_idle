# 无人机与异空间反馈

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 无人机改造指南 | `test_hyperspace_guide.gd --headless`：首胜前隐藏改造与预设、按当前操作查阅、短窗口、控件复用、只读状态与改造结果回显；不作进度或通关验收 |
| 无人机玩家反馈 | `test_hyperspace_player_feedback.gd`：已结算奖励跳转、显式装备、真实材料需求/持有/缺口、领域随机状态不变、进度刷新不重算报价、原子换装接口与多槽选择；图形证据是夹具，不作连续进度验收 |
| 手动航线与奖励来源 | `python test/run.py test_hyperspace_manual.gd --headless --godot <Godot路径>` 检查合成航线的十波、返回、领取及退款；`python test/run.py test_hyperspace_catalog_consumers.gd --headless --godot <Godot路径>` 自动生成合法的奖励来源夹具并验证早段冻结值、晚段与命中来源。两者都不证明自然进度或图形表现。 |
