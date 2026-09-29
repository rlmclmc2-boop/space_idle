# 舰船素材

本目录保存已接入运行时的舰船透明 PNG。统一画布为 887×1774，源图单舰俯视、舰首朝上；敌舰在战场中旋转 180°，朝向我方。敌舰 `size` 映射与缩放见 [视觉入口](../../docs/ARCHITECTURE.md)，素材槽位和生成约束见 [美术规范](../../docs/ART_GUIDELINES.md)。

本批素材以旧图为参考，使用内置 `image_gen` 编辑为透明、无武器的纵向舰体，保留各舰配色、发动机和装甲特征。挂点与贴图归一化比例 `display_scale` 见 [视觉配置](../../data/ship_weapon_visuals.json)；可调的我方 5 型、敌方 6 档显示倍率见 [config.xlsx](../../config_excel/config.xlsx)。战场和换舰预览共用我方倍率；玩法 `size` 不变。

## 当前贴图

以下 11 张 PNG 均为 887×1774、带透明通道，已由 `scripts/main.gd` 接入战场。文件名中的 `slot` 仅是历史命名，不代表烘焙武器数；运行时选敌舰贴图依据 `size`。

| 阵营 | 运行时对应 | 贴图 |
|---|---|---|
| 我方 | `Frigate` | [player-scout-3slot.png](player/player-scout-3slot.png) |
| 我方 | `Destroyer` | [player-interceptor-4slot.png](player/player-interceptor-4slot.png) |
| 我方 | `Cruiser` | [player-cruiser-5slot.png](player/player-cruiser-5slot.png) |
| 我方 | `Battleship` | [player-battleship-6slot.png](player/player-battleship-6slot.png) |
| 我方 | `Heavy_Battleship` | [player-dreadnought-8slot.png](player/player-dreadnought-8slot.png) |
| 敌方 | `size = 1` | [enemy-scout-1slot.png](enemy/enemy-scout-1slot.png) |
| 敌方 | `size = 2` | [enemy-medium-1slot.png](enemy/enemy-medium-1slot.png) |
| 敌方 | `size = 3` | [enemy-medium-2slot.png](enemy/enemy-medium-2slot.png) |
| 敌方 | `size = 4` | [enemy-large-4slot.png](enemy/enemy-large-4slot.png) |
| 敌方 | `size = 5` | [enemy-large-6slot.png](enemy/enemy-large-6slot.png) |
| 敌方 | `size = 6` | [enemy-super-8slot.png](enemy/enemy-super-8slot.png) |
