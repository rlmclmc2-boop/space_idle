# Amount候选完成后的接替交接

- 原工作区：`C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate`；项目cwd为其`space-battleship/`。后继复用原目录，不克隆、不新建工作区。
- 当前分支：`feat/amount-safe-previews`；本交接前代码与验证固定版本：`7aabc373690bca1817bdfa96ef34b9118a0fca7f`，已普通推送并回读一致。当前交接提交只增加本文档，不变更代码。
- 保留179项已跟踪生成文件修改、262项未跟踪.uid/.import；不清理、不纳入提交。最后核对剩余全部为这两类元数据。
- main审批暂停，不重试合入或发布；候选仍待双审。不得把局部探针通过称为完整游戏验收。
- 本线程已实际压缩，当前自然项已完成；未开始下一制作批次。

## 已完成自然项

7aabc373在Reactor的_evaluate/_allocate/_distribute入口脱离状态后才写候选容量缓存，接受时才_adopt；不新增容量账本，不变更公式、钳制、均分或发布。原3264858b的10项失败原始日志、修复通过日志、原Amount/实际Session探针通过日志及入口check-only均见[清单](amount-preview-evidence/purity-manifest.json)，提交内源码/原始证据哈希已复核匹配。三个修复后检查退出0。详见[验证报告](amount-preview-implementation.md)。

## 后续唯一需求入口及尚未裁定项

共享几何提案只读需求入口为`space-battleship/docs/ui-redesign-plan/g1-internal/g2-battle-restoration.md`，固定前端版本`a3e05ea05418841821e2acfec6899b900d8d0b90`的“联合空间预算修订：两个条件提案，均待批准”节；可用git show读取。该入口是需求与条件方案，不是参数批准。后续仅做最小共享契约/权威来源提案，不先改真实几何、Excel、数值或规则，UI不得自行重排。

尚未裁定的占位身份：33011配置只有组级combatTier=elite，CombatSetup将其写入每个actor；visual_rank对elite组全员返回elite，仅部分家族具分级贴图。配置没有逐舰占位等级字段，不能按是否有elite贴图认定等级。18格依赖所选模型display_span/缺省1的条件语义，60格依赖全员elite为2×2的条件语义；二者均未成为批准规则，格面积也不能代替矩形装箱。需先核权威映射，无映射则列明待裁定的两种语义及影响，不擅改每舰等级或新尺寸。

已读路径供接替核对：src/combat_setup.gd::build_wave、scripts/enemy_visual_identity.gd::visual_rank、scripts/ship_geometry_convention.gd::formation_positions与battle_geometry；现阵型按数量排位，未消费占位等级。普通/精英/Boss占位要求见docs/game-design/art/modules/battle.md，实际尺寸与空白参数仍待批准。

无人机现状：src/systems/battle.gd从装备稳定id生成drone:id及generation，但武器muzzle仍为玩家原点；_sync_geometry对drone直接沿用该值。scripts/hyperspace_drone_visual.gd已有按稳定身份取视图与socket/root变换辅助，尚需追完整接纳链。提案应区分阵型位置所有者、无人机稳定身份、单一canonical变换/socket与native出生一致性，不仅移动显示位置、不将身体中心当真炮口。上述仅查证线索，未完成接口方案或运行验收。
