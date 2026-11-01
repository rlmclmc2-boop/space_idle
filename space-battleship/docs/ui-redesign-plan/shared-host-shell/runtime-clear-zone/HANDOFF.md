# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `281a17cc`；当前为制作现场，未合main。
- 星球固定来源471349769，运行资产fb3b6249e；facilities_v9四GLB及两个脚本同源，保全当前现场。原组已恢复按现成设计图实际制作，后续消费其新同源资产。
- 反应堆来源4f73ea46，公共主题9034af81、main e845装备、现有公共宿主/导航和战场空间保留。planet_panel与e7591438相同，UI与业务修复保持。

## 当前目标

星球按原设计图实际制作：`8136cef8`的`scheme-b/solid-integrated-spine-clearance.png`与`1eda07fd`的`solid-integrated-spine-stages-closed.png`，完整Git路径以星球当前交接为准。连续实体环带、嵌入设施和整体比例是后续接入的视觉依据；在完整整页中判断主体质量分布、内外轮廓、功能空间与承力关系。

公共宿主继续负责主体安全区、操作台、导航及跨模块共同语言；保留现有业务、装备结构及战场空间。

## 下一步

1. 星球原组按上述原设计图继续运行资产制作，不等待新图稿确认；新同源资产固定后，整体组对照原图的连续实体环带、嵌入设施及整体比例精确接入，复看公共整页、不同台高及同源动态。
2. 反应堆原组继续设备体积、核心工作过程及少路数完整构图；整体消费下一固定源并看同版整页/动态，独立继续。
3. 不新增无依据公共微调、独立复测或main合并。
