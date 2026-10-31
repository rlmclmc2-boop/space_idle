# 2026-10-31 设计文档与入口整理记录

范围为文档，独立分支 `docs/design-entry-cleanup-20261031`，基底 `main@e3b38d7b6d8256f6031e1b086c7db7812b6a441f`。未改游戏代码、资产、Excel、存档、缓存或他人WIP，未运行游戏、性能或独立复测，未合main、未创建子任务。规则仍只在原game-design体系维护，线程文件交接仅Git。

## 固定来源与权威

[11](../11-stage6-contract.md)记录各组完整SHA、源码/文档区别与证据覆盖。核对装备d799、反应堆73ee、星球e7ff及收尾新增a40、整体824与制作中新增6e0/059ac、后台ad4c/f924；未将不同分支视作同一版。仓库两级AGENTS、foundation与doc-compact/token-opt已读。

- 全局规范采用整体分支已有13最新用户决定，补6e0公共运行材质段；数字/资源/透明/两键/整页判断仍只在13。14沿后台已有分册拆分，补公共交换边界，不另造契约。
- 01/06同步后台现有资源整数设计；03/05同步装备分支明确记录的用户免费换装/即时切回决定，不从代码现状推导规则。
- 星球原协调最新a40的54行结构保留（覆盖e7ff），仅标明固定文档快照并将跨分支证据固定；07:31站/炉失败试装已撤回的新状态已同步，本线程未访问或改写其未提交现场。
- 当前正式入口链：game-design/README → 11固定版本/各组入口；13→单个M/V；14→单个contracts分册。foundation仅命令，07仅方法/设计场景，历史不默认加载。

## 退出当前生效入口的内容及依据

| 内容 | 依据与处理 |
|---|---|
| 整体旧52c/packed组合、R1/R2、待用户R3、a83阻断 | 后续R3认可/6e0公共源与f924修复已明确；旧过程完整归档，不外推为新组合通过 |
| 反应堆旧整图/mask舞台与旧视觉通过、等新图才恢复 | 用户返修二要求可组合core/设备/实体管，73ee限定新证据；旧图/片/性能保留为历史，未删除文件 |
| 装备旧静态容量提案、10秒锁/二级确认、缺材质/缺长值、已定位尚未修和旧待用户 | d799/22395及6e0的明确后续决定/候选覆盖；旧完整139行留HISTORY，未把排版实施/部分整数接入写成R3通过 |
| M2/M3反复追加的“当前状态”、星球R2/R16路由 | 当前组入口替代重复台账；M2/M3只保规范，M3资产元数据原文单独迁出，旧锚点保路由；M7保留未完制作范围，D11按补回的用户原话关闭旧分工冲突 |
| 多方向G0–G5旧执行阶段、同页G0已过/未过 | 原文移ui-redesign-plan/HISTORY；当前已获准制作从11进入，不重开旧比较阶段 |
| foundation旧阶段“唯一测试/当前不运行”、早期压缩停工指令 | 当前任务授权与后续各分支制作已覆盖旧阶段；原文完整留历史，命令保留，不从本整理新增运行范围 |
| 测试设施/从零六阶段重建、旧拆分报告C1待定 | 07保设计场景，旧设施/顺序归档；拆分报告标历史，C1以已有裁定为准 |
| 碎片0.01落账/普通资源.0展示、泛化余额不足禁用、装备旧换装锁残句 | 按已有资源整数/费用反馈/免费即时换装权威同步；倍率/计时/工作量和其他冷却不改 |

归档保留原正文（相对链接固定或修正），来源可由原SHA逐字节恢复。未删除历史图、视频、日志、脚本或资产；无需复制这些二进制到文档分支。旧目录路径仍可到达当前入口/原固定来源，不依赖“末三节”。

## 默认阅读规模

| 入口 | 来源行数/字符 | 当前行数/字符 |
|---|---:|---:|
| 装备当前页 | 139 / 13,730 | 35 / 3,191 |
| 反应堆B01 | 265 / 44,604 | 32 / 2,341 |
| 整体公共壳 | 579 / 107,725（824） | 34 / 3,513 |
| 星球R17 | 54 / 3,144（a40） | 56 / 4,999（固定链接变长；保留原协调内容） |

字符含Markdown链接，行数不等于屏幕高度。三份堆叠入口的过程记录约16.6万字符已移出默认阅读；历史只按具体问题查询，不要求从头读。

## 问题处理与剩余裁定

[D9](conflicts.md#d9-配置身份与运行配置结构本次发现待核实)暂停裁定：初稿将二手“用户确认”扩大成设计依据，且漏查第6阶段重新引入，是核查错误。主线程补回原消息后，已分别记录去查询包装、去当时保存绑定的授权范围，以及0822763b/9490a580/51d3bdf3重新引入的代码与文档依据。main及五个制作/后台分支仍保存hash并由会话严格匹配；未核到重新引入的后续用户确认。当前只补通俗背景/选择影响，05/06争议正文不删改，不自动扩成代码任务。

[D10](conflicts.md#d10)已关闭：主线程补回2026-10-29用户“确认和还原都不需要”和后续数量循环键＋独立购买原话。移除现行M3、契约与B01入口的旧确认要求；只读预览、提交时校验与一次接纳边界保留。

[D11](conflicts.md#d11)旧分工冲突已关闭：后续用户批准环带/设施整体、球环独立转/探索船另轨，要求修正后环断裂，并允许按需适配或独立设计各星球。旧地表强制分工退出，不强制六类同形或每类一套；具体接点、采集端、变体与实机仍属未完制作，未因方向或共用运行模型而通过。原话集中保存在冲突条目，短入口不恢复全长过程。

既有C4直接父身份/完整祖先历史/保存水位，以及03首槽换型双零是否立即判死仍未决，未因归档关闭。D9已撤回原笼统裁定问题，后续授权来源由主线程核原对话；D10/D11依据补回的明确原话关闭，不重复提问。其他整理已完成。

## 引用核查与交付边界

- 核查本次所有修改/新增Markdown的本地路径、文档锚点、仓库固定Git对象链接；历史必要的7个精确提交已正常取回核对象，不仅凭链接字符串判断存在。
- 修正原G0旧第7节锚点；反应堆生成/装配脚本链接少一层目录；整体旧分支并不存在的星球/反应堆/资源跨组本地路径改指所有者固定提交。历史通过的版本范围没有随链接修复升级。
- 归档原文与固定来源逐项对照（允许目标链接迁移）；game-design/contracts沿后台原有拆分逐份保留，不丢模块接口、接纳/通知/Amount边界。
- 初稿`90095df31087519338861a67f9858bef1e2b8dd0`核查57份Markdown：472个本地引用、788个固定Git对象引用可解析，本地路径/文档锚点/固定对象缺失均为0；`git diff --check`通过。六份完整历史和反应堆元数据原文保全；14:52三张原R3图在42ea与6e0的Git blob相同。不运行游戏，不声称截图/视频重新审过或性能/画面通过。

- 原话补正后再次核查全部57份Markdown：475个本地引用、790个固定Git对象引用，缺失路径/锚点/对象均为0，`git diff --check`通过。重新fetch六个源分支，版本未变；D9仅静态读取保存/加载/编译器和历史差异，未执行游戏或测试。

## 文件清单

- `space-battleship/docs/game-design`：`01-runtime.md`、`03-progression.md`、`05-architecture.md`、`06-data.md`、`07-verification.md`、`08-decisions.md`、`11-stage6-contract.md`、`13-art-interaction.md`、`14-ui-contracts.md`、`README.md`
- `space-battleship/docs/game-design/art/modules`：`crew.md`、`equipment.md`、`planet.md`、`reactor-asset-contract.md`、`reactor.md`
- `space-battleship/docs/game-design/art/modules/planet-six`：`README.md`
- `space-battleship/docs/game-design/art`：`open-items.md`、`sources.md`
- `space-battleship/docs/game-design/contracts`：`battle.md`、`crew.md`、`enhancement.md`、`equipment.md`、`galaxy.md`、`hyperspace.md`、`persistence.md`、`planet.md`、`reactor.md`、`research.md`、`resources.md`
- `space-battleship/docs/game-design/history`：`verification-planning.md`
- `space-battleship/docs/game-design/review`：`conflicts.md`、`design-entry-cleanup-20261031.md`、`document-split.md`
- `space-battleship/docs/knowledge/tasks`：`foundation-restart.md`
- `space-battleship/docs/ui-design-candidate`：`HISTORY.md`、`README.md`、`assets-and-sources.md`、`design.md`、`validation.md`
- `space-battleship/docs/ui-redesign-plan`：`HISTORY.md`、`README.md`、`g0-frontend-constraints.md`、`g0-system-coverage.md`
- `space-battleship/docs/ui-redesign-plan/reactor-image-design/content-v1`：`README.md`
- `space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone`：`HISTORY.md`、`README.md`
- `space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision`：`README.md`
- `space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept`：`HISTORY.md`、`README.md`
- `space-battleship/docs/verification/planet-single-side-godot`：`README.md`
- `space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine`：`README.md`
- `space-battleship/docs/verification/reactor-centered-godot`：`README.md`
- `space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign`：`HISTORY.md`、`README.md`
- `space-battleship/docs/verification/reactor-centered-godot/evidence/ship-hub-r9`：`README.md`
- `space-battleship/foundation`：`HISTORY.md`、`README.md`
