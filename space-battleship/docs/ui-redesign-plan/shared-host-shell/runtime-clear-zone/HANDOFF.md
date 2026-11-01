# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `6d8a4dd9`，未合main。
- 星球来源 `415d3bbdf`：facilities_v9四GLB、planet_facility_scene.gd、planet_orbital_spine.gd六件接入并同blob。planet_visual保留公共固态整组宽度包络，planet_panel保留关闭/展开安全区及e7591438的业务/UI修复。
- 反应堆当前已接入 `c74b5d39`（交接76a03605）的十三件installation闭包，逐blob同源。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

## 星球当前整页与下一项

原图依据：

- `8136cef8:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png`，右侧完整阶段。
- `1eda07fd:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png`。

当前证据：`archive/design-docs-before-cleanup-20261031@88c4f81d:modules/public-ui/planet-v31-front-detail-shared-20261101/README.md`。五张1440×900原PNG及同尺寸JPEG、总览/设施各6秒180连续帧、分片/哈希和原图同尺寸JPEG；source.json及author-review.md记录来源和完整作者判断。

本版已由父实际发送完整实机图和视频，发送记录 `Sentinel_c9c0790924ac819196175fc798d7a926`，已回读三附件；当前仅整体造型/建筑效果的视觉评价等用户，尚无独审或用户通过。主体横向环带、前后遮挡与负形、四设施功能轮廓和主次保持；前方泊位有斜装甲肩、厚入口、暗内壁回边和夹持部件，制造区有外装甲/暗内口/压力侧壁/工作床层次，均有完整舱底承托且保留开放空间。浅装甲、深腔、功能重点色与舰船/公共层可并置；不同台高和两片当前转动内，没有所见新增裁切、跳位或导航侵入。

当前仍是原图在游戏简化分面语言中的实现，非原图细节等量还原或用户终验。运行源及证据保留，不自行追加装饰或推翻主体。

受控星球1、探索240、征服/四设施已建，业务快照暂停、正常显示动画1×；MovieMaker固定30fps离线生成，不作自然进度/整周/全交互/实时性能结论。四GLB同源，现有公共安全区和UI修复保持。

## 反应堆当前同壳判断

证据：`archive/design-docs-before-cleanup-20261031@b55d08d8:modules/public-ui/reactor-receiver-shared-20261101/README.md`。五张1440×900原PNG及同尺寸JPEG，四路/单路各12秒360连续帧及分片哈希，全部逐帧总览和原尺寸关键帧、日志。作者整页判断见同目录author-review.md。

当前整页中汇入/紧束压缩/定向释放、管内输送、接收窗充亮保持回落、设备短回应已能连续辨认，具备本轮父级复看及用户视觉评价条件。四路约1.2秒亮包仍在管中，1.9秒开始到窗，2.5秒窗体保持并见设备工作区增强；单路约1.37秒到窗、1.73–2.13秒保持，炉内热区接着短增强。窗内光受外壳包络，没有全管常亮或整机通用闪白。当前五页及两片没有所见新增公共布局、操作台/导航相交或截字，设备/核心主次、单路构图和操作锚点保持。

父已实际发送运行源bf9c52ba的完整实机图和视频，记录 `Sentinel_7b131224747c81919fb1c8d599f72720`，已回读四附件；当前仅本版视觉评价等用户，尚无独审或用户通过。原生均分/返回装备由driver实际执行并断言；四路Owner受控开放/钱包、单路受控Reactor Owner，真实Session时钟1×。MovieMaker固定30fps离线生成，不作实时性能结论。来源新短窗未复现前次冻结长尾，但原因未定位，目标机同构建同战场显示/关闭基线仍缺，不宣称收益或性能通过，不新增测量。

## 独立剩余项

1. 反应堆bf9c52ba与星球6d8a4dd9的本轮视觉候选均已实际交用户，只对应视觉方向/效果等待其意见；按后续真实反馈续接，main未合。
2. 当前没有已发现且可独立继续修正的公共控件/区域缺陷，也没有待消费的新模块固定源，保留当前现场，不制造微调或新复测。
3. 目标机性能尚缺同构建、同战场显示/关闭基线。当前环境只能提供软件渲染观察，不能补成目标机证据；等待该具体环境/数据，不扩测替代。
