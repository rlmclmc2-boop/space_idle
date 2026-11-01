# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `e3774ee5`，未合main。
- 星球来源 `cb0b96f86`：facilities_v9四GLB、planet_facility_scene.gd、planet_orbital_spine.gd、planet_visual.gd七件接入。六件同blob；planet_visual仅加固态整组宽度包络适配。planet_panel统一关闭/展开主体安全区，保留e7591438的业务/UI修复。
- 反应堆当前运行仍为 `6c7198ee`（来源a1406959、交接f97aef2d）。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

## 星球当前整页与下一项

原图依据：

- `8136cef8:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png`，右侧完整阶段。
- `1eda07fd:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png`。

当前证据：`archive/design-docs-before-cleanup-20261031@079134ad:modules/public-ui/planet-v24-original-shared-20261101/README.md`。五张1440×900原屏及同尺寸JPEG，总览/设施展开各6秒180连续帧、分片/哈希和两张原图同尺寸JPEG；具体源映射、显示适配补丁和作者整页判断均在同目录。

接入和显示适配完成：整组同比适配顶部状态区与操作台之间的安全空间，两段当前动态内前侧船坞完整、主体不与导航或不同高度详情台相交。采证为受控星球1、探索240、征服/四设施已建，业务快照暂停，显示动画1×；MovieMaker离线固定30fps，不作实时性能或整周结论。

当前仍是制作候选，不作用户确认稿。下一项交星球原组按原图完成主体：

1. 恢复低倾角横向椭圆及星体/前后弧的遮挡比例，当前后方大环仍高出星体、姿态偏直立。
2. 以平整分段甲板、深侧壁/龙骨和节段接缝建立连续建筑带截面，收敛当前圆软起伏的鼓面。
3. 观测平台/塔体、热处理穹顶及制造深腔形成主要功能体量，保留开放泊位负形；当前青橙小凸点和浅栏不足以替代原图设施体积。

整体保留当前公共安全区及UI修复，消费原组下一固定资产后看完整整页与受影响动态；不通过独立缩建筑、裁切或挤战场解决原图比例。

## 反应堆当前同壳判断

证据：`archive/design-docs-before-cleanup-20261031@d637ea17:modules/public-ui/reactor-volume-shared-20261101/README.md`，五张1440×900整屏及同尺寸JPEG，四路12秒、单路6秒同源工作片及分片/哈希，作者整页判断在同目录author-review.md。

当前设备开口/盾环厚度、单路居中总成和公共操作关系可保持，所看画面没有新越台、导航侵入或公共层重复。仍需原反应堆组收口核心过程：较长汇入阶段的低反差蓝斑偏模糊，压缩峰值可辨，但释放后管内亮包偏短/暗，整页不易跟随到接收端。按现有深度、接口及节拍，用清楚的能量体轮廓、前后遮挡、形态阶段与可追随输送包强化因果读序，不需再改已成立的总成和操作台。

当前不直接作用户最终确认稿。四路为Session Owner受控开放/均分，单路为受控Reactor Owner；两片真实Session时钟1×、MovieMaker离线固定30fps，不作实时性能或完整游戏结论。当前无新增明确公共控件修正项。

## 独立剩余项

反应堆核心过程按上节具体制作要求等原组固定修订后接入；星球按上述主体资产要求继续。当前无新增明确公共控件缺陷，不新增无依据微调、独立复测或main合并。
