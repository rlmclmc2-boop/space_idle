# A/B前端候选统一索引

规则与接口的唯一入口是[docs/game-design/README.md](../../game-design/README.md)。本页只索引当前前端候选、审查范围、资产与还原资料，不另立玩法/配置/接口规则。两方向G1组织审通过，**A/B尚未选择，整套品质及G2/G4/G9未通过**；浏览器有限响应不是完整游戏或持续提供者。**本轮主要布局/操作结构与具名反例已收敛，当前A/B候选可整体审阅并冻结，等待用户整体方向/参数反馈；不自发扩品质批次。**

## 当前实物与使用入口

统一演示为[index.html](index.html)，顶部切换 **A · 机舱现场** 与 **B · 作业编排**。A按模块进入现场；B按关联作业保留当前对象与路径；两者覆盖下表同一整套模块，并共享稳定战场，不能把一个代表场景当某方向完整交付。

当前演示源码为 **87ac154bbf553a39e75b224eb275e8b4496b6410**：在R5原源码`560a2dcfea9dc46567125e386d499c3e7fc433a8`上仅修复按效果折叠保持。[两小尾项来源/同流程记录](evidence/g2-quality-r5/fold-state-fix/README.md)分列新source与拍摄HEAD；原五结构原像素/动作归档仍为`78ae32d5f41d6cb3b4d61bdf29014451c01ba755`。两小尾项源码/证据`87ac154b` / **71ad5449591184c03db437d063b7ed8321096c60**已获根线程最终双审关闭；本次只同步结论，演示/资产/运行/配置均保持冻结。分支`design/g1-internal-organizations`，沿用`/workspace/space_idle/space-battleship`，未选UI未合main。

现环境HTTP入口为 `http://127.0.0.1:8766/docs/ui-redesign-plan/g1-internal/`。若需重启，在项目目录运行 `python -m http.server 8766 --bind 127.0.0.1`，复用同目录；无需克隆、构建或游戏进程。顶部“情境检查”和战况内部检查器是明确演示响应/压力样本入口，不是自然开放或真实结算证明。

主设计物理客户区1440×900。当前P3候选为632×900贯通战场与808px模块舱，模块切换/收起默认保持R/T；572×960是逻辑世界，不自动裁切完整视觉。P3观看体量改善可以继续，但真实尺度/占位来源/布点参数未批准，1280×800与1600×900仅历史边界样本，不扩多尺寸任务。旧G1/P1/P2投影仅为历史诊断，不能据此实施参数。

| 系统 | 当前入口与工作点 | Godot还原与当前品质补充 |
|---|---|---|
| M1战场/航程/资源 | 常驻战场、战况/装配、盾甲/驻守/拾取；五舰及编队检查为显式压力样本 | [战场/共享变换/接线缺口](g2-battle-restoration.md)、[R4护盾与敌炮台材质](g2-quality-r4.md) |
| M2舰体/装备 | 装配台、五舰比较、全槽升级、属性与实战四子路由；当前槽位独立动作 | [装备实际/候选/回执与接线](g2-equipment-restoration.md)、[R2装配舱](g2-quality-r2.md)、[R5唯一导航](g2-quality-r5.md) |
| M3反应炉 | 核心—主管—设备、整组草稿/实际供能、预设与精确金额 | [根布局/设备锚点/还原](godot-restoration.md)、[已审金额设计对齐](g2-budget-contract-alignment.md)；保留设备—管路—操作关系 |
| M4科研 | 工厂/设备实际进度与投入、按需预算台、逐资源/持续比例、设备选择/实际人员 | [工厂资产与公开绑定](godot-restoration.md)、[R1同空间装配](g2-quality-r1.md)、[R3常态/预算分层](g2-quality-r3.md) |
| M5强化 | 六效果顺序/路径定位、当前完整效果/节点、A/B模态与购级 | [强化还原/响应边界](g2-enhancement-restoration.md)、[R5主次](g2-quality-r5.md) |
| M6人员 | 名册、实际占用、派遣候选、目标/容量/释放与返回 | [殖民与人员还原](g2-colony-restoration.md)、[R1规则按需收纳](g2-quality-r1.md) |
| M7星球 | 球体/轨道设施、施工/缺人/ready/已领、探索与人员/重铸入口 | [星球/关联人员还原](g2-colony-restoration.md)、[R3轨道底座](g2-quality-r3.md) |
| M8星系 | 单一地图对象、选中发展台、缩放/拖动/记忆、建设/升级/贡献 | [星系还原/模型来源](g2-colony-restoration.md)、[R3地图与发展关联](g2-quality-r3.md) |
| M9路线/任务/回执 | `hyperspace/routes`，手动与在线任务分别绑定run/route/奖励；开始、停止、审阅/领取 | [任务还原](g2-hyperspace-tasks-restoration.md)、[R5紧凑路线入口](g2-quality-r5.md) |
| M9仓储/编队/挂设/保护/预设/过滤/材料 | `warehouse`/`formation`及仓库对象入口；密集浏览、持续所选、装卸/保护、五条件与分享审阅、兑换 | [超空间还原](g2-hyperspace-restoration.md)；具体子路由由现演示导航进入 |
| M9改造/传说图鉴 | `hyperspace/forge`与`legends`；当前原形态/词缀、费用/保护、预览/取消/实际结果 | [改造还原](g2-forge-restoration.md)、[R5基础机体预览身份与缺失范围](g2-quality-r5.md) |
| M10保存/设置/危险事务/档案 | 保存六态、目录/备份、偏好、重铸/导入/新游戏损失审阅；手册/敌情/已见已读/统计 | [维护/档案/事务还原](g2-maintenance-restoration.md)、[R2主动作与恢复](g2-quality-r2.md)、[R5状态轨](g2-quality-r5.md) |

还原阅读顺序：本页定位模块 → 模块还原资料的后续增补及相应R1–R5品质补充 → 从唯一规则入口定向读取该模块现行契约。旧还原稿的首批尺寸/“待补接口”是当时快照，不覆盖后续固定候选或后端已审版本；不沿旧文字恢复已撤玩法，也不把候选接口写成main已有。

<a id="quality-review-status"></a>

## R1–R5具名审查状态

以下只记录根线程转交的固定双审具名结论；“关闭”仅针对该反例/目标，不扩为整批、全部动态/组合或真实运行通过。R5五结构目标及折叠保持/记录范围两尾项均获最终双审具名关闭，不重开这些结构或修复项。结论是主要布局/操作结构与本轮反例收敛、可整体审阅，不是完整持续运行前端或正式游戏交付。

| 批次/资料 | 当前已获结论 | 仍开放或已转后续 |
|---|---|---|
| [R1场景层级](g2-quality-r1.md) / [同版对照](evidence/g2-quality-r1/README.md) | 有真实改善，可继续P3；B减重及船员规则折叠保留 | R1原科研预算遮挡/设施关联目标已由R3具名收口；ready视觉退化由R2关闭。不能再将这些列为当前初审待办；整套品质仍开放 |
| [R2模块推广](g2-quality-r2.md) / [同版对照](evidence/g2-quality-r2/README.md) | ready选中/未选中琥珀退化关闭；装配舱、强化顺序、保存主动作有实质改善；R2/R3 source/capture澄清关闭 | 这些尾项的R5五结构目标及两小尾项均具名关闭；不扩大为完整持续前端或整套品质通过 |
| [R3科研/星系/星球](g2-quality-r3.md) / [同版对照](evidence/g2-quality-r3/README.md) | 科研常态/预算分层、星系同一地图对象关联、星球轨道底座结构反例关闭 | 不重开已解决布局；真实动态场景、持续提供者及整体观感仍不由此通过 |
| [R4战场材质](g2-quality-r4.md) / [同版对照](evidence/g2-quality-r4/README.md) | 圆润轻薄盾与敌炮台压白材质代表稿可继续，未见新几何/功能退化 | 不是M1完整、全姿态/全部编队/动态材质或G9批准；P3参数及几何权威仍未批准 |
| [R5统一收敛](g2-quality-r5.md) / [同版对照](evidence/g2-quality-r5/README.md) | 装备唯一导航、路线占高、改造基础机体身份/范围、强化主次、保存状态轨五结构目标均具名关闭 | [两小尾项](evidence/g2-quality-r5/fold-state-fix/README.md)：保留各效果折叠状态；第25/56步按真实effect选择修正范围，未证明锁定节点交互。两项在`87ac154b` / `71ad5449`最终双审关闭。记录范围纠正不等于锁定节点交互通过；当前候选冻结，整套仍不通过 |

此前M2完整身份/paidLevel/模式/预算匹配、未知保持、单槽钱包/材料/actual回执、MAX NoChange模式范围，以及ready完整人员响应/批量已成交—跳过—失败—未执行四类反馈均已定向关闭；保留保护，不作为新复测队列。其范围始终是有限响应，不是任意连续操作交付。

| 批次 | 固定演示源码 | 首次同版归档 |
|---|---|---|
| R1 | `57ae32c3dd18d59ac19a7c953fe10b2d14b1d766` | `e474f9f963c8cba63c346bcfb7a0d2829d19c127` |
| R2 | `2cb2a5f2a74eef872bfe7f92edeb612cedcaf9e7` | `5fee3a6aa9ed988c5d375273e8bfe68636308008` |
| R3 | `0aa504d085aeaaa4ab7352babe9614fccfe0d36a` | `449fd843d4b21cbdf9d1c5f186ffa9e172e06532` |
| R4 | `90d9f3a25516baf67d9508f0d8bf2d86a3c8d63f` | `0aec2d937b06370b5ec4abddf3f5f7a4ea180ae3` |
| R5原五结构 | `560a2dcfea9dc46567125e386d499c3e7fc433a8` | `78ae32d5f41d6cb3b4d61bdf29014451c01ba755` |
| R5两小尾项 | `87ac154bbf553a39e75b224eb275e8b4496b6410` | `71ad5449591184c03db437d063b7ed8321096c60` · [来源/同流程](evidence/g2-quality-r5/fold-state-fix/manifest.json) |

R2/R3/R4的后补来源澄清及base/source/hash索引汇入`78ae32d5`，不改原PNG/动作，不伪造拍摄时HEAD或声称独立重跑。各证据入口的manifest关联源码/图hash，operations是制作方逐步记录；[R5 capture-source](evidence/g2-quality-r5/capture-source.json)与[采集归属工具](tools/capture-source-context.py)将拍摄HEAD、工作树字节与固定source分开，固定后核对Git对象再绑定。制作者浏览器证据不是独立审运行，也不是Godot/游戏/文件验收。

## 资产与安装来源

规则中的来源仍由[唯一入口](../../game-design/README.md)定向到S项；下表仅把本候选实际复用/派生记录与还原资料接起来。证据整屏不可替代独立资产。R1–R5未新增资产；更早本目录设备SVG及GLB派生图仍是候选设计资源，不能扩大为全部素材已获最终品质批准。

| 范围 | 来源与可追溯记录 | 使用边界 |
|---|---|---|
| 舰体/装备/炮台 | [S2](../../game-design/art/sources.md#s2) / [S4](../../game-design/art/sources.md#s4)、[舰体来源](../../../assets/ships/README.md)、[装备预览来源](../../../assets/ui/ships/README.md)、[场景安装](art/scene-installation.json) | 原alpha/挂点/炮口与资产身份保留；装备预览不推导战斗尺度 |
| 反应炉 | [候选SVG与源边界](art/reactor/source-bounds.json)、[Godot设备安装](godot-restoration.md#2-反应炉的可替换设备装配) | 设备/主管/读数分层；设计SVG及安装记录不冒称Godot已导入/最终批准 |
| 科研 | [原工厂资产](../../../assets/ai_tech_factory/README.md)、[安装记录](art/scene-installation.json)、[R3装配](g2-quality-r3.md) | 背景/八设备/探针独立复用，不把整屏烘焙为设备 |
| 强化/人员/星球 | [S7](../../game-design/art/sources.md#s7) / [S8](../../game-design/art/sources.md#s8) / [S9](../../game-design/art/sources.md#s9)、[强化还原](g2-enhancement-restoration.md)、[殖民/人员还原](g2-colony-restoration.md) | 原共享强化身份、人物事实、球体/云层/设施；轨道底座是2D呈现，不新增玩法距离 |
| 星系 | [原GLB来源](../../../assets/galaxy/v3/README.md)、[本候选派生来源/hash](art/galaxy/render-sources.json) | 浏览器PNG为现GLB派生，不恢复退役建筑PNG、不替换运行GLB |
| 无人机 | [S11](../../game-design/art/sources.md#s11)、[四基础GLB派生来源/hash](art/battle/drone-sources.json)、[R5预览范围](g2-quality-r5.md) | 基础机体与战场同源；改造预览未覆盖饰件/究极结构/toon，不证明canonical/真实炮口 |
| 保存/档案/全局壳 | [S1](../../game-design/art/sources.md#s1) / [S12](../../game-design/art/sources.md#s12)、[维护还原](g2-maintenance-restoration.md)、[根Control/变换](godot-restoration.md#1-根画布挂载与生命周期) | 实时文字/状态/事务保留为控件；失败恢复与危险损失不藏进教学 |

## 真正剩余与接续条件

1. **持续提供者与真实接线。** 后端M9/M10发布正等待具体确认，不能把待确认发布当已发布/已合main或已接线。现浏览器以有限owner响应工作，未覆盖组合继续待刷新。后续必须由现所有者查询→命令接纳→actual/钱包/材料→关联刷新接入GameSession/Godot/native，不能补UI业务引擎或增加样本数量冒充持续操作。真实文件/备份/导入/离线、长期推进、动态AI/长光束、音效及DPI/输入/性能仍未交付。
2. **共享几何与参数。** P3真实尺度、逐舰占位权威、统一布点与无人机稳定身份/canonical根/native炮口仍待对应批准/接纳；已有只读接口或材质改善不授予改参数/运行权限。后端已审候选不能标为main已有。
3. **方向选择与整体门槛。** A/B未选，G2/G4/G9及整套品质未通过。本轮已可整体审阅，冻结当前候选，等待用户整体方向/参数反馈；不重开已关闭的具名结构/反例/有限响应，不自发扩新品质批次，不以更多样本量替代真实接线或外推完整游戏通过。

当前交接与后续根线程结论从[HANDOFF.md顶部](HANDOFF.md)读取；其下旧流水、固定批次文档和Git历史保留当时边界，不能用旧“仍待初审”覆盖本页具名结论。本次仅同步最终具名结论与冻结状态；保留A/B入口、资产来源、Godot还原及既有原像素/同流程证据，不改演示/资产/运行/配置，不新增采样、独立复测或游戏运行。
