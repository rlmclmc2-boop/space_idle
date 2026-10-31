# 星球前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。
[本组版本状态、共同身份与失效边界](../14-ui-contracts.md#8-实现候选成员设施与选中节点的最小只读事实)。
[船员/星球早期共同候选连接](crew.md#3-候选展示扩展与尚未补齐的交换)。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 星球：planet_panel | Planet `planet_options/status_rows/building_options/visual_snapshot`；注入视觉上下文paused/speed | `set_automatic/claim_build`；注入 `coordinate_planet_cancel/publish_planet_claim` | `status_changed(ids)/buildings_changed(ids)/availability_changed`；主线面板未接入Crew人数通知 | 选中星球/设施、视角、详情与终端开合。owned仅消费已建成快照；ready与领取分开。 |

### 8.3 Planet：设施事实

拟增`Planet.facility_facts(planet_id: String, explorers: Dictionary, builders: Dictionary) -> Array`。未知或未开放星球返回空数组；可用星球仅返回其实际适用设施，包含locked/building/ready/built。explorers/builders由装配处在当前Session的可见显示帧同步新读`Crew.step_assignments()`并即读即传，不复用固定步开头缓存的people；它们是同名只读临时视图：按星球键与现有施工目标键映射成员id数组，形状与现有Planet推进输入一致。视图不得自报人数，Planet不留存这些人员视图或另建占用账本。

| 必需字段 | 类型、单位与来源 | 消费边界 |
|---|---|---|
| `planet_id/id/name/type/state` | String；现有星球、设施定义及真实状态枚举 | built表示已领取，不输出另一个owned领域状态；设施资产由实际id/type关联，不按四个演示槽位补不存在设施。 |
| `work/required_work/unlock_exploration` | int；已累计的探索完成次数/所需次数/开放所需探索次数 | 复用设施work、build_explore、unlock_explore；不是游戏秒或未来完成时间。跨门槛的那次探索是否计入施工仍服从现有推进规则。 |
| `work_fraction` | 有限[0,1]float；由Planet根据现有有效计数生成 | 只供条形显示，不由条长回写工程量；不重新解释施工规则。 |
| `extra_crew_required/builders_present/explorers_present` | int；配置额外施工人数及临时人员视图中该实际目标人数 | 额外人数为0不表示无需探索；字段不是派遣许可，继续用现有assignment_capacity及Session协调命令。 |
| `pause_reason` | String；仅building行按既有推进前提投影：`ExplorationNotRunning`、`NoExplorer`、`MissingBuilders`或空串，按此顺序取首项 | 仅为设施不能随探索完成而推进的原因；其他状态为空。全局暂停/倍速沿原上下文，不混入设施状态或自建暂停。 |
| `claim_allowed/claim_reason` | bool/String；复用当前星球可用性、ready状态及原命令准入条件的只读判断；允许时reason为空 | 不执行_claim_build或预先接纳；仍须由claim_build按提交时事实判定，不增加统一错误/回滚政策。 |
| `source_factor` | 已领取equipment/refinery设施的当前来源倍率Amount文本；其他类型或尚未领取为null | 沿已有设施贡献来源求值/缓存投影，仅是该设施当前来源倍率，不是装备或掉落的最终值。shipyard/auto_explore不伪造数值倍率；不承诺领取后预测或重铸许可。 |

实际探索者与时钟继续按原人员事实及`Planet.visual_snapshot`消费，不复制探索时钟。主线`visual_snapshot`没有automatic字段；本分支实现候选的最小增补见[第10节](../14-ui-contracts.md#10-实现候选超空间只读预览与星球自动设置)，未合main。该输出只读现有设置，不把关闭自动与立即取消合并成新动作。

### 8.5 本模块通知

[共同失效边界与版本状态](../14-ui-contracts.md#8-实现候选成员设施与选中节点的最小只读事实)
- Planet沿`status_changed(ids)/buildings_changed(ids)/assignment_options_changed(ids)/availability_changed`使对应星球事实失效；automatic-only变化若影响既有展示，也须沿原status_changed覆盖，不能靠重建全页面补缺失通知。设施视图直接订阅Crew成员/选项变化，只重读当前可见星球并注入最新人员事实，不新增Session全局通知路由。

## 10. 实现候选：超空间只读预览与星球自动设置

[本节版本与实施范围](../14-ui-contracts.md#10-实现候选超空间只读预览与星球自动设置)。

| 出口与消费者 | 最小输出与语义 |
|---|---|
| Planet `visual_snapshot(id)` → M7自动设置 | 在现有快照加`automatic: bool`，读取已接纳的继续探索设置；running/时钟独立。未知或未开放仍返回空快照。setter只在成功且设置实际改变后沿既有status_changed通知，不新增通知类别。 |

## 11. 实现候选：当前星球征服事实与累计来源摘要

**状态：设计候选`1865da2f`已获根审及原星球独审限定通过；本实现候选待原双审、未合main，不代表完整M7/V7验收。** 实际出口与定向证据见[实现记录](https://github.com/rlmclmc2-boop/space_idle/blob/ad4c01d7fd765a20701845b8bf0effe7ae217c91/space-battleship/docs/verification/planet-conquest-readonly-implementation.md)。 固定业务基线`26832431d6546a436774c802e80aff2dc086f7dd`；消费者`a91f65b4`的实际缺口、权威来源和验证边界见[短提案](https://github.com/rlmclmc2-boop/space_idle/blob/ad4c01d7fd765a20701845b8bf0effe7ae217c91/space-battleship/docs/verification/planet-conquest-readonly-proposal.md)。本节不改变征服/重铸、Buff叠加、保存或开放规则。

候选新增`Planet.conquest_facts(planet_id: String) -> Dictionary`，仅消费当前已正式绑定Session的Planet已接纳状态。未知/未开放沿现有Planet可用性判定返回`ok=false/reason=PlanetLocked`，不泄露该球详情或伪造成功空奖励。成功给`ok/planet_id/conquered/shared_experience/rewards`；conquered取该球原标记，shared_experience沿原`_buff(state,buffs,"crew_exp_share","all",planet_id)>0`，只指该球探索经验是否共享，不给未来经验或人数。

rewards只含下列四个已生效累计征服**来源**，每行给稳定`kind/target/value/unit/display_text`。累计覆盖原_buff看到的全部已接纳征服标记，不只当前球或当前可见球；当前球未征服也可显示其他已征服球的累计收益。不提供本球未来征服所得、按球拆分奖励或最终全局值。

| kind / target | 原贡献字段与value类型 | unit与显示边界 |
|---|---|---|
| level_bonus / equipment | equipment_levels；原int(_buff(...))结果 | levels，征服来源的装备有效等级加成；不是槽位付费级或装备最终有效等级。 |
| level_bonus / enhancement | enhancement_levels；原int(_buff(...))结果 | levels，征服来源的强化额外等级；不是付费等级或所有来源合计。 |
| free_charge / all | free_charge；原有限float | ratio，原免费充能比例，例如0.1；百分比display_text由提供方格式化，不变成实际供能Amount、伤害比例或统一乘数。 |
| luck / all | luck；原有限float | luck，原幸运加成单位；不是选定船员等级/幸运快照或奖励概率。 |

最小提取原_contributions初始化中的四项为共用纯助手，旧贡献计算与新读口复用；原_buff的add/mul/max顺序、原行遍历顺序及int/float类型保持，不新增规则、封顶、Amount业务运算或奖励账本。读取不调用contributions/_contributions来填缓存，也不读写_claim_state/_claim_factors，不修改_factors、通知标记或RunState。公开结果及嵌套行脱离所有者；缺失/非有限源值明确读失败或未知，不用0/×1代替。合法无征服时原求值的0与false是已知结果。

planet_unlock仍复用is_available/planet_options的实际开放结果（同时含原征服链与关卡门槛）；不新增解锁阈值口，不由UI根据Buff推断可达。设施收益继续facility_facts.source_factor，不混入累计征服区。UI不调用save_state/prepare_reforge/contributions来凑显示，不从名称或display_text反算业务值。

候选新增局部`Planet.conquest_changed(changed_planet_ids: PackedStringArray, cumulative_changed: bool)`。仅成功accept_reforge及restore_state的征服事实可能使其失效；赋值前保存首次征服标记/四项来源基准，deferred按原纯助手比较最终净变化，同批合并。标记相同且四项来源相同不发，A→B→A不发，读取/拒绝及prepare_reforge只读预览不发；候选Planet实例若执行restore_state/accept_reforge，同样可排队并按净差发信号，但事件不传当前页面、不改旧会话；发送前清队列/更新基准，重入不被旧快照覆盖。基准仅为瞬时通知比较，不是持久奖励账本。

当前星球的标记/共享经验仅在自身ID改变时重读，累计区仅在cumulative_changed=true时重读；普通探索计时、人员、自动开关和设施领取不刷新此摘要。初次绑定、切球及换Session重绑时读一次，隐藏只积累相关dirty、停止投影，重开仅消费相关失效；不轮询、不全页面重建、不增Session全局广播。原status/buildings/availability通知保持各自职责。候选恢复/重铸的Planet实例不绑定当前页面；原事务完整成功替换后才重绑，不把本口或其通知当作native全链已完成的凭据。
