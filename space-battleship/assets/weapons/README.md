# 武器素材消费

当前入口src/main.gd通过Battle与native retained/GPU表现消费武器素材；飞行弹体、槽位图标、真实炮塔图像用途不同，不能互相替换。舰上静态武器及完整轴心/发射口由fleet_20261019/manifest.json定义，双导弹口都须保留；共享真实几何按ship_geometry_convention.gd。旧PROJECTILE_SIZES或已删除ART_GUIDELINES不再是入口。

现行制作和可见验收只见[M/V模块](../../docs/game-design/art/modules/battle.md)；本页只说明当前素材边界，不保留生成历史、旧验收报告或方案入口。
