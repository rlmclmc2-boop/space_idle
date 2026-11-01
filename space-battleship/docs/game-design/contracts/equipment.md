# 舰体/装备前后端契约

[唯一入口](../README.md) · [共同读取/接纳协议](../14-ui-contracts.md)。本页维护本模块公开接口；当前实现和消费源见[11](../11-stage6-contract.md)。

换装免费且可立即切回，规则见[03§1](../03-progression.md#1-舰体槽位与升级)；制作要求见[M2](../art/modules/equipment.md)，执行现场见[11](../11-stage6-contract.md)。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 舰体：fleet_panel | Campaign `ship_options/ship_facts`，后者提供 `mounts/drone_capacity` | `change_ship` 调用注入的 Session `commit_ship_refit`；保留原换舰截断和native接纳结果 | `ship_changed/progress_changed` | 候选舰、选中态与预览；不能将预览尺寸当战斗尺寸。 |
| 装备：equipment_panel | Equipment `panel_slots(mounts,ids)/panel_equipment/price_text`；Session `equipment_inputs`；公开 `quote_slot(slot_id,count)`可给确定数量报价，main当前逐槽页面按数量读取报价/比较 | `buy_levels/buy_max_levels/buy_all_levels/equip_slot`；注入 `affordable/payment/publish_equipment_levels/publish_equipment_refit` | `slots_changed(ids)/loadout_changed/options_changed`，可见帧合并失效对象 | 当前槽与候选装备、输入、焦点、滚动、展开；余额是后端事实，换装锁不再是现行要求。 |


## 11. 实现候选：装备比较、强化摘要与成交回执

[本节版本与实施范围、共同读取纯度、实际成交回执及刷新边界](../14-ui-contracts.md#11-实现候选装备比较强化摘要与成交回执)。

| 入口/消费者 | 最小读取契约 |
|---|---|
| Session `equipment_slot_facts()` → M2槽卡 | Equipment.slot_facts按已接纳全部保留槽给id/category/index/equipment_id、paid/effective_level、dormant、switch_ready_at/cooldown_remaining。空槽与休眠独立，未知有效等级为null。switch_ready_at为兼容字段，cooldown_remaining恒为0；购买按所属Owner报价与准入执行。 |
| Session `equipment_comparison(slot_id,candidate_id,count=1,maximum=false)` → M2比较台/固定报价区 | 薄装配实际世界/AI/反应炉及预算，Equipment.slot_comparison只读输出`scope=charged_base`、current/upgrade/candidate、quote、affordable/payment_reason、switch_admission、dormant。current为现装，upgrade按本次quote实际count，candidate沿当前付费级；不组合候选换装+购级。行给装备/等级、主值规范Amount文本或null、status/reason及有单位配置特性；不输出拼接中文当数据。 |
| Equipment `quote_slot(slot_id,n)` / `quote_max_levels(slot_id,inputs,can_pay)` → M2数量/费用 | 确定数量复用原_quote_levels；MAX薄包装原_quote_affordable_levels。保留count/costs/extreme与原reason，costs为resource id→原Amount。单槽+10完整报价不缩成可购2；MAX候选报价错误/不可支付作搜索边界，0统一NoChange，原离散极限保持。不新增整组预览，不把独立MAX相加成批量总价。 |

## 比较与实际成交

静态比较止于成长、进化、科研和供能，当前实战值读取Battle.attribute_details。switch_admission提供单槽换装准入；实际提交由Session协调组合许可。_charged_base使用脱离slot的数据。

实际执行回执附在原命令结果`purchase_receipt`，不改变原ok/reason或部分成功政策。装备成功提交给`commit_status=accepted`、逐槽purchases[{slot_id,count,spent}]和逐资源合计spent；单槽/批量捕获本次执行quote，不靠钱包差/通知后重读反推。buy_all_levels即使返回后续failure、ok=false，已经成功发布的槽仍给accepted回执。无发布为not_submitted，普通发布拒绝为rejected且无确认成交；提交后fault为fault_unknown、spent=null，不声称回滚。早期原准入/报价/支付拒绝可无回执，不表示曾提交；没有成功接纳的候选成本不得当实际支出。回执是上次成交，不是下一报价。


报价/比较/选项只描述当前状态，执行按Owner当下事实重验。slots_changed/loadout_changed/options_changed和预算变化使相应读数失效。
