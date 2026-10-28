# 装备单工作台修正候选：根审交接

运行源码 `4f18eee875a046f220b5c3cf755b7c409fb9f2b5`，原目录 `/workspace/space_idle`，原分支 `implement/equipment-hangar-godot`。本次接替复用唯一现有WIP（SHA256 `12d453d9ced6fbefced788af9253fe16d92e0c883b7c5bd7811efb28b2e742cc`），没有另建工作区、重做已认可U1武器或重跑全套。用户已明确“去改”，此次内部修正授权优先于退回基线中的待设计稿冻结。未合main；以下是待根审候选，**不宣称整体视觉、停机关系或V0/V2通过**。

## 根因与删除/修改链

- 旧 `_draw` 绘完整下方双台PNG，再绘SVG切片和轮廓；三套材质几何不一致，造成深边残留、斜框被浅板覆盖及左右错壳。现在原PNG只读源y0..845的机库区域，旧下方三段draw、SVG/outline及重复数据切片都删除；由一个真实 `EquipmentWorkbench` Panel拥有统一外框、对象梁、左右内容、分隔及按钮。不是旧底图盖新浅板。
- 原 `_compare` 隐藏Label仍组文，另有两列表头/数值，且同物也重复显示。旧Label/组文删除；仅选中不同候选时显示必要两列比较与安装；同物只保留现装主值和已装备候选卡，没有无效安装/重复读数。
- 候选图原y2贴顶；现在可见图最小8px顶距，卡底与表头8px净空。现装图标沿用已审光学标定，主值面仍343×64、27px，普通/长值标签内收，费用按真实资源行数显示。工作台为(16,610,776,286)，两个动作同y850..886。
- 原回执在台体外；现在在对象梁内，完整回执保留悬停文本。实际换装完成和真实购级反馈均有整屏证据。
- 原五舰可见中心相同，但大小舰舰尾落点不同。现在用机库源台面前侧线候选点(594,730)，映为本地(404,547.1893)，每舰可见alpha舰尾对齐该点；武器、可见框仍同源同倍率。145.905/166.115/234.463/265.635/320px五档递进保持，不动战场/共享几何。这是展示候选锚，真实停靠关系仍由根端看图判断。
- 原防御三贴片、代理位置与虚线全部退出绘制/命中框。防御无物理组件点；保留真实侧槽单选、对应对象栏/图标/容量/候选及舰名轻色范围强调。三槽选中不付费、不装配。不补造战斗盾、装甲挂点或新规则；“作用于整舰”是否足够清楚仍待视觉审查。

## 同版真实整屏与局部图

真实Godot4.7.2/main/Session/native，1440×900、左808×900；所有13张整屏和7张局部均已实际view_image核看。原12张在源码提交前采集，其源码SHA与固定Git blob逐字节一致；原 `source_commit=workbench-rebuild-preview` 及15项记录原样保留，未篡改为提交后重跑。绑定见 [manifest.json](manifest.json)。第13张在固定提交上另补真实购级，未再运行原15项。

| 状态 | 真实整屏 | 重点局部 |
|---|---|---|
| 默认新局/单资源/同物 | [新局](01-fresh-silhouette-normal.png) | [完整工作台](crop-same-workbench.png) |
| cleared1导弹可选、其余剪影锁定/异物比较 | [部分开放](02-cleared1-missile-color-others-silhouette.png) | [卡顶、比较与安装](crop-different-workbench.png) |
| 实际导弹安装后/冷却/回执 | [安装后](02b-after-install-feedback-inside-workbench.png) | [对象梁回执](crop-install-receipt.png) |
| 长MAX/双资源/完整主值 | [长MAX](03-long-values-shared-material.png) | [字形、费用及比较](crop-long-max-workbench.png) |
| 五档同机位 | [Frigate](04-scale-Frigate.png)、[Destroyer](04-scale-Destroyer.png)、[Cruiser](04-scale-Cruiser.png)、[Battleship](04-scale-Battleship.png)、[Heavy](04-scale-Heavy_Battleship.png) | [小舰停机](crop-frigate-dock.png)、[大舰停机](crop-heavy-dock.png) |
| 防御三槽真实单选 | [槽1](05-defence-0.png)、[槽2](05-defence-1.png)、[槽3](05-defence-2.png) | [槽3与无贴片舰体](crop-defence-slot-and-hull.png) |
| 固定提交真实+1购买 | [Lv2 / 钱包935 / 梁内实际回执](06-fixed-source-actual-purchase.png) | 整屏已含工作台 |

局部图仅由所列整屏原像素裁切，无缩放/重绘/拼贴；坐标及SHA见manifest。新局为隔离默认状态；cleared1、全开放、长金额/等级、五档配装均由驱动明确受控restore及真实equip/refit准备，不能证明自然开放/收入流程。个人存档/设置/配置输出/缓存未入Git。

作者看图结果：未见旧深蓝边/双框叠层，候选不顶卡，异物比较与卡底分开，回执入栏，同物不重复读数，五舰位于台面且舰尾同一前侧线，防御不再有三块悬浮贴片。**仍须根端判断整体材质、紧凑度、右下空域及停车关系。** 同物右下空域仍明显，源于无比较/安装；未加常驻说明或无意义组件填空。长MAX/双资源和异物比较实际使用该高度，因此本次未再盲目减高。

## 实际操作与保护证据

原预览 [preview.log.txt](preview.log.txt) 为exit0、15项记录/0失败；[原操作](preview-operations-original.json)、[原驱动](preview-capture-driver.gd.txt)、[原交接](original-handoff.md)及patch原样保留。[check.log.txt](check.log.txt)为原同SHA的4.7.2 GDScript检查。锁拒绝/浏览不安装/真实导弹安装/长值字形/五档装配/三防御浏览覆盖只限这些场景。

固定源码另补 [focused-operations.json](focused-operations.json) 四项真实操作，进程exit0、0失败，见 [实际驱动](focused-capture-driver.gd.txt) 与 [完整日志](focused.log.txt)：

1. 暂停真实新局，发相同预算的公开经济显示通知：refresh/comparison/slot/options/candidate/redraw计数不变，钱包/装备/native不变。
2. 受控钱包改为1000铁并发公开预算通知：仅一次比较，未全读槽/选项或重绘机库。
3. 真实鼠标点击新工作台购买：accepted、所选武器Lv1→2、实际费用65、1000→935，与回执精确相减一致；反馈在梁内，同物无重复比较/安装。
4. 公开comparison_changed通知：一次比较，不全量重读槽/选项或重绘机库，不付款/换装。

这些通知探查支持消费者刷新范围，不重新证明提供方所有依赖案例。日志保留本环境Fontconfig/cache只读、ALSA无设备并回退dummy等启动诊断；实际主场景/native成功、画面真实生成并正常exit0，未把环境警告删成清洁日志。

[静态保护依据](preserved-boundaries.json)逐字节核对 `_economy_display_changed`、`_process`、`_refresh_batch`、购买/安装/批量/回执解释等10函数与e3相同；main/Session/Equipment/Battle/战场与拾取视图/共享几何7文件相同。`_accept_result`只多一次随后被原完整tooltip覆盖的表现赋值；未知结果业务/停会话门控保持。四项旧保护的证明范围仍是原已通过版本；本次**未重复未知故障注入、提供方精准依赖全案、战场等比投影/拾取实测、活战全链性能**，不能把静态相同或四项0失败写成完整四保护复验通过。

## 未覆盖与交付边界

根审/独审/用户视觉验收未完成；当前候选没有整体品质通过口径。全合法配装/朝向/扫掠、Windows/DPI/其他桌面尺寸、长期性能/保存、自然发展开放流程未扩测。上方防御作用范围表达仍待审。宿主/导航/跨模块接入归整体组；main、业务、config、native、战场未改；不合main、不force、不操作Library/Space。缓存/原/tmp全部保留。
