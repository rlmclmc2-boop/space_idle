# 美术规范

## 舰船与武器槽位

- 舰船素材使用真实透明 alpha 的 PNG，默认画布为 1774×887，单舰、严格横向侧视、舰首朝右；画布外不得有背景、阴影平面、文字、Logo、弹体或已安装武器。
- 舰船图内的武器槽只表现为圆形凹入式安装座，不画具体武器。安装座沿上/下两条硬点轨道等距排列；奇数槽位保持同一轨道顺序，不通过改变槽位直径补偿数量。
- 槽位尺寸按安装座外径统一为小/中/大型三级：小 = 1.0 单位，中 = 1.35 单位，大 = 1.75 单位。武器图标的可见主体控制在对应槽位内径的 70%–80%，不能遮住安装座边缘。
- 舰船尺寸等级只影响舰体轮廓与槽位数量，不改变同一尺寸槽位的几何形状。素材在相同画布和透明安全边距内交付，运行时再按用途缩放。
- 我方使用深海军蓝、白色装甲和青色发光；敌方使用石墨黑、暗红装甲和琥珀橙发光。两方均保持清晰的装甲分层、舱体接缝和发动机发光边缘。

## 本批舰船资产

| 阵营 | 文件 | 槽位数 | 槽位尺寸 | 默认编队备注 |
|---|---|---:|---|---|
| 我方 | `assets/ships/player/player-scout-3slot.png` | 3 | 小 | — |
| 我方 | `assets/ships/player/player-interceptor-4slot.png` | 4 | 小 | — |
| 我方 | `assets/ships/player/player-cruiser-5slot.png` | 5 | 中 | — |
| 我方 | `assets/ships/player/player-battleship-6slot.png` | 6 | 中 | — |
| 我方 | `assets/ships/player/player-dreadnought-8slot.png` | 8 | 大型 | — |
| 敌方 | `assets/ships/enemy/enemy-scout-1slot.png` | 1 | 小 | 默认 4 艘一组 |
| 敌方 | `assets/ships/enemy/enemy-medium-1slot.png` | 1 | 中 | — |
| 敌方 | `assets/ships/enemy/enemy-medium-2slot.png` | 2 | 中 | — |
| 敌方 | `assets/ships/enemy/enemy-large-4slot.png` | 4 | 大型 | — |
| 敌方 | `assets/ships/enemy/enemy-large-6slot.png` | 6 | 大型 | — |
| 敌方 | `assets/ships/enemy/enemy-super-8slot.png` | 8 | 大型 | — |

## 武器图标规范

- 槽位图标与战斗弹体分开保存：`assets/weapons/icons/` 是装入舰船槽位的武器模块，`assets/weapons/` 根目录下的 PNG 是飞行中的弹体纹理。
- 每个图标只包含一个紧凑武器模块，使用方形透明 PNG，主体居中并保留至少 10% 透明安全边距；本批源图为 1254×1254，消费端可缩放到 256×256 或槽位内径。
- 图标主体控制在对应槽位内径的 70%–80%，同一图标可用于小/中/大型槽位，按 1.0/1.35/1.75 单位等比缩放；不得把外层槽位环、舰体、背景、文字或 UI 一起画进图标。
- 激光使用青白聚焦透镜与青色能量轨；导弹使用白色装甲、红色中脊和双发射舱；火炮使用深色金属、铜箍和琥珀磁能线圈，三者在小尺寸下仍须可区分。
- 生成提示中必须写明：`transparent alpha`、`single weapon module`、`no ship/no background/no text`，并注明目标槽位尺寸或“可缩放到小/中/大型槽位”。
- 命名使用小写 kebab-case；新增素材同时更新所在目录 README，记录用途、槽位尺寸、生成提示和消费端缩放规则。
