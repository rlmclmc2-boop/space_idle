# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。本人直接执行，不使用子智能体。

## 当前版本与同源证据

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `b43a3da6`，未合main。
- 反应堆 `0e5ce0067d5d5ffa7a31768e8bdd6835b468eebc` 的十四件installation闭包逐blob同源，包含私有GLB、Stage、shader及metadata；Owner/原生控件不替换。源交接df65d3d6；installation在 `archive/reactor-material-refinement-20261101@d3f1bdd3:modules/reactor/material-refinement-20261101/installation.json`。
- 星球 `eedde803682672187a0fd5977159a085e1adf6b5` 的四GLB、设施场景/轨道、两个shader及cloud-density云图九件逐blob同源。planet_visual保留整组包络与独立环境矩形，planet_panel保留主体安全区及业务/UI修复。
- 本轮仅11件生产文件变化：反应堆7件、星球4件。公共承载ee0e2ff1、主题9034af81、最终装备main e845、main/Owner、导航及战斗空间保持。

同版整页与动态：`archive/design-docs-before-cleanup-20261031@577bf4557cb958217cd36968beb78f9116b0ddd3:modules/public-ui/reactor-material-planet-couplers-shared-20261101/README.md`。reactor/与planet/各五张1440×900原PNG/同尺寸高质量JPEG，各有两段6秒180帧视频、640KiB无损分片/哈希、逐帧总览及author-review.md；source.json记录精确闭包/保留文件。批准原图的格式转换与星球约等球径对照同存。

导入与运行成功。作者亲看十张完整页面、四段共720帧总览及代表原尺寸帧；录制采用MovieMaker离线30fps，显示/工作时钟1×。反应堆为受控四路及单炼铁Owner参数、实际鼠标均分/返回装备；星球为受控星球1/探索240/四设施已建、固定业务快照和连续显示动画。证据覆盖见驱动与segment，不把工作片段写成此前点击瞬间覆盖。本轮没有追加性能或未改购买状态复测。

## 当前整页判断与接续

### 反应堆

制作依据为获准1586×992共同图：`24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png`。当前已接分件/六类材质/核心局部反光源；原组仍继续整体还原，不等用户。

本轮整页未见公共梁/导航与模块新增相交或截字，均分、数量/升级留在原台面；武器筒、盾环厚壳、炉口返回与前收集槽已有分件。整体仍未达到原图：深舱/回壁/地面透视较弱，管道圆截面与套筒厚度不足，装甲/内腔受光仍偏均匀色面和硬黑边。核心有汇入/缩紧/散开，亮包沿管到设备，但大部分观看仍像椭圆平场加小晶体，盾面/铁流/晶体腔的体积与相邻反光还不够。单路主体/短台留空和重心需连同场景看，满载100%在滑条左端而其他百分比在右端，读数锚点仍需原组统一。具体接续见reactor/author-review.md，不以分件、接口或材质角色存在判整体完成。

原组性能日志已读：首轮异常与后续有界软件复核均保留。当前离线采集无阻止交付的运行错误，但不能据此认定异常消除或目标机性能通过；目标环境同构建/同战场显示与关闭基线仍缺。

### 星球

唯一批准稿：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/index.md`，同目录planet-ring.png，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。

本轮双层指挥窗、下部承力舱、端接套及前工位分段已进入公共整页。公共环境固定y65..900，主体min(高×0.21,宽×0.135)整组包络及源光学中心保持；人员/设施/征服不同高度操作台下未见新增裁切、碰顶栏或压台，所看转动序列无布局跳变。

按批准图同球径，前设施仍以大浅装甲面和重复块件主导，泊位/载具、制造井内机械及内壁深度不足；亮长梁和泛黄装甲抢过暗色作业井，局部暖光尚需聚焦。后方舱体端接/窗带/桅杆和金顶接触细节仍简化，背景宽模糊蓝云未还原细密气体层。近弧电车可辨，远弧/展开后较弱。原组继续前设施内件、面板与受光，不以接口补齐判整体完成；具体见planet/author-review.md。

## 公共接入边界与下一步

公共资源栏为单一完整承载梁，导航为完整竖脊；模块x0..808、顶栏y0..65、导航x808..855.875及原战斗投影保持。公共组不在y65以下叠框遮盖，模块的舱室/台体以真实侧面、端接和接触受光接到公共结构。装备现有y65..85接续及已完成操作结构保持。

可消费公共源ee0e2ff1：`src/ui/zone_shell.gd`，`assets/ui/public_shell/command-rail.svg`、`navigation-spine.svg`、`nav-idle.svg`、`nav-hover.svg`、`nav-active.svg`（均在space-battleship），删除旧title-plaque.svg。BridgeTheme API与Owner不改；设计要求归13，不在交接另立规范。

1. 本轮闭包接入、必要运行整页/动态与固定交接已完成；当前无新增明确公共几何缺陷，不以此宣称整体美术通过。
2. 反应堆原组继续完整体积/材质/工作过程与单路布局，固定更新后精确消费并重看公共整页。
3. 星球原组继续前设施内件、局部光聚焦与面板材质，固定更新后按批准图复看完整页面。
4. 目标机性能依赖单列，当前无同条件目标环境基线，不用离线记录或软件观察替代，不新增无关复测或合main。
