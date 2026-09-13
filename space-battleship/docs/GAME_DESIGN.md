# 游戏设计地图

本文件只导航。模块内 CONFIRMED 分“原表”和“当前代码”；争议统一在 [TODO](TODO.md)。Excel 单元格定位与结构化数值入口在 [DATA](DATA.md)。

| 实际系统 | 细则唯一文档 | 设计 → 数据 → 实现 → 测试 |
|---|---|---|
| 舰船、装甲、护盾、敌机 | [ships](modules/ships.md) | equipment/mon → equipment/enemies → game.stat/reset_player/spawn_group → test_game：Shield delay、Shield regeneration |
| 自动战斗、抗性、回退 | [combat](modules/combat.md) | 总览、config → config/defaults → game.tick/hit_player/hit_enemy → test_game：Resistance、overflow、Retreat |
| 激光、导弹、火炮 | [weapons](modules/weapons.md) | equipment → equipment → database.enemy_weapon、game.fire/targets → test_game：fallback、Missile |
| 资源、掉落、拾取 | [economy](modules/economy.md) | mon/res/config → enemies.drops/resources/config → game.collect → test_game：Hover、Timed pickup |
| 装备升级、解锁 | [progression](modules/progression.md) | equipment → equipment → game.upgrade/rebuild_unlocks → test_game：Upgrade、unlock popup |
| 关卡、敌群、倍率、循环 | [map](modules/map.md) | level/monGroup → levels/groups → database.ratio、game.spawn_group/clear_level → test_game：interpolation、Complete stage |
| 游戏 UI、附属 QA 窗口 | [ui](modules/ui.md) | 总览交互 + 代码 → profile/运行状态 → main/config_panel → test_game 原生按钮；test_config_panel 导入/场景重载 |

测试标识是搜索用的断言文本，不代表当前全部通过。真实结果见 [VALIDATION](VALIDATION.md)。建造、科技等未出现的系统不建空模块，边界见 TODO U-009。
