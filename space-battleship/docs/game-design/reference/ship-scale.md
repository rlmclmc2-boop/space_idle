# 舰船缩放与尺寸参考

[唯一入口](../README.md)。设计准则与验收以 [M1/V1](../art/modules/battle.md) 为准，本页仅保存静态参数事实及计算边界。

## 8. 舰船缩放与尺寸量化附录（实现事实与适配约束）

本节核对基线为 `main@6b20296496244d849da4df809c3cbf963815d726`。数值来自现有 Excel、JSON 和 PNG 元数据，计算为静态复算，未启动游戏、未新增运行测试。配置日后变化以实际消费值为准；本节仅统计当前参数，设计目标、空间约束、待定参数和验收标准统一见 [M1](../art/modules/battle.md)。

### 8.1 来源、单位与消费顺序

| 证据入口 | 本节消费的字段/职责 |
|---|---|
| `config_excel/battle_geometry.xlsx` → `battle_geometry` 表 | `player_display_multiplier=1.7`；玩家锚点 `(286,520)`；当前逻辑视口 `572×960`；敌方旋转扰动 `enemy_rotation_variance=4` 度及旧宽度算法参数。 |
| `config_excel/config.xlsx` → `config` 表 | `name` 为键、`para_1` 为数值：五种 `playerVisualScale<ship_key>`、六种 `enemyVisualScaleSizeN`。`des` 中“仅影响舰体贴图”是过时说明，不代表当前作用范围。 |
| `data/ship_weapon_visuals.json` → `ships` | 每个 visual_key 的贴图、`static_height`、挂点；精英/首领的 `display_size`；兼容旧算法的 `display_scale/formation_reference_height`；炮台投影用 `model_span/weapon_scale`。 |
| `src/systems/battle.gd::_load_models/mount_inputs` | 读取实际贴图 alpha 生成标准化凸包；按下式算我舰高度与画布变换尺寸，不读取 UI 预览高度。 |
| `scripts/ship_geometry_convention.gd::battle_geometry/transform_hull` | 使用相同尺寸变换实际轮廓；当前 enemy_opening_* 走旋转后等比适配分支。 |
| `src/systems/battle.gd::_sync_geometry/_draw_hull_texture` | 同一轮廓用于纹理多边形绘制与 native 几何输入；真实目标、挂点和炮口继续用当前共享链，不另设贴图专用缩放。 |

本节“逻辑单位”是当前战场逻辑坐标，在基线 572×960 逻辑视口内使用；不等于桌面窗口物理像素。“源图像素”是 PNG 的像素，不直接作为战场尺寸。“舰体逻辑外接框”仅含 alpha 舰体轮廓，不含独立炮台、护盾外缘、盾甲条及特效。

### 8.2 我方五档实际倍率与舰体逻辑尺寸

定义 `B=static_height`、`G=1.7`、`P=config.playerVisualScale<ship_key>`，当前 `mount_inputs` 使用：

```text
H = B × G × P
D = 源图画布尺寸 × H / (源图高度 × 标准化alpha凸包高度)
玩家逻辑轮廓 = transform_hull(标准化alpha凸包, (286,520), D, 0)
```

`H` 是目标舰体轮廓高度；`D` 是整张源画布的坐标变换尺寸，包含透明边距，不是舰体外接框。下表按当前 PNG 的 alpha>0 外接框静态复算，显示到三位小数；实际 Godot 以 `normalized_hull` 的边界及浮点结果为准。这些是舰体尺寸推导，不是完整装配包络实测。

| 舰型 / ship_key | 基准高 B | 全局 G | 分舰 P | 有效乘积 G×P | 舰体逻辑外接框 W×H | 整画布变换尺寸 D，W×H |
|---|---:|---:|---:|---:|---:|---:|
| 护卫舰 / Frigate | 60.2 | 1.7 | 1.3 | 2.21 | 98.124×133.042 | 112.268×147.186 |
| 驱逐舰 / Destroyer | 81.0 | 1.7 | 1.1 | 1.87 | 107.338×151.470 | 119.306×163.438 |
| 巡洋舰 / Cruiser | 104.8 | 1.7 | 1.2 | 2.04 | 162.792×213.792 | 175.848×226.848 |
| 战列舰 / Battleship | 109.6 | 1.7 | 1.3 | 2.21 | 212.602×242.216 | 226.746×256.360 |
| 重型战列舰 / Heavy_Battleship | 122.6 | 1.7 | 1.4 | 2.38 | 247.996×291.788 | 263.228×307.020 |

例如重型战列舰：`122.6×1.7×1.4=291.788`；当前 alpha 高 613、宽 521，故宽为 `291.788×521/613=247.996`。不能再乘 JSON 中的 `display_scale=0.12`，也不能把 UI manifest 的 `height=582.5876` 当战场基准高。

`mount_inputs.dimensions` 经 `prepare_player/_accept_player` 成为 `_player_dimensions`，随后生成 `_player_hull`。`_sync_geometry` 将它交给 `input_player_hull`，敌方凸包交给 `input_ballistic_geometry`，并把挂载/炮口交给同一 native 核；`_draw_hull_texture` 用这组轮廓和源 UV 绘制。因此表中我舰缩放同时影响共享轮廓与其接触几何、挂点空间关系；不是单独放大一张贴图。它不改变装备伤害、盾甲容量或经济数值。

炮台仍有自身投影参数：`approved_weapon_art.gd::player_pose` 取 `rendered_height/model_span` 与 `weapon_scale`，再由现行武器 manifest 的 `pixels_per_model/visual_scale/anchor/emission_pixels` 得到图像尺寸和每个真炮口。五档 `model_span/weapon_scale` 分别为 `5.669695/0.72`、`5.723601/0.68`、`6.304464/0.68`、`6.334/0.65`、`6.814157/0.58`。这些仍生效，不能将其当作废弃舰体倍率删除，也不能只凭舰体表推定转动炮台均在舰体框内。

### 8.3 战斗源图、UI 预览与原稿分别统计

| 舰型 | 战斗 PNG 画布，源像素 | 战斗 PNG alpha 外接框，源像素 | UI 预览 PNG 画布，源像素 | UI manifest 的 height，预览源坐标 |
|---|---:|---:|---:|---:|
| Frigate | 254×333 | 222×301 | 768×768 | 285.6336 |
| Destroyer | 319×437 | 287×405 | 768×768 | 384.611 |
| Cruiser | 431×556 | 399×524 | 768×768 | 497.6115 |
| Battleship | 513×580 | 481×548 | 768×768 | 520.6 |
| Heavy_Battleship | 553×645 | 521×613 | 768×768 | 582.5876 |

战斗 PNG 依次为 `assets/ships/fleet_20261019/player/{01-frigate,02-destroyer,03-cruiser,04-battleship,05-heavy-battleship}.png`；UI 预览是 `assets/ui/ships/fleet_20261019/` 下对应同名文件，元数据在 `assets/ui/ships/manifest.json`。UI 的 768 画布、height 和 mounts 是预览源坐标，实际显示还取决于控件适配，不能报成屏幕显示尺寸。当前 `src/ui/fleet_panel.gd` 的选择器也不等于已接入这套完整预览布局。

原稿及分割来源见 [fleet 源说明](../../../art_sources/fleet-20261019/README.md) 与同目录 `split-report.json`：战斗图为带透明边距的裁切产物；五档 `static_height` 是分割主体高度×0.2。旧源画布参考 `formation_reference_height=1774` 在五档均相同，是兼容旧敌宽算法的参考输入，不是这些裁切 PNG 的当前高度，也不是 UI 预览画布高度。该源说明中仍残留的 `geometry_texture`、presentation-only 等描述不取代 8.1 的实际消费链。

### 8.4 敌方普通、精英与首领适配框

当前加载的八个普通家族为 scout、sentry、interceptor、swarm、anchor、reactive、shielded、command；纹理画布均为 887×1774 源像素。普通条目无 `display_size` 时使用代码默认框 `90.4×79.3333333333` 逻辑单位。此框约束旋转后舰体外接框，不是源图宽高、碰撞矩形或完整含条形 UI 的占位。

精英/首领的 `ships.enemy_opening_<家族>_<rank>.display_size` 如下，均为逻辑适配框；展示到六位小数，精度以 JSON 原值为准。对应八张分级纹理也都是 887×1774 源像素，不按源画布直接放到战场。

| 家族 | 精英 display_size W×H | 首领 display_size W×H |
|---|---:|---:|
| anchor | 201.473193×154.735043 | 208.733489×194.666667 |
| reactive | 178.747664×166.012461 | 176.473520×194.666667 |
| shielded | 185.396825×153.415873 | 201.155556×194.666667 |
| command | 152.655271×149.327635 | 170.125356×194.666667 |

纹理在 `assets/ships/enemy/fleet_20261019/` 与 `assets/ships/enemy/elite_boss_20261020/`。选择分级 visual_key 依据 `enemy_visual_identity.gd::visual_rank/resolve/legacy_key` 的 `combat_tier`、`encounter_leader`、家族及装甲身份；不能用数值 size、终波序号或适配框大小自行推断精英/首领。当前仅四个 ranked 家族有上述专用分级条目，其余普通家族仍走各自普通 key；这不改它们的玩法身份。

**旋转及等比适配的实际顺序：**

```text
θ = 按 actor.uid/slot 的独立几何随机流产生的 [-4°, +4°] + 180°
(w,h) = 标准化alpha凸包外接框尺寸 × PNG画布尺寸
(rw,rh) = (w×|cosθ| + h×|sinθ|, w×|sinθ| + h×|cosθ|)
(Aw,Ah) = 该条目 display_size，缺省为普通框
fit = min(Aw/rw, Ah/rh)
D = PNG画布尺寸 × fit
逻辑轮廓 = transform_hull(标准化alpha凸包, actor位置, D, θ)
```

源船首朝上，转 180° 后朝下；±4° 扰动仍有效。每个 actor 的 fit 随其角度变化，横纵使用同一比例，不能把图拉伸填满适配框；矩形旋转边界公式是保守适配，不保证实际凸包同时触满框的两条边。分级模型同样用最终轮廓绘制、碰撞和挂点，不能另外给显示与命中应用两组尺寸。

### 8.5 保留字段中已被覆盖或不再走当前链的倍率

“仍在文件里/仍被读取”不等于“仍决定最终尺寸”。以下仅说明当前已加载静态舰图的有效性，不授权清理配置或删除兼容算法。

| 参数/旧路径 | 基线值 | 对当前最终舰体尺寸的作用 |
|---|---|---|
| 我舰 `display_scale` | Frigate 0.061、Destroyer 0.093、Cruiser 0.081、Battleship 0.093、Heavy_Battleship 0.12 | 不参与当前 `mount_inputs` 我舰高度。仍作为 `enemy_width` 的 `base_art_scale` 中间输入（与 1.7 相乘），随后当前 enemy_opening_* 分支覆盖最终敌尺寸；不能把它再叠乘进 8.2。 |
| `enemyVisualScaleSize1…6` | 1.2、1.2、1.4、1.5、1.5、1.7 | 旧 enemy_width 中间计算读取，但当前八家族及八分级 key 均以适配框重新写 `dimensions`，所以这些倍率不决定其最终舰体尺寸。 |
| 旧敌宽/高算法 | base 0.34、canvas span 1.2；宽上限普通54/大型66/终波78；tier终波1.85/大型1.5，size增长0.08；depth上界1.12；variance `[0.90,1.08]`；密集宽 cap74；model高宽比2 | 先计算旧 width/初始 dimensions，再被 enemy_opening_* 的 `model.size×fit` 覆盖。尺寸扰动在当前最终适配中失效，旋转扰动±4°仍有效，不能一起标废弃。旧分支若未来服务其他 key，须另核对，不能自动扩展此结论。 |
| `actor.hull_scale` | 首领 boss 1.35、ultimate 1.65，其他1；值由 `src/combat_setup.gd` 写入 | 在初始 dimensions 中相乘，但当前 enemy_opening_* 适配分支随后覆盖，不再额外放大上述首领图；首领尺寸由相应 display_size 控制。不能在框适配之后补乘一次。 |
| 旧 `scripts/ship_visuals.gd` 显示设置 | `visuals/player_ship_scale` 缺省1.25、clamp `[0.5,2.0]`；旧 `size×44/887` 等 | 不在当前 `battle.gd::mount_inputs`/`battle_geometry` 舰体尺寸链中，不能与当前 1.7 或分舰倍率叠乘。该脚本中的“只影响表现”注释不能描述当前共享几何。 |

### 8.6 本统计尚未证明的验收项目

最大**舰体**是本表中的 Heavy_Battleship，静态推导外接框约 `247.996×291.788`；这不证明它也是任意炮台装配下最大**完整包络**。本节没有测量炮台所有合法朝向、护盾外缘、盾甲条/间距、最密编队的实际组合包络，也没有测量其与画面边界、HUD、相邻敌舰及敌我间的最小净空。

现行普通框和分级 display_size 只进入舰体适配，代码的尺寸计算没有把两条盾甲条加入该框；因此不能据此认定盾甲条已计入占位。可见面积、完整包络与最小净空尚未测量，V1/G9 及整体画面品质仍待验收。

### 8.7 装备机库预览的展示层候选与战斗尺度分离

用户后续明确要求基础预览较小、五档有体量递进、最大舰安全占用；旧装备实现逐舰以manifest.height适配350px，导致五档近似等高，不能继续作为目标。当前装备内部候选固定 `8cd81a3f930f28bd362b8e14e5cf60d50c32b41b`，只改 `equipment_panel.gd`；此处记录展示候选，不改变或新批准8.2战斗参数、几何或接触尺度。

初始化只读现有公开 `Battle.mount_inputs(ship_key)` 的dimensions和art.texture，用正式战斗PNG alpha高/画布高把该输出还原为参考轮廓高R；没有读取Battle私有缓存、重复B×G×P业务公式或修改参数。以最大参考轮廓为统一归一基准，装备目标高 `P=320×R/max(R)`。再用**实际UI PNG alpha边界**反推768画布变换，而非把manifest.height当实际屏幕高；五舰可见边界中心均固定在装备本地(404,387)。

| 舰型 | 公开输出还原参考高R | UI实际alpha高（源px） | 本候选预览高P（装备px） |
|---|---:|---:|---:|
| Frigate | 133.042 | 290 | 145.905 |
| Destroyer | 151.470 | 389 | 166.115 |
| Cruiser | 213.792 | 502 | 234.463 |
| Battleship | 242.216 | 524 | 265.635 |
| Heavy_Battleship | 291.788 | 587 | 320.000 |

320px是本次装备展示候选的统一上限，不是战斗参数或已批准最小/最大值。每舰画布变换用于其正式UI manifest点；已有炮图比例也乘该舰同一装配变换，PNG锚点与选中可见框共用同因子。代码中350只换算旧炮图的显示标定，不再是逐舰目标fit；不修改原炮PNG/真炮口/native位置。原防御代理仅随已有装配变换，不把UI标记冒充原生武器点，新整舰反馈仍未实施。

同版[五档同机位原图、参考输出和当前装配包络](../../verification/equipment-hangar-godot/integrated-presentation/README.md)核对固定视口1440×900/左808×900。最大当前静态组合包络核在本地(224,158,560,446)安全区内；这是本次五个指定合法配装、静态朝向及当前选中徽标的呈现核对，不是全合法组合/全朝向扫掠、战斗净空或完整V1通过。下方共同收紧为280px区域，不能用350等高或原252px单台高度锁死比例；审查仍以M2及本次实际画面为准。
