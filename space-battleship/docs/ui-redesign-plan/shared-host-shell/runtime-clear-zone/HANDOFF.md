# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。本人直接执行，不使用子智能体。

## 当前版本与同源证据

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `42b3e7e1`，未合main。
- 反应堆 `b23d87dad9d1ec2ab570ed824d60774f7066c243` 二十件installation闭包逐blob同源，含Scene/Stage、私有GLB/layout、common include、独立体积shader/PNG/JSON和制作脚本。源交接bd262e8c，安装为 `archive/reactor-material-refinement-20261101@1f856108:modules/reactor/formed-housings-20261101/installation.json`。仅十二件生产文件发生变化，未整树覆盖公共壳或Owner。

- 星球固定 `48bf5ba8af156516454a14479e0955cc87d292b8` 的四GLB、设施场景/轨道、rotating/spine_opaque两个shader及cloud-density云图及两张远景贴图十一件逐blob同源。planet_visual保留整组包络与固定环境；planet_panel业务/UI与安全区保持。
- 本轮仅四GLB与planet_facility_scene五文件更新，含工作床/门架定向照明、节点服务灯和实心星球主光收敛。planet_visual与上一固定宿主c0f19517b逐blob保持，nebula曝光shader保持fa502483；反应堆二十件完整闭包、公共壳/导航、Owner和已完成装备保持。
- 固定环境内sky乘色0.52/0.62/0.76、气体透明度0.32/上部退后0.80、原柔光0.32。后续nebula更新继续保留uniform与宿主参数。小天体使用subject的orbit_back_layer，随详情台主体重排缩放，气体层连续固定。

星球当前同版证据：`archive/design-docs-before-cleanup-20261031@573bce7ef2697486d2ef15766f462b13e2b524bf:modules/public-ui/planet-v57-shared-20261101/README.md`。五张1440×900原PNG/同尺寸JPEG、总览/设施各6秒180帧动画、无损分片与哈希、半秒整页抽帧、前设施1:1前后对照及批准图等球径并置。source.json记录十一件原组同源文件与公共/业务保留文件，author-review.md记录本版整页判断。before两图来自c0f1已有原PNG。

反应堆当前同版证据：`archive/design-docs-before-cleanup-20261031@b0b306c29dfed6e88b6becc7c3aebd3e4d469be4:modules/public-ui/reactor-formed-housings-shared-20261101/README.md`。运行38f5d8b3的七张1440×900原PNG/同尺寸JPEG：四路/单炼铁/两路零载及均分带载、返回装备；四路/单路各6秒180帧1×真实Session时钟影片、无损分片/哈希、半秒整页抽帧与保存逐帧总览、批准图整页并置。作者看七整页、批准图和两片每半秒抽帧；两路只覆盖静态与实际鼠标均分，无同版连续动态。模块数/钱包与单/两路Owner参数受控；未加购级/MAX或性能复测。导入/运行无脚本或shader错误。

星球证据对应42b3e7e1，作者亲看五完整页、批准图、前设施1:1对照和两片0–5.5秒每半秒整页抽帧。反应堆证据仍对应38f5d8b3，本轮二十件闭包逐blob保持，不将其影片标为42b3重录。MovieMaker离线30fps不作实时性能结论。

## 当前整页判断与接续

### 反应堆

制作依据为获准1586×992共同图：`24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png`。当前已接分件/六类材质/核心局部反光源；原组仍继续整体还原，不等用户。

当前实体护壳、出射嘴、盾场分瓣压力机体、炉体/晶腔厚领圈比简化块体明确；单路总成与短台保持一组，双左路核心/机体/管道共移后构图更集中。四路/单路/两路的均分、百分比、等级费用与数量/升级在台面内，未见新增跨导航或越槽。

按批准整图仍未完整还原：舱室重复直梁、平壁和硬黑影较抢，暗凹舱/远近回壁弱；护壳依靠均匀浅面+黑边塑形，宽面反射和局部冷暖少；管件圆截面/套筒遮挡不足。核心体积会变化，但亮青白团集中，周边内壁/装甲受光没有同步建立；炉流偏圆柱/圆摊，炉口池沿导槽暖反射弱。盾面、武器青条和紫晶仍较符号化。下台分组/净空可保留，实体厚台与环境联系仍比原图简化。

原组继续环境受光和材料完成度，具体本版整页观察见author-review.md。本组保留共同公共语言与现有业务，不给已完成装备另叠皮肤来迁就当前反应堆。当前不交成品确认，不等用户。无本轮目标硬件同条件显示/关闭性能数据，离线录像不判性能通过。

### 星球

唯一批准稿：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录planet-ring.png，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。

开放泊位、两端服务舱、单主吊架与纵轨的构图保持，固定环境y65..900、主体min(高×0.21,宽×0.135)整组包络及源光学中心不变；不同高度底台下未见新碰状态条、压台或越导航。当前无需新增公共几何修正。

本轮公共背景上方与四周亮蓝气带退后，总览与三种展开高度下地表/设施先于云层成为视线焦点；下角弱气带保留连续环境变化。固定背景未跟随主体缩放重置，主次较清楚，右侧战场层次保持。没有通过遮缝层或改变建筑大小来解决背景。

本轮制造作业面、船坞入口暖光与上方服务灯在实际尺寸可见，白壳/暗腔分离比上一版清楚；三种详情台高度下主体、顶部状态和底台关系保持，公共气带继续低于主体。所看半秒相位未见新增大块亮斑跳变。

按批准图仍非完整还原稿：制造区暖光偏小块橙黄面，厚门架/内壁和邻近装甲受光联系弱；船坞压力门架仍方整，开口深度和停靠船/服务舱层次简化；上方窗舱、穹顶承托及接轨包覆仍欠厚度和材料反射。岩石远近密度/细气丝也未充分还原。当前原组继续这些可见差距，不交成品确认、不等用户；具体判断见author-review.md。公共组无须叠新底板或改战场解决当前几何关系。

## 公共接入边界与下一步

公共资源栏为单一完整承载梁，导航为完整竖脊；模块x0..808、顶栏y0..65、导航x808..855.875及原战斗投影保持。公共组不在y65以下叠框遮盖，模块的舱室/台体以真实侧面、端接和接触受光接到公共结构。装备现有y65..85接续及已完成操作结构保持。

可消费公共源ee0e2ff1：`src/ui/zone_shell.gd`，`assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均在space-battleship），删除旧title-plaque.svg。BridgeTheme API与Owner不改；设计要求归13，不在交接另立规范。

1. 星球48bf固定资产与工作照明闭包及同壳整页/动态交接完成；公共曝光/连续覆盖与主体适配保留。后续nebula素材/shader更新需合并公共uniform和曝光参数，不回到整页高亮。
2. 反应堆原组继续炉口/池沿暖反射、盾场前后受光、核心环境联系与舱室远近明暗；固定更新后精确消费并重看公共整页。
3. 星球原组继续前设施内件、局部光聚焦与面板材质，固定更新后按批准图复看完整页面。
4. 目标机性能依赖单列，当前无同条件目标环境基线，不用离线记录或软件观察替代，不新增无关复测或合main。
