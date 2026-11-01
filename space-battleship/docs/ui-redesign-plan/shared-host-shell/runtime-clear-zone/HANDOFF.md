# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。本人直接执行，不使用子智能体。

## 当前版本与同源证据

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `41506983`，未合main。
- 反应堆 `0e5ce0067d5d5ffa7a31768e8bdd6835b468eebc` 的十四件installation闭包逐blob同源，包含私有GLB、Stage、shader及metadata；Owner/原生控件不替换。源交接df65d3d6；installation在 `archive/reactor-material-refinement-20261101@d3f1bdd3:modules/reactor/material-refinement-20261101/installation.json`。
- 星球 `8ccffa6d1d58ee31616c9a8796fe3bc48e120daf` 的四GLB、设施场景/轨道、两个shader及cloud-density云图九件逐blob同源。planet_visual保留整组包络与独立环境矩形，planet_panel保留主体安全区及业务/UI修复。
- 本轮仅7件星球生产文件变化：四GLB、设施局部光、星云shader及planet_visual星点；后者只合并源三处星点变化，保留固定环境/主体适配。反应堆十四件闭包保持。公共承载ee0e2ff1、主题9034af81、最终装备main e845、main/Owner、导航及战斗空间保持。

星球当前同版证据：`archive/design-docs-before-cleanup-20261031@9d43eabe2dd9de59b92dfc739f93851249074bc9:modules/public-ui/planet-open-berth-shared-20261101/README.md`。运行41506983的五张1440×900原PNG/同尺寸高质量JPEG、总览/设施展开两段各6秒180连续帧、无损分片/哈希、逐帧总览、批准图等球径对照及author-review.md。

反应堆当前闭包证据保持：`archive/design-docs-before-cleanup-20261031@577bf4557cb958217cd36968beb78f9116b0ddd3:modules/public-ui/reactor-material-planet-couplers-shared-20261101/reactor/author-review.md`，同目录为运行b43a3da6的五整页和两段6秒工作动态；本轮十四件反应堆闭包及公共文件逐blob保持，不把该旧运行号的视频标成415重录。

当前星球导入与运行成功。作者亲看五完整页、全部360帧总览和代表原尺寸帧。星球为受控星球1/探索240/四设施已建、固定业务快照和1×显示动画；反应堆证据为受控四路/单炼铁Owner参数、实际鼠标均分/返回装备和1×真实Session时钟。两者均MovieMaker离线30fps，具体版本/覆盖见各驱动与segment，不作实时性能或点击瞬间覆盖。本轮未追加性能或未改购买状态复测。

## 当前整页判断与接续

### 反应堆

制作依据为获准1586×992共同图：`24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png`。当前已接分件/六类材质/核心局部反光源；原组仍继续整体还原，不等用户。

本轮整页未见公共梁/导航与模块新增相交或截字，均分、数量/升级留在原台面；武器筒、盾环厚壳、炉口返回与前收集槽已有分件。整体仍未达到原图：深舱/回壁/地面透视较弱，管道圆截面与套筒厚度不足，装甲/内腔受光仍偏均匀色面和硬黑边。核心有汇入/缩紧/散开，亮包沿管到设备，但大部分观看仍像椭圆平场加小晶体，盾面/铁流/晶体腔的体积与相邻反光还不够。单路主体/短台留空和重心需连同场景看，满载100%在滑条左端而其他百分比在右端，读数锚点仍需原组统一。具体接续见reactor/author-review.md，不以分件、接口或材质角色存在判整体完成。

原组性能日志已读：首轮异常与后续有界软件复核均保留。当前离线采集无阻止交付的运行错误，但不能据此认定异常消除或目标机性能通过；目标环境同构建/同战场显示与关闭基线仍缺。

### 星球

唯一批准稿：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录planet-ring.png，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。

本轮开放泊位、两端服务舱与连续接轨已进入公共整页，船坞不再先读成封闭工厂；制造区单主吊架和纵轨比重复亮框更能解释开放工位。公共环境固定y65..900，主体min(高×0.21,宽×0.135)整组包络及源光学中心保持；人员/设施/征服不同高度台下未见新增碰状态条、压台或越导航。当前无需再缩主体或调整公共几何。

按批准图同球径，前设施的服务舱/支架和大浅装甲面仍偏方块堆叠，泊位凹深、承力臂/接轨腔口及制造井内机械层次不足；青色作业面和黄梁受光偏平亮，未形成图中的连续材质/接触阴影。后方舱体/窗带/桅杆与金顶细分仍简化。星点更密、气体边缘增加，但两侧仍是宽亮蓝云团，与原图深黑空间和细气体丝有差距。近弧电车可辨，远弧/展开后较弱。原组继续设施内件、材质受光和星云细层，不以开放泊位或主吊架出现判断整体完成；具体见本版author-review.md。当前不是成品确认稿，无用户等待依赖。

## 公共接入边界与下一步

公共资源栏为单一完整承载梁，导航为完整竖脊；模块x0..808、顶栏y0..65、导航x808..855.875及原战斗投影保持。公共组不在y65以下叠框遮盖，模块的舱室/台体以真实侧面、端接和接触受光接到公共结构。装备现有y65..85接续及已完成操作结构保持。

可消费公共源ee0e2ff1：`src/ui/zone_shell.gd`，`assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均在space-battleship），删除旧title-plaque.svg。BridgeTheme API与Owner不改；设计要求归13，不在交接另立规范。

1. 本轮闭包接入、必要运行整页/动态与固定交接已完成；当前无新增明确公共几何缺陷，不以此宣称整体美术通过。
2. 反应堆原组继续完整体积/材质/工作过程与单路布局，固定更新后精确消费并重看公共整页。
3. 星球原组继续前设施内件、局部光聚焦与面板材质，固定更新后按批准图复看完整页面。
4. 目标机性能依赖单列，当前无同条件目标环境基线，不用离线记录或软件观察替代，不新增无关复测或合main。
