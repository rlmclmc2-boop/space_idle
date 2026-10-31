# AI 科技工厂首代静态资产

`scripts/ai_tech_factory_art.gd` 使用本目录的背景、八台透明设备和独立探针。背景铺满 1284×701 美术区；设备按脚本的 `MACHINE_BOUNDS` 等比放入舞台，抽屉图标放入 99×99 格。贴图按需加载，抽屉首次打开才创建图标。脚本只移动研究中的探针；隐藏页、覆盖抽屉与 `set_art_enabled(false)` 都停止动画。十级换代及代内改装仍只预留接口。

素材由内置 `image_gen` 生成。参考 `docs/ai-tech-tree-20261017` 分支的 `main-concept.jpg`、`selection-concept.jpg`，只沿用构图、卡通材质与覆盖抽屉方向。云端工具未能读取本地 JPEG 路径，故通过以下文字描述风格生成，不照抄图中的数字或连线。所有游戏数值来自页面快照。

## 生成提示词

背景：`Empty first-generation cartoon spacecraft workshop, three-quarter view. Broad central round assembly pedestal with a segmented teal light ring and clear EMPTY mounting area for a separate device layer. At left, a friendly articulated robot arm; at right, a small simple service robot. Wall panels and shallow side supply trays. Polished stylized 3D mobile game, chunky simplified beveled armor, matte ivory shells, slate blue structure, restrained amber seams, cyan emissive accents, coherent dark outline and gentle ambient shadows. No machine on pedestal, text, UI, progress bar, borders, watermark, ship, realistic metal or dense cables.`

八台设备共用：`One first-generation machine, centered full silhouette, three-quarter orthographic view from slightly above. Polished stylized 3D mobile game illustration, matte beveled ivory armor, blue metal structure, narrow amber work lights, restrained teal energy, strong dark silhouette outlines and coherent soft shading. True transparent background, clean alpha, generous margin. No platform, floor, environment, robot, text, label, number, logo, UI, ground shadow, watermark or other machines.`

| 文件 | 设备主体提示词与用途 |
|---|---|
| `ai-singularity-v2.png` | 方形 AI 核心；中央蓝绿色镜头、角部装甲、短铜针脚。 |
| `weapon-accuracy-v2.png` | 武器校准鼓；分层圆筒、环形传感器和短扫描头。 |
| `equipment-reinforcement-v2.png` | 双柱液压装甲压机；横梁、活塞和中央装甲板。 |
| `resource-refining-v2.png` | 竖式封闭熔炉；顶部料斗、熔炼观察窗和侧罐。 |
| `fragment-condensation-v2.png` | 封闭凝聚舱；双侧发射器，晶体只在内部透明窗中。 |
| `equipment-precision-v2.png` | 双机械臂精加工台；中央夹具、导轨与校准工具。 |
| `uranium-extraction-v2.png` | 封闭三分区离心提炼器；受保护的矿物观察窗与侧罐。 |
| `joint-integration-v2.png` | 双核心耦合基座；中央蓝绿色连接器与对称停靠架。 |

`inspection-probe-v2.png` 提示词：`One SMALL hovering inspection probe, compact ivory-and-slate-blue articulated tool head with a bright cyan downward-facing sensor lens and one warm amber status slot. Self-contained component moving gently over any larger machine during research. Three-quarter view, polished chunky cartoon 3D mobile-game style, true transparent alpha. No cable, larger robot, platform, floor, shadow, background, text or UI.`
