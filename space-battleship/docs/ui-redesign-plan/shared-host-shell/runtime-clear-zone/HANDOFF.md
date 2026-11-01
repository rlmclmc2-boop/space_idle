# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。本人直接执行，不使用子智能体。

## 当前版本与同源证据

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `f553cb30`，未合main。
- 反应堆 `cfcc9a3552a886283ed07be656ff7247c8a498bf` 的十四件installation闭包逐blob同源，包含私有GLB、Stage、shader及metadata；Owner/原生控件不替换。源交接14f1e0bd；installation在 `archive/reactor-material-refinement-20261101@564cc030:modules/reactor/depth-light-20261101/installation.json`。
- 星球 `c063e710ef93fa4ea84306b9fa620128e93112b2` 的四GLB、设施场景/轨道、nebula/rotating/spine_opaque三个shader及cloud-density云图十件逐blob同源。planet_visual保留整组包络与独立环境矩形，planet_panel保留主体安全区及业务/UI修复。
- 本轮仅6件星球生产文件变化：四GLB、planet_facility_scene与nebula，包含分层装甲、曲面蜂巢、上方压力护套及气体颗粒。反应堆十四件闭包、公共背景/主体适配、公共承载ee0e2ff1、主题9034af81、最终装备main e845、main/Owner、导航及战斗空间保持。

星球当前同版证据：`archive/design-docs-before-cleanup-20261031@d0a8b8d67a8ce260b2920ec23a420499c46d8c24:modules/public-ui/planet-pressure-couplers-shared-20261101/README.md`。运行f553cb30的五张1440×900原PNG/同尺寸高质量JPEG、总览/设施展开两段各6秒180连续帧、无损分片/哈希、逐帧总览、批准图等球径及1:1像素对照、全时段半秒抽帧、2..3秒近侧及上方两节点连续原像素序列、author-review.md。

反应堆当前同版证据：`archive/design-docs-before-cleanup-20261031@4d4ec6cddc516b034a025ef179da840346ead3f8:modules/public-ui/reactor-depth-light-shared-20261101/README.md`。运行774deace的五张1440×900原PNG/同尺寸高质量JPEG、四路/单炼铁各6秒180连续帧、无损分片/哈希、逐帧总览、批准整图共同屏幕比例并置及author-review.md。

本轮星球导入/运行成功，作者亲看五完整页、两片每0.5秒抽帧、各2.00–2.97秒的30帧原像素近侧序列及总览同段上方节点序列、原尺寸对照及批准图；受控星球1/探索240/四设施已建，固定业务快照、1×显示动画。反应堆证据对应774deace，当前十四件闭包/公共文件保持，不把其影片标成f553重录；其覆盖为受控四路/单炼铁Owner参数、实际鼠标均分/返回装备和1×真实Session时钟。两者均MovieMaker离线30fps，具体版本/覆盖见驱动和segment，不作实时性能或此前点击瞬间覆盖。本轮未追加性能或未改购买状态复测。

## 当前整页判断与接续

### 反应堆

制作依据为获准1586×992共同图：`24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png`。当前已接分件/六类材质/核心局部反光源；原组仍继续整体还原，不等用户。

本轮百分比共用轨内右端，单路100%与零载/四路锚点一致，滑块不挤读数；均分与数量/升级保持台面内，公共梁/导航未见新增相交或截字。壁板返回、顶凹井、核心后承托与真实点光进入整页。

按批准整图，当前仍是制作检查点：墙面偏均匀亮灰蓝，直线/黑轮廓抢眼，舱室远近/暗腔未充分退到设备后面；武器侧护壳、盾后机体的中尺度分件及厚壳受光不足，管道圆截面和套筒遮挡仍弱。核心有汇入/缩紧/释放、管内亮头尾可读，但主体仍多为光滑椭圆场与细线约束单元，层叠能量深度及周边反光少于原图。圆润炉流、盾面与晶体腔也需继续材质/体积层次。单路主体/短台和大墙面/台下留空的重心仍需原组整体校准，不能以本轮指定点完成判整页还原。

具体接续见本版author-review.md：保留核心焦点和固定读数成果，原组继续护壳分件、舱室远近明暗及局部冷暖受光。没有需要宿主叠框或改战斗空间来补的公共几何问题，不交用户作成品确认，不等用户。本版无新FPS测量，目标机同构建/同场景显示关闭基线仍缺，离线采集不能判性能通过。

### 星球

唯一批准稿：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录planet-ring.png，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。

开放泊位、两端服务舱、单主吊架与纵轨的构图保持，固定环境y65..900、主体min(高×0.21,宽×0.135)整组包络及源光学中心不变；不同高度底台下未见新碰状态条、压台或越导航。当前无需新增公共几何修正。

当前穹顶蜂巢、端口分层护套和近侧装甲边均在实际尺寸可辨；所看上方连续序列中蜂巢保持可读、未见大块跳变，浅船翼点状自阴影未重新出现。背景颗粒和亮点增加，云面内部变化可见。这些改善不构成整体还原通过。

按批准图完整品质仍未完成：护套更像醒目的外露白环/短筒，厚侧壁、内层结构和接触阴影不足以解释包覆/承力；穹顶与下部窗舱/承力体的受光和嵌合仍简化。前设施依旧偏大浅面/重复方块，船壳、泊位内壁、制造井的机械与材质层次不足，黄梁/浅前壁较抢。背景虽有细颗粒，仍以宽亮云团和较均匀细噪为主，未还原图稿深黑空间中的细气体丝、光团/小天体与远近关系。原组继续护套承力受光、前设施机械/材料完成度及背景纵深，不以更多细线/白边/噪点代替。当前不是成品确认稿，无待用户验收状态；完整判断和观看范围见本版author-review.md。

## 公共接入边界与下一步

公共资源栏为单一完整承载梁，导航为完整竖脊；模块x0..808、顶栏y0..65、导航x808..855.875及原战斗投影保持。公共组不在y65以下叠框遮盖，模块的舱室/台体以真实侧面、端接和接触受光接到公共结构。装备现有y65..85接续及已完成操作结构保持。

可消费公共源ee0e2ff1：`src/ui/zone_shell.gd`，`assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均在space-battleship），删除旧title-plaque.svg。BridgeTheme API与Owner不改；设计要求归13，不在交接另立规范。

1. 本轮闭包接入、必要运行整页/动态与固定交接已完成；当前无新增明确公共几何缺陷，不以此宣称整体美术通过。
2. 反应堆原组继续武器侧护壳/盾后机体分件、舱室远近明暗、局部受光及单路重心；固定更新后精确消费并重看公共整页。
3. 星球原组继续前设施内件、局部光聚焦与面板材质，固定更新后按批准图复看完整页面。
4. 目标机性能依赖单列，当前无同条件目标环境基线，不用离线记录或软件观察替代，不新增无关复测或合main。
