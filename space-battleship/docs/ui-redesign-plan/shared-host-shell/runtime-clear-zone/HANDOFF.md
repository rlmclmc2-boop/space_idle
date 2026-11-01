# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。本人直接执行，不使用子智能体。

## 当前现场

工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，当前运行源 `540e38a8`，未合main。公共承载ee0e2ff1、主题9034af81、最终装备main e845保持；不整树覆盖Owner/公共壳/其他模块。

反应堆固定 `3e0240c9ce65780ac4666ee6367a5c70cdc6586d`，二十件installation闭包逐blob同源，含GLB/layout、Scene/Stage、全部shader/include、体积PNG/JSON及制作脚本。installation为 `archive/reactor-material-refinement-20261101@72c9f5fa:modules/reactor/continuous-bay-20261101/installation.json`，原组交接9954bd81。本轮五件生产文件变化，连续墙地、共同deck_level与刚性结构遮蔽进入运行；设备/端口/工作过程/操作分组保持。

星球固定 `4fd60ce37cdf50bad4fecae5ae4f3ef69efbadd3`，四GLB、设施场景/轨道、rotating/spine_opaque两个shader、cloud-density云图与两张小天体贴图十一件同源；planet_visual保留整组包络/小天体绘制与公共环境，nebula保留公共曝光。planet_panel业务/UI修复与安全区保持。

## 同源证据与覆盖

反应堆：`archive/design-docs-before-cleanup-20261031@a6a3cdef3635874d663e4296ed46023a6479bc57:modules/public-ui/reactor-continuous-bay-shared-20261101/README.md`。540e38a8的七张1440×900原PNG/同尺寸JPEG，四路/单炼铁/两路真零和均分带载、返回装备；四路/单路各6秒180帧、无损分片/哈希、半秒整页抽帧、批准图整页并置、author-review.md。作者亲看七整页、批准图与两片每半秒抽帧。实际鼠标均分/返回成功；模块数/钱包与少路Owner/接纳发布器受控。两路仅静态/输入，无同版连续片，未重开购买矩阵。导入/运行无脚本或shader错误。

星球：`archive/design-docs-before-cleanup-20261031@5b5624c714d56aef747eb3ff34280a666b9e74b6:modules/public-ui/planet-v61-shared-20261101/README.md`。9c34e6bc的五张1440×900完整页、总览/设施各6秒180帧动画、分片/哈希、半秒抽帧、原尺寸对照及批准稿等球径并置。作者看五整页、批准图、1:1对照及两片每半秒抽帧。受控星球1/探索240/四设施已建、固定业务快照/1×显示动画。本轮星球与公共文件逐blob保持，不将影片标成540e重录。

上述MovieMaker离线30fps不作实时性能。保存的未看序列不计入亲看覆盖，具体驱动/segment/source.json与作者范围同存。

## 当前整页判断与依赖

反应堆以获准共同图 `24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png` 为依据。连续舱壁/坡面地台和设备落座关系已改善，少路不再读成另一片背景地板；公共边界与台面净空保持。当前仍未成品：凝聚机上部仅薄领圈/开放空腔，投射件、种子座与工作腔的实体构成不足，带载紫晶偏裸柱；原组正继续。墙地宽面远近受光仍简、核心外环青白亮较均匀、炉流/盾面材料体积简化。具体差距见本版author-review.md，不据本轮墙地完成判整体通过，不等用户才接后续源。

星球批准稿为 `archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/planet-ring.png`，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。9c34同版完整页/动态已由父交用户，当前仅等相关视觉意见，未获接受/main授权。主次、连续护肩、暖入口和操作台关系已能完整评价；应明示前设施较方厚、停靠船简化及环境反射更克制，不宣称完全还原。微小织纹/铆钉不作为无限加细节门槛。这个依赖不停止反应堆制作/接入。

## 公共边界与下一步

模块x0..808、顶栏y0..65、导航x808..855.875、战斗投影保持；装备y65..85接续和已完成操作结构保持。公共组不在y65以下叠盖板遮缝。

环境用既有层连续覆盖y65..900；sky乘色0.52/0.62/0.76、气体透明度0.32/上部退后0.80、柔光0.32，nebula保持fa502483公共uniform。主体整组包络min(高×0.21,宽×0.135)，底台按安全区适配。小天体使用subject的orbit_back_layer随主体布局；气体环境固定。后续原组shader更新须合并公共适配，不整文件覆盖。

可消费公共源ee0e2ff1：`src/ui/zone_shell.gd`、`assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`，删除旧title-plaque.svg；BridgeTheme API和Owner不改，设计要求只归13。

下一项是原组凝聚机上部固定闭包到后精确接入并重看整页/动态。本版没有新增明确公共几何缺陷，不盲加样式微调。星球待当前视觉反馈，其他固定更新到后按原职责接续。目标机性能依赖单列：当前无同构建/同场景显示关闭基线，不用离线影片或软件观察替代，不新增无关复测或合main。
