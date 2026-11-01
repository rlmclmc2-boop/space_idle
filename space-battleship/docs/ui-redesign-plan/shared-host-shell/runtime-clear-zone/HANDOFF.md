# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `9d4a708f`（公共承载ee0e2ff1），未合main。
- 星球来源 `e222b2202e2d6ea8122e298d546a558d6f62c3cc`：facilities_v9四GLB、planet_facility_scene.gd/planet_orbital_spine.gd及nebula/rotating两个shader八件同blob；planet_visual保留公共整组包络并分开环境矩形，planet_panel保持主体安全区和e7591438业务/UI修复。
- 反应堆当前已接入 `b9afb41cd34e43372f83f438716a234b3a93edbf`（交接c18480e9）的十四件installation闭包，逐blob同源。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

## 星球当前批准稿与下一项

制作依据：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录 `planet-ring.png`（SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`）。用户已批准按此图接入游戏，原星球组制作中。

当前按批准图还原大直径细环、四设施体量与接合细节。e222b220为低宽前设施与分件电车中间版，原组继续完整资产和材质，不等用户。

同壳9d4a708f精确接入四GLB/轨道脚本五件变化，继承c666的固定环境y65..900、主体min(高×0.21,宽×0.135)包络和源稿光学中心。planet_visual/planet_panel、公共控件及业务/UI修复未改；反应堆保持b9。背景与主体的最小接续仍为planet_visual::set_environment_rect/_layout_environment和planet_panel::_fit_drawer；setter在矩形未变时直接返回，无遮盖层。

当前证据：`archive/design-docs-before-cleanup-20261031@cb9453d4bc80d55e30a7ea8df957524a1b4a56ff:modules/public-ui/planet-front-mass-shared-20261101/README.md`。五张1440×900原PNG/同尺寸JPEG、约等球径对照，总览和设施展开各6秒180连续帧及分片/哈希；source.json核同源与保留闭包。受控星球1/探索240/四设施已建，业务快照固定、显示动画1×，MovieMaker离线30fps，不作性能结论。

作者亲看完整页、全部360帧总览/代表帧及批准图等尺度对照。低宽前设施和开放机器床/泊位有实质变化，当前公共边界/背景/详情台关系未新增裁切；总览前弧可辨带窗车舱，远弧与详情展开后车辆身份仍弱。前设施大白面、重复块件、开口/窗带和受光层次，以及球面/星云层次仍与批准图有明显差距。完整当前判断见author-review.md。本版不交用户确认，继续消费原组固定新源，当前无需额外公共几何修改。

## 反应堆当前制作与公共接续

反应堆由原组按获准1586×992共同图整体制作中。当前47e385ee是体块中间版同壳接入，不作为完整确认稿。原组继续设备分件、材质反射与核心受光。

本轮同源证据：`archive/design-docs-before-cleanup-20261031@e73578cdc563e6be122c54534b881493540f811d:modules/public-ui/reactor-spatial-shared-20261101/README.md`。五张1440×900原PNG/同尺寸JPEG，四路与单路零载/带载、装备返回；两段各6秒180连续帧的真实Session1×工作片段及无损分片/哈希。模块数/钱包受控，单路使用Reactor Owner参数；原生鼠标均分和回装备实际执行。MovieMaker固定30fps离线采集，不作性能结论，不把工作片段冒充点击瞬间覆盖。

整页作者判断与原组具体接续在同目录author-review.md：公共梁/导航和模块边界未见新增相交，核心基座/设备座的承托更明确；但深舱透视、设备厚壳与内腔受光、粗管圆截面、核心能量体积仍未尽可能还原原图，与当前装备机库的材质完成度仍有明显差距。单路主体/短台与留空需整体校准，100%在滑轨左端而零载/四路在右端的读数锚点差异需原组修正。公共层保持原有完整承载，不向模块内叠遮盖框；新材质和主体固定后继续同壳整页判断，不等用户。

公共承载适配已固定ee0e2ff1：资源栏替换为单一完整承载梁，移除独立标题牌控件和title-plaque.svg，导航面按完整竖脊排布。保持模块x0..808、顶栏y0..65、导航x808..855.875和原战斗投影。装备原有y65..85空白接续保留；模块组拥有y65以下舱室/台体，公共组不在内部叠新框。新舱室上边/右边应以真实结构面和接触阴影接到公共梁体，光源与共同图一致；下方控制台自身的厚度/侧壁由原反应堆组连同主体完成。

公共同源证据：`archive/design-docs-before-cleanup-20261031@33ace275:modules/public-ui/structural-carrier-20261101/README.md`。八张1440×900原屏/同尺寸JPEG，两方向原生鼠标hover→按住→释放共2.4秒72连续帧、哈希、驱动及完整作者判断。长余额1.2e22/999.9kt可读；当前所看文字/图标和释放后的路由对应。当前是公共适配候选，须与反应堆新成套舱室复看，不作为整体还原/通过。

原组可精确消费的公共差异为 `src/ui/zone_shell.gd` 及 `assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均位于space-battleship）；移除旧title-plaque.svg。BridgeTheme API、main、Owner、模块内部和战斗投影未改。造型依据与承托要求在13§2.1“共同图形依据”，不是另立风格规范。

## 独立剩余项

1. 公共适配ee0e2ff1已完成本轮实机检查和固定交接，供原反应堆组接续新舱室；当前无新增明确公共控件缺陷，不以本轮有限状态宣称全局通过。
2. 反应堆b9体块中间版已接入并交当前整页差距；原组继续设备分件/材质反射/核心光及单路布局，固定新源后继续同壳整页还原判断。
3. 星球e222低宽设施/电车版已精确接入并固定整页/动态；公共环境与主体适配保持，原组继续完整资产/材质与球面/背景，后续同壳整页重看，不交中间稿验收。
4. 目标机性能仍缺同构建、同战场显示/关闭基线，不用软件环境观察替代，不新增无关复测或合main。
