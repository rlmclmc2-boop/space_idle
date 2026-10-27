# 强化前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 强化：enhancement_panel | Session `enhancement_inputs` 提供bonus、开放查询及装甲数，当前是操作准入输入；主线无专用页面 `presentation_model` | Enhancement `purchase/set_branch/move_forward`；注入 `affordable/publish_enhancement` | 主线没有专用强化 `presentation_changed`；不能假定它已通知界面 | 效果/节点/分支候选与展开；有效顺位、门槛和数值仍由Enhancement决定。 |

## 3. 候选展示扩展与尚未补齐的交换

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 强化 | `presentation_model/presentation_changed` | 当前有效数值及A/B具体增量的充分展示；如输出不足，在Enhancement复用实际效果求值形成最小展示输出。 |

## 11. 实现候选：装备比较、强化摘要与成交回执

[本节版本与实施范围、实际成交回执及刷新边界](../14-ui-contracts.md#11-实现候选装备比较强化摘要与成交回执)。

| 入口/消费者 | 最小读取契约 |
|---|---|
| Session `enhancement_presentation()` → M5等级行/六卡 | Enhancement.presentation_model在真实bonus/开放/armours上纯调用_effective_level/_describe/_combat，输出scope=enhancement_static、paid/bonus/effective、available/reason、两组实际顺位及effects。行给id/category/position/threshold/active/reason，节点index/threshold/choice/open/function_active/reason，summary含合成A/B静态参数与生效规则。不是native临时/历史乘数或未来收益。 |
| Session `enhancement_branch_details(effect,node)` → M5选择前详情 | Enhancement.branch_details对所选节点0–2给门槛/选择/open、A/B options；无论未选/未开放均给稳定rule_id及必要parameters（value/unit）。command_allowed沿原_choose，function_available/function_reason独立；repeat-B2旧选择可保存且原命令可接纳，但功能不生效。不把选项规则冒充当前合成结果。 |
| Session `enhancement_purchase_preview(count)` → M5买1/最多10固定区 | Enhancement.purchase_preview复用原_quote_purchase，保留ok/reason、request_count、purchasable_count、costs/extreme与first_level_costs。最多10可能实际2；NoChange给可购0，其他错误的数量未知，不伪造0。首级所需与实际可成交总费分开，不新增强化MAX。 |

强化summary给完整已生效A/B静态投影：熟练/适应静态合成因子及规则、连发含A的概率/伤害/延迟/额外目标、暴击原始率和B3效果触发率分开、记忆含A及当前装甲B3的恢复/上限、延期未强制清除概率和B2/B3随机/强制清除及来袭倍率分开。生效规则及节点选项均用稳定rule_id、参数和game_seconds/count/ratio单位供前端本地化，不让UI补公式；每盾充能等只给既有规则参数，不伪造未提供的累计实值。未定历史动态乘数、未来收益继续排除。
