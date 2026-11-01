# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `bf9c52ba`，未合main。
- 星球来源 `9c1bc8130`：facilities_v9四GLB、planet_facility_scene.gd、planet_orbital_spine.gd六件接入并同blob。planet_visual保留公共固态整组宽度包络，planet_panel保留关闭/展开安全区及e7591438的业务/UI修复。
- 反应堆当前已接入 `c74b5d39`（交接76a03605）的十三件installation闭包，逐blob同源。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

## 星球当前整页与下一项

原图依据：

- `8136cef8:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png`，右侧完整阶段。
- `1eda07fd:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png`。

当前证据：`archive/design-docs-before-cleanup-20261031@191e4bab:modules/public-ui/planet-v30-original-refined-shared-20261101/README.md`。五张1440×900原屏及同尺寸JPEG，总览/设施展开各6秒180连续帧、分片/哈希、两张原图同尺寸JPEG；源映射和作者整页判断均在同目录。

作者判断已具备交用户评价本轮整体造型及风格关系的条件：星体主焦点、横向实体环带和前后弧遮挡比例接近原图；观测盘/塔、金色热工穹顶、左纵向泊位与右制造舱可凭形状/开口/重点色区分。舱门柱、上梁、舱底及侧壁能读成共同承托，前端收口完整。总览及三种台高、两段当前转动内没有所见新裁切或导航/状态区相交。公共深青与浅装甲/功能重点关系可以保持。

材质仍是游戏分面语言下的简化实现：门架大灰梁面、环板分节和观察台侧壁的中尺度机械层次少于原图，不称原图细节等量还原或品质终验。当前未实际发用户；推荐父复看总览、设施展开JPEG和设施6秒片后交付完整候选，不能提前写成用户等待/认可。

受控星球1、探索240、征服/四设施已建，业务快照暂停、显示动画1×；MovieMaker固定30fps离线生成，不作实时性能/整周/自然进度结论。保留当前公共安全区和UI修复，不再自行改主体或追加无依据微调。

## 反应堆当前同壳判断

证据：`archive/design-docs-before-cleanup-20261031@b55d08d8:modules/public-ui/reactor-receiver-shared-20261101/README.md`。五张1440×900原PNG及同尺寸JPEG，四路/单路各12秒360连续帧及分片哈希，全部逐帧总览和原尺寸关键帧、日志。作者整页判断见同目录author-review.md。

当前整页中汇入/紧束压缩/定向释放、管内输送、接收窗充亮保持回落、设备短回应已能连续辨认，具备本轮父级复看及用户视觉评价条件。四路约1.2秒亮包仍在管中，1.9秒开始到窗，2.5秒窗体保持并见设备工作区增强；单路约1.37秒到窗、1.73–2.13秒保持，炉内热区接着短增强。窗内光受外壳包络，没有全管常亮或整机通用闪白。当前五页及两片没有所见新增公共布局、操作台/导航相交或截字，设备/核心主次、单路构图和操作锚点保持。

当前仅作者完整整页判断，尚未实际交用户，不写作用户认可。原生均分/返回装备由driver实际执行并断言；四路Owner受控开放/钱包、单路受控Reactor Owner，真实Session时钟1×。MovieMaker固定30fps离线生成，不作实时性能结论。来源新短窗未复现前次冻结长尾，但原因未定位，目标机同构建同战场显示/关闭基线仍缺，不宣称收益或性能通过，不新增测量。

## 独立剩余项

1. 当前反应堆完整同壳候选交父级复看，随后按用户实际反馈续接；没有本轮发现的独立公共控件缺陷。
2. 星球fb482dce保留，原组继续前方设施质感，消费其下一固定源后复看完整组合；当前星球图未实际发送不写待用户。
3. 目标机性能仍缺上述具体依据。无新增授权动作时不制造微调或扩大矩阵，不新增独立复测或合main。
