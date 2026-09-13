# 战斗与伤害

## CONFIRMED · 原表

总览!A4:A5：自动攻击，敌群全灭才前进，战斗时停止移动，BOSS 击毁通关。equipment!D2：1=能量、2=物理；config!A5:C5 定义类型相同时减伤。equipment!B24 定义先护盾再装甲及受击中断恢复；B4 定义生命耗尽后退。具体回退参数不是原表规则（U-005）。

## CONFIRMED · 当前代码（不是额外策划承诺）

- `reduced_damage(raw,type,resistance)`：类型相同令 f=1-config.dmgReduce，否则 f=1；结果 `max(1,ceil(raw*f))`。原表没有规定统一最小伤害和这一取整流程，见 U-006。
- 敌方出手 raw=`ceil(weapon.dmg * enemy.dmgMultiple * ratio(atkRatio))`；玩家出手 raw=当前武器 dmg。敌人命中用其 armourType 结算。
- 玩家护盾损失=`min(当前护盾,reduced_damage(raw,...))`；剩余原始伤害=`max(0,raw-护盾损失/f)`；再按装甲类型对剩余原始伤害减伤，装甲最低零。护盾/装甲抗性目前读取**1 级行**；逐级抗性差异边界见 U-006。
- `since_hit` 每次受击清零，活跃状态累加。达到当前护盾 para3 后，每步恢复 `max_shield()*para2*dt`，不超上限。
- `begin_retreat()` 清敌机、玩家冷却，保留弹体（失去目标后飞行规则见 weapons）；后退距离读取 config.backRange，来源见 [map](map.md)。tick 在 defaults.deathRetreatDuration 内插值后退，恢复生命/护盾，进入 TRAVEL；目标点及之后敌群可重新触发。已收集资源保留，地上掉落仍按拾取系统计时。
- main._process 把帧间隔限到 0.1 秒，按 game.speed 缩放，再拆为不大于 1/60 秒步长。paused 阻止模拟及拾取推进；解锁弹窗阻止下一关计时，但掉落计时仍执行。

归属：锁定/导弹分发见 [weapons](weapons.md)，通关/重刷见 [map](map.md)，掉落见 [economy](economy.md)。
追踪：`scripts/game.gd` hit_player/hit_enemy/reduced_damage/begin_retreat/tick → `../test/test_game.gd` Resistance、overflow、Retreat、Pause。实测状态见 [VALIDATION](../VALIDATION.md)。
