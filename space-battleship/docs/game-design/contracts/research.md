# 科研前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；沿用第14章节号并明确当前版本范围，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。
[本组版本状态、Amount边界与草稿失效](../14-ui-contracts.md#9-已审设计反应炉整组草稿与科研预算的amount安全预览)。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 科研：research_panel | Research `panel_model/choices`；panel_model提供选项、当前每资源投入、自动开关和比例，不是完整工作进度舞台模型 | `select/set_investment_text/set_automatic`；返回原拒绝/成功事实 | `choices_changed/investment_changed` | 每资源投入草稿、自动比例草稿、焦点和选择；刷新不能将草稿伪装成已生效值。 |


### 9.3 Research：单工作点预算预览

工作分支提供`Research.budget_preview(request: Dictionary, inputs: Dictionary) -> Dictionary`。request带当前`research_id`和以下一种意图；ID须与当前已接纳研究一致，查询不选择/续选项目。inputs由装配在当前Session显示帧从工作分支提供最小公开`Session.research_preview_inputs()`即读即传：Economy当前钱包、`income_rates(..., research.income_window(), "investment")`的收入率及游戏时钟/窗口终点、原研究外部速度因子和实际科研岗位事实；外部速度只提供聚合因子供Research消费，UI通过注入的具名预览callable调用，不读取`Session._research_speed`或拆分人员/算法组成来求值或管理失效。不读取UI钱包、墙钟peak或production_base冒充投入收入。

| request | 本次只读目标及既有写入口 |
|---|---|
| `kind="once_ratio", basis_points` | 铁/铀共同近期收入比例。每资源`floor(income_rate×bp/10000)`，0%为0，低收入取整到0也保留0；生成两个金额草稿，不改已生效投入。 |
| `kind="once_amounts", amount_texts={"1": String,"2": String}` | 精确编辑或已生成而保留的本次金额草稿，沿set_investment_text的解析/floor口径；单字段非法给该资源原因，保留文本，相关目标估算未知，不伪造0。 |
| `kind="following_sample", enabled: bool, basis_points` | 给出目标开关/比例及原自动准入。enabled=true时仅展示按**本次收入样本**计算的周期目标`max(1,floor(income_rate×ratio))`；enabled=false只预览关闭设置，周期目标null并标AutomaticDisabled。设置仍调用既有set_automatic，不直接改金额；样本不是已生效或锁定下一周期的投入。 |

收入窗口沿现行规则（当前60游戏秒）：合格已入账actual样本除完整窗口长度，含investment口径接受的galaxy_yield；不是只除已有采样时长、钱包占比或未来收入预测。**保留现有分别接纳路径：** 本次金额仍按当前逐资源动作分别set_investment_text接纳；一项成功不因另一项失败回滚。成功后重读current及比较，未应用资源草稿保留。比例换算/预览由Research拥有，不因共同预算控件就新增没有实际消费者的批量金额入口；持续设置仍独立调用set_automatic。

**持续0%不改现行准入。** set_automatic仍检查原minimum_ratio（关闭时也检查ratio）；当前配置下0%不能提交，following_sample须给`can_apply=false/reason=InvalidResearchRatio`，不能输出“合法下一周期至少1”冒充已支持。若另获准放宽下限，才另审其0%下max(1,...)语义；本提案不改配置。关闭持续跟随使用已接纳的合法ratio调用set_automatic(false,ratio)，仅关自动，不清当前投入。本次0%及手动0投入继续合法。

最小输出如下，均以本次快照为条件，不是新业务状态。科研将比较目标分为`immediate_draft`与`following_sample`两个互斥块，后者另含目标enabled/ratio；不得把following_sample的金额放入“应用后立即生效投入”：

| 字段 | 口径 |
|---|---|
| `current.research_id/level/work/required/remaining_work` | 原已接纳项目/等级及Amount工程量；剩余为原所需量减已做量。复用原求值，不因读查询修改存档required_work。无当前项目时相关值null并给原因，不自动选最短。 |
| `current.investment/automatic_enabled/automatic_ratio/minimum_ratio` | 已生效的每游戏秒投入及原自动设置；与目标、局部模式和比例草稿分别显示。 |
| `resources[1/2].income_rate/balance/current_rate/draft_rate/following_sample_rate/net_current/net_draft/net_sample` | 收入、钱包、当前/本次草稿/持续样本每游戏秒投入及有方向的净收支。仅本请求对应的比较块有值，其余null；合法目标为canonical整数Amount。持续关闭或无合法目标时样本金额null，当前投入始终保留。 |
| `resources[1/2].stock_duration_current/stock_duration_draft/stock_duration_sample` | **假设此后无收入且无其他支出**，钱包/每秒投入所得游戏秒，不是按净收入计算的破产预测或研究完成时间。率为0标not_spending且时长null；余额为0且率>0时为有限0秒；不伪造无穷float。 |
| `current/immediate_draft/following_sample.speed_now` | 本次快照瞬时工作量/游戏秒，按当下余额和投入是否可支付复用原AI/人员/算法与投入求值；没钱失去对应付费因子，基础研究仍继续。率1的因子仍可能为1，不把有扣费一律标成有增速。暂停上下文单列，不改此游戏时钟口径。 |
| `current/immediate_draft/following_sample.completion_estimate` | 条件明确的估算：冻结本次等级/速率/外部因子，假设正投入资源持续足额可付至本级完成，独立复用原求值得到`funded_speed`（工作量/游戏秒的Amount）并由剩余工作量除该速度求Amount游戏秒，绝不拿缺钱时的speed_now相除；同时给假设、funded_speed、各资源所需资金、当前余额能否覆盖。不能当实际ETA；资金不覆盖时仍明确条件未满足，不预测后续随机入账。不可求时null及原因。 |
| `completion_effects` | 当前选中科技完成本级的原效果id及当前→下一级值/摘要，沿原Research效果求值和本次peak事实；不是投入本身的收益、整套战斗最终值或未来随机倍率。 |
| `automatic_refresh` | 沿原refresh_elapsed/automatic_due给距原刷新边界的非负游戏秒、是否已到期及自动关闭/无实际岗位等阻断事实。设置不重置原周期；可能已经到期、等待岗位或下一固定步，不承诺开启后一定再等60秒。 |

速度/估时须抽取原科研求值或对脱离所有者的数据求值；不在UI重写log/支付积分，不用调用advance来推进真状态，不将短缺一概当停工。库存独撑时长与有条件完成估时分别命名/展示，不以一个“remaining”同时指两者。输入/工作/支付条件一变，旧估算失效；不承诺未来项目、收入或实际现实完成时刻。
