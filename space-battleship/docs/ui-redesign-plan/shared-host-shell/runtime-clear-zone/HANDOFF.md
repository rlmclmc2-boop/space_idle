# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `6c7198ee`；当前为制作现场，未合main。
- 星球固定来源471349769，运行资产fb3b6249e；facilities_v9四GLB及两个脚本同源，保全当前现场。原组已恢复按现成设计图实际制作，后续消费其新同源资产。
- 反应堆来源a1406959，交接f97aef2d，十三件installation闭包同源，公共主题9034af81、main e845装备、现有公共宿主/导航和战场空间保留。planet_panel与e7591438相同，UI与业务修复保持。

## 当前目标

星球按原设计图实际制作：`8136cef8`的`scheme-b/solid-integrated-spine-clearance.png`与`1eda07fd`的`solid-integrated-spine-stages-closed.png`，完整Git路径以星球当前交接为准。连续实体环带、嵌入设施和整体比例是后续接入的视觉依据；在完整整页中判断主体质量分布、内外轮廓、功能空间与承力关系。

公共宿主继续负责主体安全区、操作台、导航及跨模块共同语言；保留现有业务、装备结构及战场空间。

## 反应堆当前同壳判断

证据：`archive/design-docs-before-cleanup-20261031@d637ea17:modules/public-ui/reactor-volume-shared-20261101/README.md`，五张1440×900整屏及同尺寸JPEG，四路12秒、单路6秒同源工作片及分片/哈希，作者整页判断在同目录author-review.md。

当前设备开口/盾环厚度、单路居中总成和公共操作关系可保持，所看画面没有新越台、导航侵入或公共层重复。仍需原反应堆组收口核心过程：较长汇入阶段的低反差蓝斑偏模糊，压缩峰值可辨，但释放后管内亮包偏短/暗，整页不易跟随到接收端。按现有深度、接口及节拍，用清楚的能量体轮廓、前后遮挡、形态阶段与可追随输送包强化因果读序，不需再改已成立的总成和操作台。

当前不直接作用户最终确认稿。四路为Session Owner受控开放/均分，单路为受控Reactor Owner；两片真实Session时钟1×、MovieMaker离线固定30fps，不作实时性能或完整游戏结论。当前无新增明确公共控件修正项。

## 下一步

1. 星球原组按上述原设计图继续运行资产制作，不等待新图稿确认；新同源资产固定后，整体组对照原图的连续实体环带、嵌入设施及整体比例精确接入，复看公共整页、不同台高及同源动态。
2. 将上述核心过程的当前可见项交原反应堆组窄收口；整体消费下一固定源后看完整同壳页面与受影响工作动态。
3. 不新增无依据公共微调、独立复测或main合并。
