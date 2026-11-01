# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。本人直接执行，不使用子智能体。

## 当前版本与同源证据

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `fa502483`，未合main。
- 反应堆 `cfcc9a3552a886283ed07be656ff7247c8a498bf` 的十四件installation闭包逐blob同源，包含私有GLB、Stage、shader及metadata；Owner/原生控件不替换。源交接14f1e0bd；installation在 `archive/reactor-material-refinement-20261101@564cc030:modules/reactor/depth-light-20261101/installation.json`。
- 星球固定 `c063e710ef93fa4ea84306b9fa620128e93112b2` 的四GLB、设施场景/轨道、rotating/spine_opaque两个shader及cloud-density云图九件逐blob同源。planet_visual保留整组包络与固定环境；planet_panel业务/UI与安全区保持。
- 本轮公共适配仅planet_visual.gd与planet_nebula.gdshader：固定环境内sky乘色0.52/0.62/0.76、气体透明度0.32/上部退后权重0.80、原柔光透明度0.32；其他环境保持默认。后续原组shader更新须保留两个uniform默认值与宿主参数，不整文件覆盖公共适配。无新控件/遮盖层，建筑体量和战场未改。

星球当前同版证据：`archive/design-docs-before-cleanup-20261031@4db20c86edc9652ba06062dbb59a99ab7077ab9d:modules/public-ui/planet-field-composition-20261101/README.md`。五张1440×900原PNG/同尺寸JPEG、总览/设施各6秒180帧动画、无损分片与哈希、半秒整页抽帧、保存的逐帧总览及author-review.md；before两图由f553已有同状态原PNG转换，未重跑。精确两文件差异见host-environment.patch。

反应堆当前同版证据：`archive/design-docs-before-cleanup-20261031@4d4ec6cddc516b034a025ef179da840346ead3f8:modules/public-ui/reactor-depth-light-shared-20261101/README.md`。运行774deace的五张1440×900原PNG/同尺寸高质量JPEG、四路/单炼铁各6秒180连续帧、无损分片/哈希、逐帧总览、批准整图共同屏幕比例并置及author-review.md。

本轮星球导入/运行无ERROR。作者亲看五完整页及两片0–5.5秒每半秒整页抽帧；受控星球1/探索240/四设施已建、固定业务快照、1×显示动画。反应堆证据仍对应774deace，十四件闭包保持。MovieMaker离线30fps不作实时性能；本轮未加性能或未改购买状态复测。

## 当前整页判断与接续

### 反应堆

制作依据为获准1586×992共同图：`24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png`。当前已接分件/六类材质/核心局部反光源；原组仍继续整体还原，不等用户。

本轮百分比共用轨内右端，单路100%与零载/四路锚点一致，滑块不挤读数；均分与数量/升级保持台面内，公共梁/导航未见新增相交或截字。壁板返回、顶凹井、核心后承托与真实点光进入整页。

按批准整图，当前仍是制作检查点：墙面偏均匀亮灰蓝，直线/黑轮廓抢眼，舱室远近/暗腔未充分退到设备后面；武器侧护壳、盾后机体的中尺度分件及厚壳受光不足，管道圆截面和套筒遮挡仍弱。核心有汇入/缩紧/释放、管内亮头尾可读，但主体仍多为光滑椭圆场与细线约束单元，层叠能量深度及周边反光少于原图。圆润炉流、盾面与晶体腔也需继续材质/体积层次。单路主体/短台和大墙面/台下留空的重心仍需原组整体校准，不能以本轮指定点完成判整页还原。

具体接续见本版author-review.md：保留核心焦点和固定读数成果，原组继续护壳分件、舱室远近明暗及局部冷暖受光。没有需要宿主叠框或改战斗空间来补的公共几何问题，不交用户作成品确认，不等用户。本版无新FPS测量，目标机同构建/同场景显示关闭基线仍缺，离线采集不能判性能通过。

### 星球

唯一批准稿：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录planet-ring.png，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。

开放泊位、两端服务舱、单主吊架与纵轨的构图保持，固定环境y65..900、主体min(高×0.21,宽×0.135)整组包络及源光学中心不变；不同高度底台下未见新碰状态条、压台或越导航。当前无需新增公共几何修正。

本轮公共背景上方与四周亮蓝气带退后，总览与三种展开高度下地表/设施先于云层成为视线焦点；下角弱气带保留连续环境变化。固定背景未跟随主体缩放重置，主次较清楚，右侧战场层次保持。没有通过遮缝层或改变建筑大小来解决背景。

按批准图，建筑整体品质仍未完成：压力护套更像外露白环，厚壁/内构与接触受光不足；穹顶与下层承托仍简化。前泊位、制造井多为浅方块，机械内件、材料反射和接触阴影弱，黄梁较抢。细气丝/小天体纵深也不能以本次曝光替代完整素材还原。原组继续设施材质和体积，当前不是成品确认稿，不等用户。

## 公共接入边界与下一步

公共资源栏为单一完整承载梁，导航为完整竖脊；模块x0..808、顶栏y0..65、导航x808..855.875及原战斗投影保持。公共组不在y65以下叠框遮盖，模块的舱室/台体以真实侧面、端接和接触受光接到公共结构。装备现有y65..85接续及已完成操作结构保持。

可消费公共源ee0e2ff1：`src/ui/zone_shell.gd`，`assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均在space-battleship），删除旧title-plaque.svg。BridgeTheme API与Owner不改；设计要求归13，不在交接另立规范。

1. 公共固定环境主次适配与同版整页/动态交接完成，待父亲看本版；没有因此新增独立微调或测试。后续星球shader固定更新需合并公共uniform和曝光参数。
2. 反应堆原组继续武器侧护壳/盾后机体分件、舱室远近明暗、局部受光及单路重心；固定更新后精确消费并重看公共整页。
3. 星球原组继续前设施内件、局部光聚焦与面板材质，固定更新后按批准图复看完整页面。
4. 目标机性能依赖单列，当前无同条件目标环境基线，不用离线记录或软件观察替代，不新增无关复测或合main。
