# 手绘单壳、开放部件托盘与数值精准刷新候选

`34c79083` 仍被根/原Astra判为通用灰凹框，美术未通过。本次不是继续加厚边：使用一件按机库材质上下文制作的空白手绘壳，撤图标框和整卡凹框，材料分工为开放图标/部件托盘、唯一软仪表面、直接落台面的报价、主次漆面按键。当前艺术效果待原审，不自判通过，不pushmain。

## 版本与主图

- 当前视觉源码 `03b523237d1b82a04376d72379766d5101b5a331`；两张当前作者整屏：[双资源/开放候选](02-double.png)、[同体系批量](04-batch.png)，原像素局部见本目录-local图。源字节在作者取图至固定Git之间未改变，以source-boundaries的SHA绑定；不冒称固定提交后又重跑业务。
- 数值/创建/失效必要观察源码 `89ac5d0a0a4a124b0dbff9a15b92a50f2a1b9588`，其原始4整屏/4局部、[36条操作/计数](runtime-89ac5d0a/operations.json)、[原日志](runtime-89ac5d0a/runtime.log.txt)、[原驱动](runtime-89ac5d0a/capture-driver.gd.txt)独立留在runtime-89ac5d0a，不修改原记录、不写成后续视觉补缝版重跑。后续只加Panel壳边白漆过渡，11个相关逻辑函数逐字该观察版。
- [实际计数摘要](refresh-summary.json)、[源码/旧源归档字节绑定](source-boundaries.json)。main/Session/Owner/Economy/Campaign/project及正式机库/船武器/几何逐字main `e3b38d7b6d8256f6031e1b086c7db7812b6a441f`。

## 材质与自然过渡

单件新[空白壳PNG](../../../../../assets/ui/equipment/materials-20261029/painted-console-shell.png)、[完整提示](../../../../../assets/ui/equipment/materials-20261029/painted-console-prompt.txt)、[原始来源/参考图hash及消费](../../../../../assets/ui/equipment/materials-20261029/painted-console-sources.json)。实际image_gen.imagegen生成，原2117×743透明PNG保留/workspace/generated_images/exec-866f42f0-5d24-4a52-8558-f585055b792f.png；SHA256 `f5aa0c10ee10581319eb257043e526321b5f0fd6b51dbece53d9e62b9c786ce1`，提示SHA256 `094afb28aa414154fc1eca97d2f228d28c79d1ad0a067b5004fb3763a0f48c47`。不含文字/图标/状态，正式船武器机库不换。

按实壳alpha边界取(8,56,2102,620)，统一缩到640宽/整数高189；固定32px角部、直边TILE，中心独立漆面，**不把整壳跨比拉伸**。首轮作者看图发现20px切片未包完角部、重复成侧边接头，且底缘过紧；已固定完整角部与实际边缘尺度，原/tmp/equipment-painted-preview保留。后续观察到源边内白漆/阴影与中心在切片边硬接，已仅对既有Panel源壳16–31px内侧白漆做柔和alpha过渡，深色壳/角部保留，底面及子文字不受影响；无新增控件/新素材批。

图标框删除；候选只在正式图标下承托小托盘，名称/状态用暗色原生文字直接在台面上，不再每件套同形框。读数只保唯一软接缝仪表面，无绿高光/硬凹槽。购买/安装/执行保持主层级，模式次、关闭弱；按键不再硬斜面，多态缓存初始化一次。公共顶栏/main不改，两键报价/购买关系、字体/数据和点击布局保留。

## 用户要求的清理与刷新：已发现、已做与边界

**已发现并清理：** 空PurchaseRail Panel；不再参与读取的CurrentIconBezel节点/字段/布局；旧硬deck/recess/cassette/beam绘制分支、无调用slot皮肤分支；原初始通用皮肤随后又建primary/quiet皮肤的重复临时分配。现直接按角色构造一次缓存。旧未消费atlas PNG/import/提示/来源100%原字节移到[.gdignore来源档案](../rejected-art-sources/ba7/README.md)，不再留runtime assets；原import仅作为.txt历史文本，原hash含义不变。没有叠新节点遮旧界面。

**刷新实际情况：** 原路径不是每次数值重建整树，已有ID节点复用/签名早退；但slots_changed丢弃IDs并且每笔等级结果都置_dirty，会额外读候选选项。现合并等级IDs走一次数值刷新，只改相关槽等级、当前比较/报价和可见Batch；换装/可用性/换舰仍走必要结构失效。候选选择用同槽的选项缓存更新原生选择/报价，选项来源变化仍重新读Owner，不以省计数跳过必要更新。

在同一次真实main/Session/native运行中，36项必要观察exit0：

| 事件 | full | numeric | UI fact读 | options读 | 舰体stage重绘 | compare读 |
|---|---:|---:|---:|---:|---:|---:|
| 单槽购级 | 0 | 1 | 1 | 0 | 0 | 1 |
| Batch购级 | 0 | 1 | 1 | 0 | 0 | 1 |
| 循环报价 | 0 | 0 | 0 | 0 | 0 | 1 |
| 候选选择 | 0 | 0 | 0 | 0 | 0 | 1 |
| 真实refit | 1 | 0 | 1 | 1 | 1 | 1 |
| 受控真实availability变化 | 1 | 0 | 1 | 1 | 0 | 1 |

单槽/Batch后Owner比较、原生当前值和Batch等级一致；节点79→79、同一节点ID/缓存材质ID；availability阶段77→77。差别2节点是后续fixture首次真实双资源报价建立的两枚缓存Label，并非每次购级新增。计数为UI仪表，驱动独立读Owner作对照，不宣称全局查询数；公开facts口仍一次返回全槽快照，没有改Owner端口。费用Label按资源ID有界缓存/隐藏复用、合法未解锁候选为固定目录ID的无显示/无焦点缓存，属于在用状态缓存而非废层；只有消失ID才queue_free并删字典。**同预算早退本轮仅静态保留，未重新触发测试**。初始化/建控件不在数字更新路径调用。

本轮不新增独立全套/全链；spent只记真实Owner回执，不扩称可观察精扣。旧ba7动态/32观察仍是旧版，不当本轮材质视频。极端金额/全舰/WindowsDPI/长期/完整保存/故障矩阵及真实三费继续未扩，三费无生产源不伪造。

## 资源共用身份待接口（未接入）

根新增要求固定c4c48282的13§2.2/resource_visuals.gd共用资源身份，尚未完成：正常fetch整体分支得到fa28589bbf4e2ae84f3174737114eca407a13fcb，本地无法读取c4c48282；已报根，等完整SHA/已推分支，不猜用其他版本、不为相同资源生成新图。[精确状态](shared-resource-status.json)。本候选不能声称已统一资源图标；接口到达后只需最小共用源/资产和必要静态费用图标版，不重复36项。

原分支/原workspace/cache/tmp保持，收尾期间发生实际上下文压缩，完成本自然项归档后原地交接停止；不Library/Space，不pushmain。艺术效果交原Astra/根判断。
