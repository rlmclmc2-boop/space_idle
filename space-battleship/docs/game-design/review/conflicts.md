# 待用户裁定的明显矛盾与覆盖缺口

[唯一入口](../README.md)。核对来源为拆分前 `main@7a85481`；下列原文按该提交保留，可用 `git show 7a85481:space-battleship/docs/game-design/<原路径>` 回读。C1/C4保留双边原文待用户裁定；C2/C3/C5依据已有权威校正文案，不再作为重选规则的问题。本轮不改数值或实现，不以归档视为已解决。涉及某项时只读取该项及双边来源；无关任务可继续。

## C1 无人机舰型容量：设计表与实际消费来源不一致（待裁定）

- 原文A：[03第1节](../03-progression.md#1-舰体槽位与升级)船型表，无人机容量按五舰列 `1、2、3、4、5`；[超空间快照](../reference/config/hyperspace_config.md)“舰型容量”同列该值。
- 原文B：[ship快照](../reference/config/ship.md)的 `para_5` 五舰为 `1、1、2、2、4`；[历史来源审计](../history/stage6-combat-audit.md#drone-capacity-source-conflict)原文：“`Campaign.ship_facts` returns para_5; Session passes that result to equip/preview/preset/ship-change operations”。
- 影响：驱逐、巡洋、战列、重型战列的可装备总数，以及换舰截断/预设/原生贡献。全局 `maximum_equipped=5` 与舰型更小上限可以并存，不是此矛盾。
- 待裁定：哪张舰型表应成为唯一权威，是否调整设计表/未消费表/实现；本轮均未改。

## C4 parent身份与保存水位：书面要求和已记录实现差异（待裁定）

- 原文A：[02第7节](../02-combat.md#7-衍生攻击和传说连接)：“派生攻击带父AttackId与类型。”[06第5节](../06-data.md#5-新存档格式与生命周期)规定 `next_ids:{encounter,actor,attack,emitter,drop}`。
- 原文B：[原11身份审计](../history/stage6-combat-audit.md#c10-identity-contract-audit)：“strange packets and counters do not retain a full parent attack relationship, and `next_ids.attack` is a carrier watermark.”原文亦明确“does not waive the design requirement”。
- 影响：派生溯源、ID语义、checkpoint兼容与审计观察口径；行为矩阵通过不证明完整表示契约等价。
- 待裁定：继续实现完整关系、修订书面要求或保留明确例外；不把历史“nonblocking”改成自动豁免，也不新增测试ID/保存字段。

## 已按现行权威校正文案（无需重新裁定）

| 原编号 | 已有权威与本轮修正 | 实现边界 |
|---|---|---|
| C2 炮台朝向 | 13要求保留真实目标修复，原11记录native每武器真实目标；05第6节删除“固定向前”泛称，明确真挂点/端口及活光束绑定目标 | 不重选朝向规则，不改代码 |
| C3 敌方倍率 | 原13的8.5节已经说明当前enemy_opening_*最终fit覆盖旧宽度；05第6节区分我舰有效倍率与敌方被覆盖的中间值，引用[参数参考](../reference/ship-scale.md#85-保留字段中已被覆盖或不再走当前链的倍率) | 不启用旧倍率、不改fit或配置 |
| C5 批量拒绝 | 03第1节及05动作表已有单槽整批/全体逐槽规则；05第3节将“失败原状”限定到当前动作/子动作，明确全体买不起跳过且不回滚此前成交 | 仅澄清已有适用范围，不改变支付/提交行为 |

## 覆盖/时效缺口（不是已确认的新规则）

| 项目 | 原来源与缺口 | 本轮处理 |
|---|---|---|
| F1 配置快照基线混杂 | 原09第0节目标值与其他历史main表值不同，覆盖表有29工作簿，但字段/小表只有26种；缺 battle_geometry、equipment_evolution、game_rules 的完整字段页 | 数值与字段原样迁出；三个缺页在09索引明示，不伪造采样；目标映射只留历史来源，实际字段/值从当前Excel查 |
| F2 迁移命令已过时 | 原09第0节仍要求“编译新配置前应应用本节目标”，含“新economy_rules.xlsx”“新battle_rules.xlsx”等；原11已经记录配置发布/实现完成 | 历史指令不作为现行必做步骤；当前应采用何种字段归并/目标清理仍需按06与实际配置逐项确认，未改任何目标值 |
| F3 测试规划与阶段执行口径 | 07规划 tests/excel、tests/run_cases；foundation入口记当前阶段仅编译及既有Amount测试；旧10/11列临时探针 | 不宣称所有规划已实施或旧脚本仍可用；入口区分“设计用例”和“当前运行命令”，不恢复旧runner/测试Excel |
| F4 来源断链 | 资产说明引用已不存在的旧美术文档/工具，原13已有清单 | 保留[来源时效说明](../art/sources.md#41-来源中的已知断链与时效)，不恢复旧依赖 |

03中“更换首槽类型使两类当前余量均为0是否立即死亡”仍是原有未决项，不因整理而判定。用户本轮明确的“战斗持续可见、无返回战斗关系”已直接更新13唯一导航原则，属于新指示覆盖旧表述，不列为未决冲突；旧代码/历史测试中的返回按钮仅是实现事实。
