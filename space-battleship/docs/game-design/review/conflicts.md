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

**暂停裁定与争议条款删改。** 用户指出“我之前从未做过这个决定,补充背景”。初稿把二手交接中的“用户确认”直接当成完整设计授权，并漏查第6阶段已重新引入配置指纹，这是本次核查的错误；不得用该记录反驳用户。主线程随后找回原消息，支持的精确范围如下，不能扩大成“所有配置校验都删除”。

### 原设计目的与原始对话范围

- [原06设计@e3e5e92b](https://github.com/rlmclmc2-boop/space_idle/blob/e3e5e92b82e22d8fdca63ff11f59ebfc5dbe7e51/space-battleship/docs/game-design/06-data.md)把Excel编译结果包装成含索引/来源的ConfigBundle，并在存档写configHash、载入检查一致性。目的是让会话用同一套规则，避免换表后旧ID/进度被错误解释；“查询包装”“文件完整性”“配置兼容策略”是三件不同的事。
- 用户原消息 `Sentinel_da0fdca3e4a08191af3fe519639ded13`，2026-10-24T17:56:55Z：“ConfigBundle：加载数据包并提供查询。 这也没用”。支持移除额外数据包查询包装，不能据此推导不用校验Excel、ID、金额或坏存档。
- 助手原消息 `Sentinel_84c92ffc4ca8819186ac3d9ab0ac6213`，2026-10-24T18:26:22Z，提议“① 删除保存与配置哈希的绑定”，理由为改配置可能拒绝旧档、新导入不生成哈希，并说明“文件保存层应管文件完整性，不应决定游戏配置是否兼容”；请求“①删除，②③④保留”。用户 `Sentinel_2a63d9f07fd08191a498c80d09b3403b`，2026-10-24T18:28:03Z 回复“确认”。这些消息由主线程从原聊天取回后传入本线程；不是本线程直接检索原room所得。
- 精确授权：去掉查询包装和当时提议的保存绑定。原话没有逐项批准删除所有配置校验，也没有明确给出新的跨配置存档兼容算法。[foundation-restart](../../knowledge/tasks/foundation-restart.md)只是二手摘要，必须与以上原文范围一起读。

### 删除及重新引入的代码时间线（只读核查）

| 固定提交 | 实际变化及文档依据 |
|---|---|
| [de0c3f9c](https://github.com/rlmclmc2-boop/space_idle/commit/de0c3f9cb96030d14096a6ea4c7449bea3f49a3f) | 删除`foundation/host/config_bundle.gd`与当时编译/schema设施，改普通JSON读取；此提交早于a653，不能把包装删除算成a653的范围。 |
| [a65327c2](https://github.com/rlmclmc2-boop/space_idle/commit/a65327c25adb0d752fc5c393f77703497ab1882a) | 仅3文件：`save_files.gd`与两份说明。删除SaveFiles构造/读取参数中的config_hash、封套configHash、后台任务配置字段与相等判断；保留checksum/payloadHash、格式、代际、A/B和写入失败处理。二手“用户确认删除”文字也在此提交加入。 |
| [0822763b](https://github.com/rlmclmc2-boop/space_idle/commit/0822763bd9f2779dbda0faec1e3643b1bc888f0e) | 2026-10-26开始第6阶段：SaveFiles.request重新接收config_hash，写封套且检查64位十六进制形状；没有恢复构造/读取时的配置相等参数。同提交[11交接](https://github.com/rlmclmc2-boop/space_idle/blob/0822763bd9f2779dbda0faec1e3643b1bc888f0e/space-battleship/docs/game-design/11-stage6-contract.md)援引03/05/06/07，明确“configHash随封包保存；候选会话验证它与当前配置相同”。 |
| [9490a580](https://github.com/rlmclmc2-boop/space_idle/commit/9490a580d2c5c84a0f75a131d26c9f4b5930717f) | GameSession接上真实保存/导入：保存时计算磁盘配置文本hash，候选加载不一致即ConfigurationMismatch。对应11继续引用原06保存规则；这是业务会话层恢复严格匹配，非SaveFiles自己决定兼容。 |
| [51d3bdf3](https://github.com/rlmclmc2-boop/space_idle/commit/51d3bdf3160b4a5e5c382cdff25cb05b694b5f3d) | 改为保存会话初始化时固定的hash，候选初始化后再核一次，防止运行中改磁盘文件使存档错标新配置；同时补探针与实现记录。本次只读这些历史证据，未运行探针。 |

重新引入可核的文档依据是仍保留的06设计和第6阶段11交接；相关提交正文、上述仓库记录没有附后续用户重新批准严格匹配的原消息。本线程未核到该后续确认，不能断言另一个对话中一定不存在，也不能把实现/测试通过当用户授权。是否另有后续裁定仍需主线程核原对话，不再次笼统询问“全部删除还是全部保留”。

### 当前实际用法与选择的影响

已重新fetch并只读核对[11固定来源](../11-stage6-contract.md)中的main、装备、反应堆、星球、整体、后台六个版本：以下机制均存在；这不是这些分支的组合运行验收。

- [编译器@main](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/config_tools/compile.py)输出普通表JSON，sourceHash/semanticHash/outputHash放编译报告；并没有恢复旧ConfigBundle查询对象或06所列完整包装。
- [GameSession@main](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/game_session.gd)直接解析JSON、初始化业务模块，保存启动时配置文本的SHA-256；加载与导入都做严格文本hash匹配并校验候选领域状态。[SaveFiles@main](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/foundation/host/save_files.gd)构造仍只传目录，负责封套与完整性，不自己比当前配置hash。
- 通俗区别：checksum/payloadHash回答“存档有没有损坏”；configHash严格相等回答“是不是完全同一份配置文本”，并不能回答“不同配置是否仍能兼容”。当前即使只改JSON空白、数值规则不变，也会因文本hash不同拒绝旧档。这是静态代码推出的行为，本次未跑游戏验证。

以下仅说明后续策略的两种影响，**不请求立即选择、不替用户裁定、不授权实施**；两者都不要求恢复ConfigBundle查询包装，也不取消文件完整性与领域合法性校验。

| 策略 | 玩家与实现影响 |
|---|---|
| 保留当前严格同配置加载 | 配置文本不同时拒绝加载/导入；可避免未知跨版本解释，但平衡数值或纯格式更新也可能让旧档无法打开。若采用此策略，需明确告知这种兼容限制；当前已有实现不等于用户已批准。 |
| 按业务兼容性加载，取消“hash不同必拒绝” | 可允许兼容的数值/格式更新继续旧档；仍须校验ID、进度、金额、占用等，结构变化必须明确迁移或拒绝。仅删相等判断不等于完成兼容，具体边界尚需设计；hash可作为诊断记录是否保留另行说明。 |

现阶段05/06争议正文保留，不自动删除/恢复结构或修改代码；本项只补事实、原始证据和差异背景。

<a id="d10-b01分配提交语义待裁定"></a>
<a id="d10"></a>

## D10 B01分配提交语义（已按用户原话关闭）

- 旧要求：[M3@73ee](https://github.com/rlmclmc2-boop/space_idle/blob/73ee39c08b03ff6a4845f7d317baf4cdedc92874/space-battleship/docs/game-design/art/modules/reactor.md)的“整组草稿确认/还原”和“未确认草稿不改变工作动态”属于被覆盖的UI流程，不再作为恢复控件的依据。
- 裁定来源：主线程在2026-10-31补回本对话用户原话（2026-10-29）：“确认和还原都不需要,但要有升级*10和升级*max.字体和ui控件都太丑,改.跟装备的ui感觉统一”。随后用户明确：“一个按钮切换x1,x10,xmax,另一个按钮负责购买”。[现有反应炉契约§9.2.2](../contracts/reactor.md#922-实现候选手动升级10与max)亦已记录移除确认/还原；本项不是从运行代码反推设计。
- 生效结果：分配拖动/均分直接沿原所有者命令提交，不增加整组确认/还原；购级使用×1→×10→MAX循环键和独立购买键。预览只读、提交时校验、一次接纳/发布、拒绝不污染已接纳状态等后台边界继续有效，实际工作动态仍读取已接纳状态。
- 实施与验收：集中下台与设备一并制作；本裁定不表示新核心/管路/公共材质消费、性能或整页视觉已完成，当前状态仍见[B01入口](../../verification/reactor-centered-godot/evidence/b01-redesign/README.md)。

<a id="d11-星球设施承载与六类适用范围待核"></a>
<a id="d11"></a>

## D11 星球设施承载与六类适用范围（旧分工冲突已关闭）

- 旧要求：[M7@e7ff](https://github.com/rlmclmc2-boop/space_idle/blob/e7ff7673eea06611ca65337c58f32e248115cc13/space-battleship/docs/game-design/art/modules/planet.md)将精炼厂/工坊固定在地表并随地貌自转；该通用强制分工不再生效，不要求其他类别回退旧地表布局。
- 后续裁定来源：主线程在2026-10-31补回本对话用户原话。用户提出“卡通化轨道环带，深入采集，建筑在环带上构成整体”，可“以空间站为原点的扩写式方案”，并说“不同星球做好接点就行”；随后批准：“这个没啥问题，就这样吧。环带和星球自转可以分开转，探索船用另一条路线绕星球转。在模块视图里星球可以小一些了，以整个结构站住”。用户要求导入游戏优化，同时指出“环带是断裂错误的”，不得带入实机。
- 生效范围：以星球包裹式环带/设施整体作为后续制作方向，球环可独立转、探索船另轨，后环应正确闭合；可复用结构并适配不同星球接点。用户后续补充“星球设施,不必须每个星球都一个样.若确有需求,每个星球单独一套也可以”，且“只是建议不强制”；因此既不强制六类外观完全相同，也不强制每类单独制作一套。
- 保留的未完范围：具体类别的接点、采集端与专属变体仍须随方案完成；上述方向批准不等于每类具体资产/实机已经验收。[R17入口](../../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)维护当前固态代表与四设施共同形体的制作状态，不恢复A/C形/虚线平台旧退回稿，不把共用运行模型当成六类完成证据。
