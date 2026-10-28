# 星系前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。
[本组版本状态、共同身份与失效边界](../14-ui-contracts.md#8-已审待实施成员设施与选中节点的最小只读事实)。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 星系：galaxy_panel | Galaxy `status_rows/assignment_options/visual_snapshot`；上下文来自Crew `galaxy_assignments`及Session暂停/速度 | 当前星系面板主要读地图；派遣通过crew_panel的 `coordinate_assignment`。探索/施工/升级由Galaxy推进 | `status_changed(keys)/availability_changed`；主线面板未订阅Crew变化，没有候选的所选节点详情刷新链 | 当前区域、节点选择、pan/zoom和详情开合；不能在UI推进工程量。 |

## 3. 候选展示扩展与尚未补齐的交换

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 星系 | `node_presentation(region,id)`；候选面板订阅Crew变化，可见所选详情每250ms只读刷新 | 完整发展阶段、撤人/恢复与升级结束实操未通过；不能用静态字段存在代替该验收。 |

| 候选查询 | 已有候选字段 |
|---|---|
| Galaxy.node_presentation | `name/state/level/effect/bonus/explored/reachable/explore_remaining/construction_remaining/upgrade_remaining`；人数仍由Crew事实按区域关联。 |

### 8.4 Galaxy：选中节点事实

拟增`Galaxy.node_facts(region_id: String, node_id: String, counts: Dictionary) -> Dictionary`。未知/不可用区域或不存在节点返回空字典。counts由装配处在当前Session的可见显示帧同步新读`Crew.galaxy_assignments()`并即读即传，不复用固定步开头缓存的people；它仅转交该区域人数映射，与现有Galaxy推进输入一致，不由视图按人物图标计数或写回。地图形状/连接与人员总数继续消费原接口，本方法只补选中节点的语义截面。

| 必需字段 | 类型、单位与来源 | 消费边界 |
|---|---|---|
| `region_id/id/state/explored/reachable` | String/String/String/bool/bool；实际键、empty/exploring/constructing/active状态、揭示事实及既有可达性求值 | reachable不表示可选中即能启动工程，也不要求前端重生成蓝图或推导可达性。 |
| `building_id/name/level/upgrading/target_level` | String/String/int/bool/int或null；已揭示设施身份、当前等级、现有升级集合成员资格及正在施工/升级的实际目标等级 | 未explored时building_id/name为空、target_level为null，不泄露已抽取但未揭示的类型；level保持实际值。正在施工目标为1，正在升级为当前+1，否则target_level为null，不将演示目标等级当新升级命令。 |
| `explore_remaining/explore_required` | float；探索工程量 | required复用初始化分配给该节点的准确工程量，含既有末节点余量口径；不重新生成蓝图/RNG。 |
| `construction_remaining/construction_required` | float；在现有施工前提满足时消耗的游戏秒 | required沿用现有construction_time；无人/全局暂停时不推导现实倒计时。 |
| `upgrade_remaining/upgrade_required` | float或null；升级工程量，非资源费用、非直接剩余秒数 | 未在升级集合中时均为null；required复用本次已启动升级对应等级的既有工作量求值，不重新选升级目标。 |
| `progress_fraction` | 有限[0,1]float或null；当前exploring/constructing/upgrading阶段的已完成比例 | 无进行中阶段时为null；所需量与比例由Galaxy沿原初始化/阶段启动求值生成，不由UI把工程量除人数计算ETA。 |
| `progress_block_reason` | String；进行中阶段且该区域无实际人员时为`NoGalaxyCrew`，否则为空 | 全局暂停仍用原上下文；不添加领域暂停状态或新的工作循环。 |
| `effect_id/contribution` | 已揭示设施的原effect_type/String；本节点当前已生效来源贡献的Amount文本或null | 未揭示时effect_id为空、contribution为null；已揭示但未建成的当前贡献为合法0。值是原来源账本中的无量纲增量，不是全局/区域合计或最终倍率，不能由UI加1、套等级/收益公式或据此声称未来效果。 |

当前来源贡献沿原贡献求值/缓存读取；不在该查询中推进、完成或领取工程，不从私有来源账本向UI透传整本数据。本节不增加节点操作、未来贡献预览或真实炮口/碰撞几何接口。

### 8.5 本模块通知

[共同失效边界与版本状态](../14-ui-contracts.md#8-已审待实施成员设施与选中节点的最小只读事实)
- Galaxy沿`status_changed(region_keys)/availability_changed`使选中节点事实失效；施工与升级余量实际变化均须覆盖所在区域，不能只通知升级完成。视图直接订阅Crew成员/选项变化并重读当前选中区域的人数与节点，不全图重建或扩大原人数接口。
