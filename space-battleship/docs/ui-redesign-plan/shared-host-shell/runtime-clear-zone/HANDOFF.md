# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `47e385ee`（公共承载ee0e2ff1），未合main。
- 星球来源 `415d3bbdf`：facilities_v9四GLB、planet_facility_scene.gd、planet_orbital_spine.gd六件接入并同blob。planet_visual保留公共固态整组宽度包络，planet_panel保留关闭/展开安全区及e7591438的业务/UI修复。
- 反应堆当前已接入 `b9afb41cd34e43372f83f438716a234b3a93edbf`（交接c18480e9）的十四件installation闭包，逐blob同源。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

## 星球当前批准稿与下一项

制作依据：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录 `planet-ring.png`（SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`）。用户已批准按此图接入游戏，原星球组制作中。

当前目标是按批准图还原大直径、细窄环体、四设施的体量比例，以及建筑与环之间的承托和管线接合细节；原组可尝试环轨电车。公共组保留当前运行现场、主体安全区和业务/UI修复，待新资产固定后继续同壳整页适配，核总览与不同详情台高度下的比例、遮挡、留白和正常动态。不等待旧实机评价，不在当前旧资产上追加美术迭代。

当前运行仍为星球 `415d3bbdf` / 公共接入 `6d8a4dd9`。其证据保存在独立归档 `archive/design-docs-before-cleanup-20261031@88c4f81d:modules/public-ui/planet-v31-front-detail-shared-20261101/README.md`；新批准稿尚未作为运行资产接入。

本线程已从 `archive/planet-resume-20261101@78b604c9:approved-design-20261101-thin-orbit/parts/README.md` 的四片无损重组原PNG，2358640字节且完整SHA256一致，并亲看1536×1024全图。画面以大直径细椭圆轨道围绕星体，四设施通过承托接头/管线形成清晰功能轮廓，环与星体间负空间宽阔。后续把完整轨道、设施及运动包络整组适配主体安全区，保留图中球环比例、设施体量和开放/封闭空间关系，再与公共操作台整页核对。

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
3. 星球原组按032b2f18批准稿制作中；保留当前6d8a4dd9现场，待新资产固定后继续同壳整页与正常动态适配。
4. 目标机性能仍缺同构建、同战场显示/关闭基线，不用软件环境观察替代，不新增无关复测或合main。
