# 舰体/装备前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 舰体：fleet_panel | Campaign `ship_options/ship_facts`，后者提供 `mounts/drone_capacity` | `change_ship` 调用注入的 Session `commit_ship_refit`；保留原换舰截断和native接纳结果 | `ship_changed/progress_changed` | 候选舰、选中态与预览；不能将预览尺寸当战斗尺寸。 |
| 装备：equipment_panel | Equipment `panel_slots(mounts,ids)/panel_equipment/price_text`；Session `equipment_inputs`；公开 `quote_slot(slot_id,count)`可给确定数量报价，当前页面主要显示下一级价 | `buy_levels/buy_max_levels/buy_all_levels/equip_slot`；注入 `affordable/payment/publish_equipment_levels/publish_equipment_refit` | `slots_changed(ids)/loadout_changed/options_changed`，可见帧合并失效对象 | 当前槽与候选装备、输入、焦点、滚动、展开；冷却/余额是后端事实。 |

## 3. 候选展示扩展与尚未补齐的交换

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 舰体/装备 | Battle `hull_presentation`；Equipment `presentation_slots/equipment_comparison`；Session `equipment_presentation_inputs` | 舰体开放的结构化门槛；批量/MAX的本次总费/数量展示。确定数量报价先复用主线quote_slot；MAX预览若需公开，必须复用原求值，不在UI复制算法。 |

## 11. 实现候选：装备比较、强化摘要与成交回执

[本节版本与实施范围、实际成交回执及刷新边界](../14-ui-contracts.md#11-实现候选装备比较强化摘要与成交回执)。

| 入口/消费者 | 最小读取契约 |
|---|---|
| Session `equipment_slot_facts()` → M2槽卡 | Equipment.slot_facts按已接纳全部保留槽给id/category/index/equipment_id、paid/effective_level、dormant、switch_ready_at/cooldown_remaining。空槽与休眠独立，未知有效等级为null。冷却只作用换装，不给购级加新禁令。 |
| Session `equipment_comparison(slot_id,candidate_id,count=1,maximum=false)` → M2比较台/固定报价区 | 薄装配实际世界/AI/反应炉及预算，Equipment.slot_comparison只读输出`scope=charged_base`、current/upgrade/candidate、quote、affordable/payment_reason、switch_admission、dormant。current为现装，upgrade按本次quote实际count，candidate沿当前付费级；不组合候选换装+购级。行给装备/等级、主值规范Amount文本或null、status/reason及有单位配置特性；不输出拼接中文当数据。 |
| Equipment `quote_slot(slot_id,n)` / `quote_max_levels(slot_id,inputs,can_pay)` → M2数量/费用 | 确定数量复用原_quote_levels；MAX薄包装原_quote_affordable_levels。保留count/costs/extreme与原reason，costs为resource id→原Amount。单槽+10完整报价不缩成可购2；MAX候选报价错误/不可支付作搜索边界，0统一NoChange，原离散极限保持。不新增整组预览，不把独立MAX相加成批量总价。 |

静态比较止于成长/进化/科研/供能；当前实战值另复用Battle.attribute_details，不拿当前native最终值对比候选charged_base。switch_admission仅复用原单槽换装准入，不承诺最终无人机/Higgs组合许可，实际提交仍沿Session原链。查询只读已接纳事实；_charged_base仅给脱离slot，强化不调用会写_pending_output的evaluate，不设可写展示缓存或临时接纳。
