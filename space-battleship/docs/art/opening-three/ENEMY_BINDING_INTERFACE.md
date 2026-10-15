# 新舰绑定：最小接口与现有缺口

核对基线：85a04e2633631cb84fed8018c7b29a5143759758。供父协调Sol；本文不新增机制、ID、敌种或事件实现。背景候选保持不动，Windows原生窗口仍由父安排。当前截图中的旧舰、旧战点及脉冲100/0.5秒不是新平衡接入证据。

## 先让Sol返回的最小交接

| 项目 | 最小内容 | 用途/边界 |
|---|---|---|
| 敌种身份表 | 稳定配置主键及其含义；若一个身份跨多个配置行，给明确归并关系；前三关实际用到哪些主键 | 优先复用现有row.id；仅其不能表达稳定身份时才讨论额外archetype字段。美术不指定任何ID值，不按size、血量或关卡猜型 |
| 运行身份出口 | 配置主键在敌人Dictionary/原生actor读模型中的字段名；实例uid生命周期 | uid定位本局实例；slot、size、空间source_id都不能代替敌种身份 |
| 已成立的反馈语义 | 现有武器/护盾/装甲类型；新减伤若成立，其权威状态与结算原因；相关事件确切出口 | 没有真实状态就不画该机制。持续束不因美术提前解锁 |
| 权威时钟与攻击归属 | root/batch/flight等已有标识各指什么；同轮多磁轨的归组由谁发布；时间单位/暂停/交接语义 | 表现只消费结果，不根据射速、时间邻近或小伤害自行识别减伤/同轮 |

父另外协调：新轮廓与现有几何权威的兼容方案。未确认前保留旧舰正式绑定；R03三种轮廓仍只是识别样张。历史R01的needle/anvil/crown均不是Sol批准ID，不写进配置。

## 资产绑定最小契约

稳定敌种键 → 一个稳定visual key → 舰体纹理、alpha/可见边界、既有hardpoints/slot_map。无需每战点独立皮肤，也不把size重定义成敌种。实际装备仍来自equipment，挂点须容纳这些已有装备而不改变炮口权威、武器数量或类型。

代码当前按size选择enemy_1…enemy_6，且有多个入口，不能只改其中一处：

| 源码锚点 | 当前行为 | 接入时所需一致性 |
|---|---|---|
| scripts/game.gd::spawn_group（2183起） | 复制db.enemies行，赋uid/slot和实例状态 | 现有行字段可随复制进入实例，但稳定键是否最终可用由Sol确认；不因此假定原生发布已覆盖 |
| scripts/simulation_geometry_authority.gd::_source_enemy_appearance（181）、enemy_recognition_geometry（518）、geometry_from_descriptor调用（892） | size→ship_key；appearance签名含ship_key与装备名 | 同一个已确认解析结果同时服务外观、挂点与几何；身份/资产版本改变时使既有发布失效，不新建第二份几何权威 |
| scripts/simulation_geometry_authority.gd::prepare（535） | 主线程捕获纹理identity、bounds、alpha profile，所有权移交后禁止再读纹理 | 新alpha轮廓会影响权威包络，不能当作纯换色安全替换；父须决定合法几何配准/绑定方式，美术不能偷偷改变命中体积 |
| scripts/battlefield.gd::prepare_enemy_hulls / draw_enemy_hull_and_status / enemy_status_layout（936/954/997） | 预热及fallback绘制仍从size取纹理 | 新绑定须覆盖预热、普通/首领fallback、状态条边界，不能只使某一种渲染路径换舰 |
| scripts/retained_enemy_contacts.gd::compile_record（115）、更新分支（204） | size取纹理；按shape_revision/source_id/appearance身份重编译 | 复用既有失效条件，appearance必须反映新visual key；不要逐帧加载贴图、读取alpha或重建全舰 |
| data/ship_weapon_visuals.json::ships.enemy_* | 既有texture、hardpoints、slot_map | 美术登记资产描述，不改equipment或武器规则；和权威快照使用同一描述 |

最小新增信息是“已批准敌种键到visual key的明确映射”，不是强制新增一套敌人schema。几何批准与两条绘制路径一致后，可先绑定身份；高级反馈不必成为所有贴图绑定的前置条件。

## 表现状态与事件：可复用和缺口

以下字段是所需语义，不是指定Sol必须采用的字段名。优先补齐现有权威出口/读模型，不新建并行事件总线或模拟器。坐标沿用既有逻辑战场坐标，时刻沿用对应权威时钟；数值沿用现有数值类型。事件沿既有单次消费链，不能因交接/暂停重复播报。

| 表现 | 已有出口/语义 | 最小缺口或处理 |
|---|---|---|
| 存活、盾量、护甲类别 | hp/max_hp、shield/max_shield、armourType/shieldType；enemy_recognition_visual.gd::state（118） | 可复用。新身份不得由这些数值推断；保留既有伤害类型差异，不暗示绝对免疫 |
| 炮口、弹体、接触点 | 实际equipment/components；projectile_impact含shot/pos；shot.serial；既有发射绘制入口 | 普通发射/命中可复用，不改弹体数量或频率。shot.serial只标识飞行体，不能自动等同攻击根或同轮批次 |
| 命中—目标—结果关联 | game.gd::hit_enemy（2564）发hit：uid/type/amount/critical；amount合并盾与船体损失 | 如需精确结果型反馈，需权威给目标uid、实际接触点/时刻、已有攻击归属、盾损失与船体损失（或等价前后状态）。不能从合计amount倒推破盾/减伤 |
| 破盾 | 当前可观察shield正数→0；explode已是实际死亡反馈 | 快速连续结算/跨所有权交接可能在两帧间跨越，精确一次性破盾须随权威结算发布布尔结果或等价有序前后值；不要混同击毁 |
| 护盾恢复 | shield_hit_at、shieldDelay、shieldRecovery、shield_updated_at、enemy_shield_time；state用实际盾量增长且非暂停才亮恢复 | 现有普通持续反馈可复用，不凭到点假亮。若新反馈需同帧精确“恢复开始/被打断”，由权威发布已结算状态/实际变化；不要美术重算恢复规则 |
| 短连续受击减伤 | 所查现有反馈没有这项专用状态/原因出口 | 等Sol确认机制是否成立以及作用域。需要真实生效状态及本次实际减伤原因/结果；不以低伤害反推。窗口/倍率、同轮磁轨豁免由Sol/父定，不由视觉计时器决定 |
| 危险攻击前兆 | 实际发射已有；当前未找到稳定的“已承诺攻击蓄势/取消”表现事件 | 仅在权威确有该阶段时给source_uid、攻击归属、开始/结束时刻、取消；目标只有已确定才给。否则只画实际发射，不把cooldown或未来队列当承诺的危险倒计时 |
| 击毁 | game.gd::hit_enemy只由跨零命中发explode；battlefield.gd消费uid/位置/领舰状态 | 复用已存在的单次消费链。需要保留消失前的位置/姿态，不因下一次slot复用把效果贴给新舰；不另发一套击毁判定 |

## 原生与fallback对齐点

- combat_context.gd已有root_id/batch_id/source_id/weapon；其中source_id是伤害来源语义，不能直接当敌种ID。其与原生attack/instance/flight标识如何对应、哪些代表“同轮”，仍需Sol明确，不能美术自行归并。
- addons/native_battle/src/combat_execution_kernel.h::take_feedback（2742）有uid/type/amount/absorbed/clock/position/target_uid及部分shot，但**字段存在不代表敌方盾吸收已赋值**：敌人hit构造（1024起）只把damage+absorbed写入amount，没有把局部absorbed写入e.absorbed。
- scripts/native_execution_session.gd::consume_feedback（220/240）把原生hit转为游戏事件时未保留clock/攻击根；若扩展结算反馈，原生产生端、适配端和fallback需同语义，不只在GDScript一侧加字段。
- addons/native_battle/src/combat_presentation.h::contact_snapshot（234）只提供position/direction/born、类型或fire/hit/critical等视觉数据，没有目标uid/攻击归属/减伤原因。它适合现有接触效果，不适合从中反推结算；不要把它扩成第二份战斗权威。

## 可执行的交接顺序

1. Sol交稳定主键/归并表、运行字段与已成立机制的反馈出口；父确认alpha/挂点如何与现有几何权威兼容。
2. 美术按确认映射准备正式单舰资产和登记描述；复用当前出版/失效链，让retained与fallback、普通与首领身份一致，未知键保留旧资产并可诊断。
3. 仅对确有权威结果的状态接反馈；缺失的高级状态暂不表现，普通舰体/真实发射/真实命中不因此停工。
4. 必要验证：同身份跨关不换型；实例回收不串效果；盾/船体/击毁不混淆；原生与fallback同语义；无每帧资源读入。Windows原生时段仍由父协调，不另开独立测试任务。

本次只读源码并写接口清单，没有修改生产代码、配置、资产、机制或背景，也未启动游戏/性能测试。
