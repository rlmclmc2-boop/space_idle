# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `79329163`，未合main。
- 星球来源 `ccf596c4`：facilities_v9四GLB、planet_facility_scene.gd、planet_orbital_spine.gd六件接入并同blob。planet_visual保留公共固态整组宽度包络，planet_panel保留关闭/展开安全区及e7591438的业务/UI修复。
- 反应堆当前已接入 `ba137938`（交接df1e6ad5）的十三件installation闭包，逐blob同源。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

## 星球当前整页与下一项

原图依据：

- `8136cef8:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png`，右侧完整阶段。
- `1eda07fd:space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png`。

当前证据：`archive/design-docs-before-cleanup-20261031@a01db75f:modules/public-ui/planet-v28-original-framing-shared-20261101/README.md`。五张1440×900原屏及同尺寸JPEG，总览/设施展开各6秒180连续帧及分片/哈希，两张原图同尺寸JPEG；源映射与作者整页判断均在同目录。

当前横向椭圆、后弧遮挡与前弧间隔已接近原图，观测/热工主体和两个开放功能区形成区别。五页及两片所看时段内，主体与顶部状态区、不同台高和导航保持安全间距，无新裁切。受控星球1、探索240、征服/四设施已建，业务快照暂停、显示动画1×；MovieMaker固定30fps离线生成。

当前是可比较原图结构/比例的制作候选，材质与舱口完成度尚不宜作成品确认。星球原组下一项：

1. 保留共同曲率、朝向和整体比例，把弧段亮面收成明确的顶面/倒角/深侧壁截面，节段接缝对应装甲结构，收敛鼓起曲面及锯齿折痕，不靠新增噪声或黑线。
2. 保留两处开放舱口负形，完成门柱/上梁/舱底/侧壳的承托连接及端部封边。当前泊位和制造区域仍偏细杆骨架，前侧深壳端部偏薄尖片；需形成建筑带内的功能空间，而不封死开口或增添新功能。

整体保留现有公共安全区和UI修复，消费下一固定资产后按完整整页和受影响动态判断，不新增战场/公共布局变更。

## 反应堆当前同壳判断

证据：`archive/design-docs-before-cleanup-20261031@9dc74760:modules/public-ui/reactor-readable-shared-20261101/README.md`。五张1440×900原屏及同尺寸JPEG，四路/单路各12秒360连续帧、分片/哈希，完整逐帧总览与原尺寸关键帧。作者整页判断见同目录author-review.md。

整页设备体积、单路共同重心、总量/均分及费用两键锚点保持，公共导航和操作台没有所见新增相交/截字。汇入能量体的前亮后暗及靠近方向、中心紧束压缩、定向释放和黑管腔内白头青尾的移动已能区分，当前不用再改核心/设备总成或操作布局。

仍需原反应堆组收口接收端：四路约1.2–1.9秒亮包可跟随到套筒，但到达只露出小块青光；单路第42帧（约1.37秒）接收座只在宽套筒边缘有很小亮点，随后暗下，整页易读成亮包进入口腔后消失。请保留真实金属遮挡，在可见接收座上使到达响应具有清楚起落、与输送相接，不全管常亮或穿透外壳。本轮为继续制作候选，不直接作用户确认稿。

两片真实Session时钟1×，四路Owner受控开放/钱包、单路受控Reactor Owner；原生均分及返回装备由driver执行并断言。MovieMaker固定30fps离线生成，不是实时性能。来源performance.log冻结窗p95 38.239ms，冻结均值25.20ms高于运行23.05ms，原始异常已保留、原因未定位；短窗不阻塞当前视觉采证，但不构成目标机性能通过，不新增性能测试。当前无新增明确公共控件缺陷。

## 独立剩余项

反应堆接收端按上节具体制作要求等原组固定修订后接入；星球按上述装甲截面与舱口承托要求继续。当前无新增明确公共控件缺陷，不新增无依据微调、独立复测或main合并。
