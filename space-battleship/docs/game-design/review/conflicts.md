# 已裁定修正、待定问题与覆盖缺口

[唯一入口](../README.md)。核对来源为拆分前 `main@7a85481`；下列原文按该提交保留，可用 `git show 7a85481:space-battleship/docs/game-design/<原路径>` 回读。C1已按用户裁定修正消费来源，双边原文保留作来源记录；C4仍待裁定；C2/C3/C5依据已有权威校正文案，不再作为重选规则的问题。除C1已裁定修正外，本页其余整理不改数值或实现，不以归档视为已解决。涉及某项时只读取该项及双边来源；无关任务可继续。

## C1 无人机舰型容量：原实现误读占地字段（已裁定并修正）

- 原文A：[03第1节](../03-progression.md#1-舰体槽位与升级)船型表，无人机容量按五舰列 `1、2、3、4、5`；[超空间快照](../reference/config/hyperspace_config.md)“舰型容量”同列该值。
- 原文B：[ship快照](../reference/config/ship.md)的 `para_5` 五舰为 `1、1、2、2、4`；[历史来源审计](../history/stage6-combat-audit.md#drone-capacity-source-conflict)原文：“`Campaign.ship_facts` returns para_5; Session passes that result to equip/preview/preset/ship-change operations”。
- 影响：驱逐、巡洋、战列、重型战列的可装备总数，以及换舰截断/预设/原生贡献。全局 `maximum_equipped=5` 与舰型更小上限可以并存，不是此矛盾。
- 归因：正确的舰型容量权威表原已存在；这是实现消费字段错误，不是两个权威规则冲突。
- 用户裁定：五舰无人机容量依次为 `1、2、3、4、5`。现行权威是[超空间配置工作簿](../../../config_excel/hyperspace_config.xlsx)的“舰型容量”表（`hull_id/capacity`）；该表原值已符合裁定，未修改工作簿。
- 实现同步：`Campaign.ship_facts().drone_capacity` 改为消费上述舰型容量表；配装、预设、成长/改造刷新、换舰截断与原生配装校验继续使用该公开事实。合法数量须同时满足舰型容量和独立的全局 `maximum_equipped`，不把全局最大值当成每舰容量。
- 字段区分：[舰型工作簿](../../../config_excel/ship.xlsx)的 `para_5` 是“战舰占地”，`para_6` 是“同种武器上限”，均不作为无人机容量且未修改。上述历史快照及原文B保留原样，不再据旧消费关系定义当前规则。

## C4 parent身份与保存水位：书面要求和已记录实现差异（待裁定）

- 原文A：[02第7节](../02-combat.md#7-衍生攻击和传说连接)：“派生攻击带父AttackId与类型。”[06第5节](../06-data.md#5-新存档格式与生命周期)规定 `next_ids:{encounter,actor,attack,emitter,drop}`。
- 原文B：[原11身份审计](../history/stage6-combat-audit.md#c10-identity-contract-audit)：“strange packets and counters do not retain a full parent attack relationship, and `next_ids.attack` is a carrier watermark.”原文亦明确“does not waive the design requirement”。
- 影响：派生溯源、ID语义、checkpoint兼容与审计观察口径；行为矩阵通过不证明完整表示契约等价。
- 概念区分：直接父攻击身份表示一次派生的直接来源；完整祖先历史是可沿多代追溯的记录，二者不等同。触发许可决定特定来源能否触发某个效果及其次数，不由是否存父对象自动决定。保存水位是ID序号的持久状态，不等于将运行期父链写入存档。
- 当前状态：C4仅作只读专项审核，直接父身份的最小必要范围、是否需要完整祖先历史、各类触发许可及保存水位语义分别待核；不将所有派生一刀切处理。本次不改战斗实现或保存格式，不把历史“nonblocking”改成自动豁免，也不新增测试ID/保存字段。文档拆分候选通过双审不代表全规范语义已核清。

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

## D9 配置身份与运行配置结构（本次发现，待核实）

- 原文 A：[06 第4节](../06-data.md#4-configbundle运行结构)要求 `schemaVersion/semanticHash/sourceManifestHash` 的 ConfigBundle，且“一份会话固定使用一个 configHash”；第5节封套含 `configHash`，加载要求 ConfigBundle 匹配。[11 原记录](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/docs/game-design/11-stage6-contract.md)仍写“配置指纹不匹配保持明确拒绝”。
- 原文 B：[首阶段决定记录](../../knowledge/tasks/foundation-restart.md)记录用户确认“删除保存与配置哈希的绑定”，提交 `a65327c25adb0d752fc5c393f77703497ab1882a` 移除了保存封套/读取中的配置身份；同页另记删除 ConfigBundle，配置直接加载 `generated/config.json`。这不是单凭代码猜出的意图。
- 后续事实：main 的 foundation 命令已使用 `config_tools/production_manifest.json`；早期删除输入清单的决定不能无条件解释为永久禁止后来的配置发布校验。保存层去耦是否同时废止06全部运行配置结构要求，现有材料不足以完整判定。
- 影响：是否把 configHash/ConfigBundle 重新加回保存协议、是否重建运行配置包装、如何解释校验与旧存档拒绝；本次不更改协议、代码或Excel。
- 必要问题：配置身份/ConfigBundle 旧设计是否全部退出当前规范，还是仅保存层去耦、其余设计仍保留？请补最新用户裁定或固定 Git 来源。答复前保留原条款并标记争议，不从任一侧新增实现任务。

## D10 B01分配提交语义（待裁定）

- 原文A：[M3@73ee](https://github.com/rlmclmc2-boop/space_idle/blob/73ee39c08b03ff6a4845f7d317baf4cdedc92874/space-battleship/docs/game-design/art/modules/reactor.md)：“只有一套整组草稿确认/还原”；V3要求“未确认草稿不改变工作动态”。[反应炉契约§9.2](../contracts/reactor.md#92-reactor整组分配预览)仍区分预览与一次接纳。
- 原文B：[B01同提交入口](https://github.com/rlmclmc2-boop/space_idle/blob/73ee39c08b03ff6a4845f7d317baf4cdedc92874/space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md)记录用户批准B01、四路集中控制；运行记录为拖动10%即Owner接纳、再次超额拒绝并回到已接纳10%。该行为事实不能自行证明用户取消了确认/还原。
- 已确定：集中下台替代旧每设备独立操作面板；上方/下方一起改。未确定：提交语义是否随新批准改变。
- 必要问题：B01分配采用拖动/均分立即应用，还是保留整组草稿确认/还原？影响提交时机、取消和动态来源；答案前保留双方文字，不改代码或默认恢复旧控件。其他结构/材质工作可继续。

## D11 星球设施承载与六类适用范围（待核）

- 原文A：[M7@e7ff](https://github.com/rlmclmc2-boop/space_idle/blob/e7ff7673eea06611ca65337c58f32e248115cc13/space-battleship/docs/game-design/art/modules/planet.md)写“资源工厂（现有精炼厂）与工坊在星球表面”，随地貌自转；并称用户在R5造型后确认。
- 原文B：[六类入口@e7ff](https://github.com/rlmclmc2-boop/space_idle/blob/e7ff7673eea06611ca65337c58f32e248115cc13/space-battleship/docs/game-design/art/modules/planet-six/README.md)记录批准B实体承重脊固态完整态/独立建造闭环，球环独立转；同时明确“气态/恒星实体带专属概念变体尚未制作，此次运行使用共用主体与既有外观”。[R17](../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)正制作四设施共同根壳。
- 可确认：固态当前制作按R17批准代表，不回退旧贴地/独立平台；六类专属设计和实机没有整体完成。
- 必要问题：旧M7地表分工是否整体退出所有六类，或只在获准固态代表中被覆盖？其他类别的承载/采集端是否已有固定新决定？不以共用运行模型代替设计授权；确定的固态制作继续。
