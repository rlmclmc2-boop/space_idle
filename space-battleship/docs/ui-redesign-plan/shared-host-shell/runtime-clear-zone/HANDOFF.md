# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，星球主体见[M7](../../../game-design/art/modules/planet.md)，反应堆控制区内容口见[资产契约](../../../game-design/art/modules/reactor-asset-contract.md#宿主安装与三段控制区内容口)。

## 当前现场

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `c3b5d426`，当前为制作现场，未合main。
- 星球固定来源 `wip/planet-thread-resume-20261101@04db6b3f`：四GLB、planet_facility_scene.gd、planet_orbital_spine.gd六件同源。
- 公共主题9034af81、宿主/导航、main e845装备操作结构和战场空间保持；planet_panel与e7591438相同，人员撤回、引用清理和反馈修复、y65起点与共用底台保留。
- 反应堆运行资产5ae32e28，三段控制区内容口73caec37；等待原组下一成套固定运行源。

## 当前目标与未完成项

星球设施与环结构形成有层次的整体建筑剪影，与舰船和公共控件保持共同造型及材质语言。当前仍需解决环与节点的体量比例、节点分布及连续建筑节奏；以完整页面的主次和空间关系判断。

## 下一步

1. 星球原组继续整体构图制作并交固定源；整体组查看完整主剪影、比例及建筑节奏，再精确接入公共宿主，结合不同操作台高度复看整页。
2. 保留公共UI与业务修复、装备和战场空间；模块内部资产由原组制作。
3. 反应堆固定源独立交接；当前没有新增明确公共控件修正项，不追加无依据微调或复测。
