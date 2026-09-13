# 武器

## CONFIRMED · 原表

总览!A8:A9 与 equipment!B44/B64/B84：激光/火炮单目标；导弹锁定多个不同敌人，目标不足不多发，数量读取 para1。伤害、冷却和弹速的字段及数据范围只见 [DATA](../DATA.md)。解锁规则见 [progression](progression.md)。

## CONFIRMED · 当前代码

- `targets()` 对活敌按 x 升序、距编队中线距离、slot 排序。玩家每次武器冷却到零时选择该列表前若干目标；导弹按数量上限发射。首次玩家冷却默认零，敌机初始冷却为武器 CD。
- `fire()` 创建字典弹体，携带目标对象、飞行方向、伤害、类型、速度、敌我、武器键。弹速乘 defaults.projectilePixelsPerUnit。目标死亡/移除时，仅导弹可重定向到第一个活敌；没有可锁目标则解除锁定、保持最后飞行方向直至出屏，激光/火炮不换靶。下次开火仍重新选取活敌。来源：2026-09-13 用户本次换靶及继续飞行指令；锁定顺序等剩余边界见 U-006。
- `tick_projectiles()` 在战斗、巡航、通关等待及死亡后退期间更新；敌舰死亡、波次结束、BOSS通关不清除已发射弹体，敌方弹体仍可命中存活玩家。出屏判定包含32像素尾迹余量，绘制直接使用保存的方向，不依赖失效目标。
- 敌机每个 equipment 条目每轮只发一发；不按导弹 para1 发多枚。当前编队没有引用敌方导弹；未来启用前见 U-011。
- `ShipDatabase.enemy_weapon()` 将 `_mon`/`-mon` 去掉映射同名玩家武器：整行缺失则采用玩家同级整行；已有行仅补 null 的 dmg/cd/dmgtype/para1/para2。para3 不在补全字段内。
- `|` 右值当前导入为 level；原表 C2 称“数量”，冲突只见 U-002。当前原表敌方火炮 E106/F106 有值，不能再称其缺伤害/CD；敌方 2 级行缺失仍为事实，见 U-003。

追踪：equipment → JSON equipment → database.equip/ enemy_weapon → game.fire/targets/tick → test_game 的 fallback、Missile fires、Distinct missile targets。添加武器前先检查 EQUIPMENT、UI 名称映射及导入器固定玩家键，见 U-007。
