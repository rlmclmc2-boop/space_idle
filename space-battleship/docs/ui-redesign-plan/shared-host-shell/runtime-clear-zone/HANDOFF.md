# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `ee0e2ff1`，未合main。
- 星球来源 `415d3bbdf`：facilities_v9四GLB、planet_facility_scene.gd、planet_orbital_spine.gd六件接入并同blob。planet_visual保留公共固态整组宽度包络，planet_panel保留关闭/展开安全区及e7591438的业务/UI修复。
- 反应堆当前已接入 `c74b5d39`（交接76a03605）的十三件installation闭包，逐blob同源。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

## 星球当前批准稿与下一项

制作依据：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录 `planet-ring.png`（SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`）。用户已批准按此图接入游戏，原星球组制作中。

当前目标是按批准图还原大直径、细窄环体、四设施的体量比例，以及建筑与环之间的承托和管线接合细节；原组可尝试环轨电车。公共组保留当前运行现场、主体安全区和业务/UI修复，待新资产固定后继续同壳整页适配，核总览与不同详情台高度下的比例、遮挡、留白和正常动态。不等待旧实机评价，不在当前旧资产上追加美术迭代。

当前运行仍为星球 `415d3bbdf` / 公共接入 `6d8a4dd9`。其证据保存在独立归档 `archive/design-docs-before-cleanup-20261031@88c4f81d:modules/public-ui/planet-v31-front-detail-shared-20261101/README.md`；新批准稿尚未作为运行资产接入。

本线程已核批准稿文字入口；图片blob读取受工具二进制解码限制，尚未完成该图片的本地视觉核对。新资产到位时须连同批准原图读取并对照，不能以文字目标代替图稿。

## 反应堆当前制作与公共接续

反应堆由原组按获准1586×992共同图整体制作中，不等用户。当前运行基线c74b5d39/bf9c52ba仅保留功能与接入现场，不作为可确认外观。当前目标是图中的厚机壳、嵌入舱室、实体粗管、体积能量和共同受光；公共层遵循同一实体承载关系，不能以配色/不越框代替整页效果。

公共承载适配已固定ee0e2ff1：资源栏替换为单一完整承载梁，移除独立标题牌控件和title-plaque.svg，导航面按完整竖脊排布。保持模块x0..808、顶栏y0..65、导航x808..855.875和原战斗投影。装备原有y65..85空白接续保留；模块组拥有y65以下舱室/台体，公共组不在内部叠新框。新舱室上边/右边应以真实结构面和接触阴影接到公共梁体，光源与共同图一致；下方控制台自身的厚度/侧壁由原反应堆组连同主体完成。

公共同源证据：`archive/design-docs-before-cleanup-20261031@33ace275:modules/public-ui/structural-carrier-20261101/README.md`。八张1440×900原屏/同尺寸JPEG，两方向原生鼠标hover→按住→释放共2.4秒72连续帧、哈希、驱动及完整作者判断。长余额1.2e22/999.9kt可读；当前所看文字/图标和释放后的路由对应。当前是公共适配候选，须与反应堆新成套舱室复看，不作为整体还原/通过。

原组可精确消费的公共差异为 `src/ui/zone_shell.gd` 及 `assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均位于space-battleship）；移除旧title-plaque.svg。BridgeTheme API、main、Owner、模块内部和战斗投影未改。造型依据与承托要求在13§2.1“共同图形依据”，不是另立风格规范。

## 独立剩余项

1. 公共适配ee0e2ff1已完成本轮实机检查和固定交接，供原反应堆组接续新舱室；当前无新增明确公共控件缺陷，不以本轮有限状态宣称全局通过。
2. 反应堆原组按共同原图整体制作中，固定新源后继续同壳接入，按台体/舱室/管路/能量体积及受光完整重看，不等用户、不用当前基线代替。
3. 星球原组按032b2f18批准稿制作中；保留当前6d8a4dd9现场，待新资产固定后继续同壳整页与正常动态适配。
4. 目标机性能仍缺同构建、同战场显示/关闭基线，不用软件环境观察替代，不新增无关复测或合main。
