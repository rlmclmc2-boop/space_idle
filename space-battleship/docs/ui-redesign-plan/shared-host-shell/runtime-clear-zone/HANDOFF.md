# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。本人直接执行，不使用子智能体。

## 当前版本与同源证据

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `47ce2422`，未合main。
- 反应堆 `cdd8b494b96929c2c965f2284519d294ebf3d13a` 二十件installation闭包逐blob同源，含Scene/Stage、私有GLB/layout、common include、独立体积shader/PNG/JSON和制作脚本。源交接10bf227d，安装为 `archive/reactor-material-refinement-20261101@37d9eb92:modules/reactor/lined-outlet-20261101/installation.json`。仅八件生产文件发生变化，未整树覆盖公共壳或Owner。

- 星球固定 `be3a2b93fc56cd6d4793e00b92c35cbffc4f6cdc` 的四GLB、设施场景/轨道、rotating/spine_opaque两个shader及cloud-density云图及两张远景贴图十一件逐blob同源。planet_visual保留整组包络与固定环境；planet_panel业务/UI与安全区保持。
- 本轮仅equipment/shipyard两GLB、planet_facility_scene与planet_spine_opaque四文件更新，船坞/制造主甲和冷侧壳材质分区进入原生资产。planet_visual保持c0f19517b，nebula曝光shader保持fa502483；反应堆二十件完整闭包、公共壳/导航、Owner和最终装备保持。
- 固定环境内sky乘色0.52/0.62/0.76、气体透明度0.32/上部退后0.80、原柔光0.32。后续nebula更新继续保留uniform与宿主参数。小天体使用subject的orbit_back_layer，随详情台主体重排缩放，气体层连续固定。

星球当前同版证据：`archive/design-docs-before-cleanup-20261031@7e30df6ee26183c4bcb0d61c72ab70281195fa78:modules/public-ui/planet-v60-shared-20261101/README.md`。五张1440×900原PNG/同尺寸JPEG、总览/设施各6秒180帧动画、无损分片/哈希、半秒整页抽帧、保存的近侧序列、前设施1:1前后对照及批准图等球径并置。source.json记录十一件原组同源文件与公共/业务保留文件。before两图来自0522已有原PNG。

反应堆当前同版证据：`archive/design-docs-before-cleanup-20261031@8c453834c16c0dff22aa694b8e3b3855db97e025:modules/public-ui/reactor-lined-outlet-shared-20261101/README.md`。运行b3918fa5的七张1440×900原PNG/同尺寸JPEG：四路/单炼铁/两路零载及均分带载、返回装备；四路/单路各6秒180帧1×真实Session时钟影片、无损分片/哈希、半秒整页抽帧及保存逐帧总览、批准图整页并置与前版原像素受光并置。作者看七整页、批准图和两片每半秒抽帧；两路只覆盖静态/实际鼠标均分，无同版连续动态。模块数/钱包及少路Owner参数与接纳发布器受控；未加购级/MAX或性能复测。导入/运行无脚本或shader错误。

星球证据对应47ce2422，作者亲看五完整页、批准图、前设施1:1对照与两片0–5.5秒每半秒抽帧；保存的未查看序列不计入亲看覆盖。反应堆证据仍对应b3918fa5，本轮二十件闭包逐blob保持，不将其影片标为47ce重录。MovieMaker离线30fps不作实时性能结论。

## 当前整页判断与接续

### 反应堆

制作依据为获准1586×992共同图：`24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png`。当前已接分件/六类材质/核心局部反光源；原组仍继续整体还原，不等用户。

本轮核心内环/夹具冷反射、盾场套环前后明暗和炉口/池沿暖色进入实际整页；池壁开口、厚U槽和耐火内衬承托排出液流，零态保留槽而工作光关闭。四路/单路/两路的主体/操作台边界保持，均分/百分比/等级与数量升级未见新贴边或越槽。

按批准图仍非完整还原：舱壁/地面大片平直面和硬黑影较抢，近台与远墙的中尺度进深/受光关系弱；核心外壳/夹具偏均匀青白亮，腔内亮瓣与环境联系仍硬。流体偏圆柱/圆摊，液面温差与槽壁反光简单；盾面/后机体、武器青条/晶体柱层次偏简。宽面反射、管件套筒遮挡和近台实体侧厚仍欠图稿完成度。公共布局不需叠新盖板或改战场来补。

原组已继续舱壁中尺度退台/接缝、近地面板与远近受光；本组消费后续固定源再整体看。具体本版判断见author-review.md。当前不交成品确认、不等用户，无本轮目标硬件同条件显示/关闭性能数据。

### 星球

唯一批准稿：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录planet-ring.png，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。

开放泊位、两端服务舱、单主吊架与纵轨的构图保持，固定环境y65..900、主体min(高×0.21,宽×0.135)整组包络及源光学中心不变；不同高度底台下未见新碰状态条、压台或越导航。当前无需新增公共几何修正。

本轮公共背景上方与四周亮蓝气带退后，总览与三种展开高度下地表/设施先于云层成为视线焦点；下角弱气带保留连续环境变化。固定背景未跟随主体缩放重置，主次较清楚，右侧战场层次保持。没有通过遮缝层或改变建筑大小来解决背景。

公共气带、主体安全区和操作关系保持，工作位暖色没有抢星体。船坞暖顶甲/冷下壳、制造区亮顶甲/冷侧壳/暗腔在1:1对照中可读，总览中也能辨出主甲与承力下层，可保留这个材质分区方向；不要求继续增加不可见细纹。

完整还原仍欠体积与光影关系：厚门架/舱口内壁和接轨护肩包覆较直方平面，暖工位对内侧墙、门架和邻近台面的受光联系简单；停靠船/甲板/服务舱层次仍简化。上方窗舱、穹顶承托和端口遮挡少于原图，远景岩石密度/气体空间丰富度未齐。原组按大尺度形体与材料/受光继续，不以改完指定点判整页通过。当前不交成品确认、不等用户，完整判断见author-review.md。

## 公共接入边界与下一步

公共资源栏为单一完整承载梁，导航为完整竖脊；模块x0..808、顶栏y0..65、导航x808..855.875及原战斗投影保持。公共组不在y65以下叠框遮盖，模块的舱室/台体以真实侧面、端接和接触受光接到公共结构。装备现有y65..85接续及已完成操作结构保持。

可消费公共源ee0e2ff1：`src/ui/zone_shell.gd`，`assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均在space-battleship），删除旧title-plaque.svg。BridgeTheme API与Owner不改；设计要求归13，不在交接另立规范。

1. 星球be3a固定资产与主甲/冷侧壳分区闭包及同壳整页/动态交接完成；公共曝光/连续覆盖与主体适配保留。后续nebula素材/shader更新需合并公共uniform和曝光参数，不回到整页高亮。
2. 反应堆原组继续舱壁退台/接缝、近地面板、远近受光及设备/流体材料完成度；固定更新后精确消费并重看公共整页。
3. 星球原组继续前设施内件、局部光聚焦与面板材质，固定更新后按批准图复看完整页面。
4. 目标机性能依赖单列，当前无同条件目标环境基线，不用离线记录或软件观察替代，不新增无关复测或合main。
