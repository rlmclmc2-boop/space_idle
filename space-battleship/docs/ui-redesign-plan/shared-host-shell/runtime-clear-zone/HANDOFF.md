# 公共壳制作交接

规范入口：[公共美术](../../../game-design/13-art-interaction.md)、[星球M7](../../../game-design/art/modules/planet.md)、[反应堆资产接口](../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前版本

- 工作区 `/workspace/space_idle`，分支 `design/clear-zone-host`，运行源 `ad184682`，未合main。
- 星球来源 `cb0b96f86`：facilities_v9四GLB、planet_facility_scene.gd、planet_orbital_spine.gd、planet_visual.gd七件接入。六件同blob；planet_visual仅加固态整组宽度包络适配。planet_panel统一关闭/展开主体安全区，保留e7591438的业务/UI修复。
- 反应堆当前已接入 `ba137938`（交接df1e6ad5）的十三件installation闭包，逐blob同源。公共主题9034af81、main e845装备、公共宿主/导航和战场空间保持。

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

证据：`archive/design-docs-before-cleanup-20261031@9dc74760:modules/public-ui/reactor-readable-shared-20261101/README.md`。五张1440×900原屏及同尺寸JPEG，四路/单路各12秒360连续帧、分片/哈希，完整逐帧总览与原尺寸关键帧。作者整页判断见同目录author-review.md。

整页设备体积、单路共同重心、总量/均分及费用两键锚点保持，公共导航和操作台没有所见新增相交/截字。汇入能量体的前亮后暗及靠近方向、中心紧束压缩、定向释放和黑管腔内白头青尾的移动已能区分，当前不用再改核心/设备总成或操作布局。

仍需原反应堆组收口接收端：四路约1.2–1.9秒亮包可跟随到套筒，但到达只露出小块青光；单路第42帧（约1.37秒）接收座只在宽套筒边缘有很小亮点，随后暗下，整页易读成亮包进入口腔后消失。请保留真实金属遮挡，在可见接收座上使到达响应具有清楚起落、与输送相接，不全管常亮或穿透外壳。本轮为继续制作候选，不直接作用户确认稿。

两片真实Session时钟1×，四路Owner受控开放/钱包、单路受控Reactor Owner；原生均分及返回装备由driver执行并断言。MovieMaker固定30fps离线生成，不是实时性能。来源performance.log冻结窗p95 38.239ms，冻结均值25.20ms高于运行23.05ms，原始异常已保留、原因未定位；短窗不阻塞当前视觉采证，但不构成目标机性能通过，不新增性能测试。当前无新增明确公共控件缺陷。

## 独立剩余项

反应堆接收端按上节具体制作要求等原组固定修订后接入；星球按上述主体资产要求继续。当前无新增明确公共控件缺陷，不新增无依据微调、独立复测或main合并。
