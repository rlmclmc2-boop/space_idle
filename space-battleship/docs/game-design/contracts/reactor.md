# 反应炉前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。
[本组版本状态、Amount边界与草稿失效](../14-ui-contracts.md#9-已审设计反应炉整组草稿与科研预算的amount安全预览)。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 反应炉：reactor_panel | Reactor `panel_options`；Session `reactor_inputs` 提供容量因子与免费供能输入，不能据此冒充已有完整分配展示模型 | `purchase/allocate_text/distribute`；注入 `payment/publish_reactor` | `choices_changed`；主线没有专用 `presentation_changed` | 设备选择与金额草稿、控制区展开；实际分配与增益归Reactor。 |

## 3. 候选展示扩展与尚未补齐的交换

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 反应炉 | `presentation_model/allocation_preview/adjust_allocation` 及 `presentation_changed` | 与前端设备身份、工作/停机和编辑器连接；资产锚点属于前端，不向后端新增像素字段。 |

| 候选查询 | 已有候选字段 |
|---|---|
| Reactor.presentation_model | `level/capacity/remaining/load`；modules行 `id/name/enabled/allocation/free/effective/factor/ratio/load`，区分手动、免费、有效供能和最终增益。 |

### 9.2 Reactor：整组分配预览

拟增`Reactor.allocation_plan_preview(draft: Dictionary, inputs: Dictionary) -> Dictionary`。inputs由装配具名callable即时注入现有`Session.reactor_inputs()`的当下值，不要求UI构造或认识内部组成。draft仅有三个具名读取分支，不是通用命令容器：

| draft | 精确含义 |
|---|---|
| `kind="shares", shares_bp={module_id: int}` | 每项占**总手动容量C**，不是剩余容量、有效量或含免费量的比例；键必须恰为当前开放设备，全部显式给出，允许0。每项`floor(C×bp/10000)`，未分配部分保留。 |
| `kind="amounts", amount_texts={module_id: String}` | 同一整组草稿的精确金额入口，仍须给全体开放设备；按原金额解析及floor生成整数目标，不在UI求和/钳制。 |
| `kind="equal"` | 沿既有distribute的纯求值：只含开放设备，整数商均分、余数按配置顺序；沿原Amount对极大个位余数的可表示性口径。 |

未知/锁定ID、缺项、非整数/越界基点、基点合计>10000或目标Amount合计>C均返回具名拒绝；不静默补旧值、归一化、重排或替玩家钳到预算。超额检查以Amount实际求值结果再核一次。请求0%/清零时合法目标为0，免费量仍按原规则存在。

最小成功输出：`source`只给外部必要的容量、开放设备ID及配置顺序等公开结果，可复用`current`对应值，不重复暴露输入分解；`current/target`各给`capacity/allocated/remaining`，设备行给`id/manual/free/effective/factor`的Amount文本。容量输入因子、免费输入比例及人员/算法等内部组成不透给UI作比较或管理失效。C来自原_capacity；free的实际Amount读数仍展示且不占手动容量，effective及factor复用原_evaluate，不能把免费比例当最终伤害比例。target是同快照的整组效果比较，不承诺完整战斗收益。比例条可另给有限显示比例，C为0时比例为0，不产生NaN。

**选定的整组提交：** 拟增所有者内最小具名金额入口`Reactor.apply_allocation_plan(amount_texts: Dictionary, inputs: Dictionary, publish: Callable) -> Dictionary`；装配负责即时提供inputs/publish，UI只提交已显示并确认的全套canonical金额目标。比例草稿只用于预览生成目标，命令不接收基点、不按新容量重算金额。映射键必须恰为提交时开放设备ID集合，含0值项；金额须为规范非负整数Amount，不重取整改变确认值。

所有者按提交时容量/开放集合一次校验完整映射与合计，不能容纳或集合变化即普通拒绝，不补项、不按设备钳制；复用原候选求值后仍须核对全部手动值等于确认金额。容量改变但仍能容纳、集合未变时保留确认金额并允许接纳，不引入容量快照锁。通过后形成一个所属模块候选，一次求值、接纳及既有发布；普通拒绝不写入任何本组目标，无逐设备部分成功，原fault仍按第5节停机，不声称可回滚native故障。

成功后当前真实分配/免费/有效量及效果替换旧比较；不把旧预览的倍率当承诺。现有allocate_text仍供单设备动作，新整组确认不让UI管理先减后增、多次发布或差异重试。均分保持确认后**一次distribute**，明确按提交时状态均分；预览的容量/效果不锁住提交时容量，实际回执优先。
