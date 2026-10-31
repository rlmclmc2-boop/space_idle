# 反应炉前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。
[本组版本状态、Amount边界与草稿失效](../14-ui-contracts.md#9-已审设计反应炉整组草稿与科研预算的amount安全预览)。

B01分配提交语义待核[D10](../review/conflicts.md#d10-b01分配提交语义待裁定)；保留本节预览/接纳分离合同，不由当前UI调用方式默改设计。

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

<a id="921-待审增补真实展示与局部变化通知"></a>

### 9.2.1 实现候选：真实展示与局部变化通知

**状态：设计`3d14ded8`已根线程及原独审核限定通过；[运行实现候选](https://github.com/rlmclmc2-boop/space_idle/blob/ad4c01d7fd765a20701845b8bf0effe7ae217c91/space-battleship/docs/verification/reactor-presentation-implementation.md)待原双审、未合main，不代表UI或完整游戏验收。** 现有整组接口以已审`09af963cf6f66146e019cecd08353426ab6d6abb`为基线；本增补不改变它们或原购级/均分/发布语义。第3节b7bb展示候选不因本节转为已实现。固定消费者、接纳/钱包写入路径、验证计划见[本次定向提案](https://github.com/rlmclmc2-boop/space_idle/blob/ad4c01d7fd765a20701845b8bf0effe7ae217c91/space-battleship/docs/verification/amount-safe-preview-contract.md#反应炉真实场景最小展示与局部通知提案)。

| 运行候选出口 | 最小职责与字段 |
|---|---|
| `Reactor.presentation_model()` | 仅读已接纳状态与容量/效果缓存，给ok、level、capacity/allocated/remaining规范Amount文本、can_allocate/reason、modules及core load；不带预算/购级报价，不把即时inputs或prepared预测为current。缺已接纳缓存给ReactorSnapshotUnavailable，不伪造0或factor=1。modules沿已接纳开放ID及顺序，给id/enabled、manual/free/effective/factor规范文本、has_free及有限ratio/load。当前准入开放集合与已接纳缓存不一致时明确不可用，不混成一个成功快照。 |
| `Reactor.purchase_preview(can_pay: Callable)` | 仅当前消费者所需+1；复用原_purchase的脱离候选及_quote/等级范围判断，给原costs规范文本、can_purchase/reason。count固定1，不新增MAX；付款能力只用注入Economy.can_pay。金额/文本只按已接纳level和会话内固定配置重算/复用，预算变化只重读可支付性；确认仍原purchase重验和发布。显示cost_text/message由宿主/前端按资源ID与原原因本地化，不解析Amount或计算费用。 |
| 原`allocation_plan_preview`及实际结果的current/target行 | 在共用_plan_readings中补同口径ratio/load/has_free；沿现行_amounts/shares/equal准备求值，不另写均分或效果算法。current仍已接纳，target仍脱离候选；命令及其canonical金额、拒绝顺序和回执原字段不变。 |
| `Reactor.presentation_changed(changes: PackedStringArray)` | 仅该Reactor实例的局部deferred合并通知；变化类别限level/capacity/availability/allocation/free/effect/readiness。只标记失效，不携带或接纳候选。level/availability才影响+1报价/准入；当前/来源相关变化才重读场景与必要草稿比较。 |
| `Economy.budget_changed(resource_ids: PackedStringArray)` | 仅真实已接纳余额的局部deferred变化提示；由Economy拥有，保留原display_changed语义。宿主仅把与+1 costs资源集合相交的事件标记为报价可支付性失效；不触发场景/草稿预览/效果/滑杆重建。 |

**比例仅供绘制：** C为同一已接纳或target的总手动容量，A为该行manual，F为该行实际免费量，E为原Amount.add(A,F)。C>0时ratio=to_ratio(A,C)、模块load=to_ratio(E,C)、核心load=to_ratio(ΣE,C)，沿既有to_ratio在[0,1]饱和；核心/设备load不是输出速率、功率或额外玩法上限。has_free由Amount.compare(F,0)>0给出，不从文本或float猜测。免费供能不占手动容量，却参与effective/load及原效果求值。

原_evaluate把F计算为C乘现行免费系数；因此合法且已求值的C=0必有F=A=E=0，ratio/load为0、效果沿原公式为1。C>0、A=0、F>0时load>0，不能因滑杆为0而停掉真实运行表现。E≥C时load饱和为1但E/factor全文仍保留；不能由饱和值反算金额。缺缓存或源错误是未知；C=0且F>0不是该公式的合法结果，不能拿这种夹具证明免费零容量规则或强行输出0。

**通知与刷新边界：** Reactor在_adopt接纳、成功restore_state及开放事实变化时仅安排一次deferred检查；prepare、discard、预览、拒绝和读取不发信号。检查在同步业务调用栈结束后比较最终已接纳公开事实和本轮第一次变化前的事实，只在数值/ID顺序/准入确有净变化时发相应changes；不比较整份save、不求幂/报价，不暴露_prepared_state。A→B→A不广播；同帧多次成功接纳只合并最终净变化。记录比较基准并清queued标记后才emit，监听者重入产生下一次独立检查，不能在emit后写回旧候选/快照。它只使UI失效，不承担业务接纳；原choices_changed及旧面板行为保留；新Scene以presentation_changed驱动实际模型，不再把旧choices无条件连到整场景invalidate，避免原整组入口无净变时仍触发全读。

Economy在真正钱包写入点安排独立deferred检查，包括notify=false的静默接纳；保留原display_changed/drop_collected及其通知顺序。比较第一次写入前与本轮最终钱包的数值，缺键视同零；用原Amount.compare排除仅表示差异、零增量和A→B→A，只报真正净变资源。该临时只读快照仅服务通知合并，不是第二预算账本。payment/can_pay、掉落登记/生成/移动、收入窗口裁剪和显示格式化均不使budget_changed发生。来源错误不伪造0、不借通知新增RunState.fail。

UI只订阅本实例及相关预算资源；通知只置局部dirty，下一可见显示帧分别消费：presentation dirty读取模型/必要比较，quote dirty仅读+1报价可支付性。预算事件不调用全场景_refresh或_preview_draft，不用限频全量新读兜底，也不新增Session总线。隐藏期只积累相关标记，停止投影；重开/换Session初次读取一次并重绑旧连接。真实工作shader始终只消费current model的load，时钟推进不读取模型/报价/预览；宿主时钟context补显式running（取公共RunState.is_running），running=false禁用交互，paused仅控制动画；不能把用户暂停等同停机而改变原业务准入。

被动容量/免费量/来源变化时，shares草稿须保留已生成canonical金额，沿原amounts分支重取比较；不得由刷新把旧基点重新换成新金额。只有新拖动才用shares生成新金额。equal确认仍一次原distribute并采用提交时状态；开放集合改变清旧预览，不补项。读取错误须禁用相关操作并呈现未知，不沿用消费者缺字段默认为0的绘制回退。

<a id="reactor-bulk-purchase"></a>

### 9.2.2 实现候选：手动升级×10与MAX

**状态：设计固定`c6170694`，按根线程继续授权实施；当前实现候选待原双审、未合main，不代表消费者或完整游戏验收。** 用户已要求×10/MAX；本节不把9.2.1固定+1实现冒充批量报价已存在。固定Owner、两消费者及源码证据见[定向核对与提案](https://github.com/rlmclmc2-boop/space_idle/blob/ad4c01d7fd765a20701845b8bf0effe7ae217c91/space-battleship/docs/verification/reactor-bulk-purchase-proposal.md)。UI风格、分配确认/还原的移除及消费接线归反应炉组；本节不扩展分配或自动岗位。

| 实现候选所有者出口 | 字段与精确语义 |
|---|---|
| `Reactor.purchase_preview(can_pay: Callable, count: int = 1)` | 向后兼容原单参+1；正整数count沿原_purchase/_quote求整批费用。成功仍给ok/count/costs规范Amount文本/can_purchase/reason，并给cost_resource_ids（原费用资源ID集合）。count=10严格为10级；不足时can_purchase=false/reason=InsufficientResources，不降成部分10。非法count、等级范围或费用计算/格式化/比较错误明确失败，不伪成功或伪余额不足。 |
| `Reactor.purchase_max_preview(can_pay: Callable)` | 给同口径ok/count/costs/cost_resource_ids/can_purchase/reason；count为当下已接纳等级和钱包下可整批支付的最大正整数。连+1也不足时给ok=true/count=0/costs={}/can_purchase=false/reason=InsufficientResources；cost_resource_ids仍保留原+1报价的资源集合。UI显示“可购0级/资金不足”，禁止执行，不把空costs显示成免费升级。所有金额文本由Owner给出，UI不解析、反算、搜索或取整。 |
| 原`Reactor.purchase(10, false, inputs, pay, publish)` | ×10直接复用既有一次整批报价、pay候选钱包、_submit求值及publish接纳；整批买不起普通拒绝，零部分成交。不是循环10次+1。inputs仍由宿主即时注入Session.reactor_inputs。 |
| `Reactor.purchase_max(inputs: Dictionary, can_pay: Callable, pay: Callable, publish: Callable)` | 点击时在同一同步调用栈用当前等级/钱包重新求MAX，不接收或信任预览count；count=0普通拒绝且不调用pay/publish。正数只调用一次原purchase(count,false,inputs,pay,publish)，费用与支付再沿原路径校验；成功才附本次实际count与costs规范文本，失败沿原结果，不把预览数量当已成交。 |

**MAX求值与终止：** 只复用原_quote与Amount.sum_ceiled_geometric（原L级下一项起点L−1、逐项ceil及其现有极大Amount口径），不以+1报价乘count，不另造初级价格特例、封顶或升级折扣。对费用调用注入Economy.can_pay，传入脱离所有者的费用；只有其明确InsufficientResources可作为搜索的不可支付边界。原_quote/Amount/比较/格式化等其他错误整口返回失败，不将其当不可支付继续搜后返回较小“MAX”。extreme沿原Amount口径是表示事实，不自创为失败或新价格上限。

搜索只在1..(9223372036854775807−当前level)内，安全倍增找到不可支付上界，再用`low+(high-low)/2`二分，避免有符号加倍/中点溢出；至多63次扩界及63次二分，不逐级购买、不任设较小搜索上限。最后核n可支付、n+1不可支付才称MAX；若level已无正整数空间，或可支付一直延伸到最大可表示等级而无法证明业务MAX，明确ReactorLevelRangeExceeded，不把机器边界冒充玩法上限或返回截断MAX。错误、搜索和读取均不写等级、钱包、分配、prepared或通知，不新增RunState.fail。

**既有业务不变：** 手动×1/×10/MAX固定automatic=false，不设置_distribute、不自动花掉新增容量；现有自动岗位仍每秒买1级并均分。原_purchase的原等级/费用准入、原_evaluate、Session.publish_reactor的native→Reactor.accept→贡献/钱包接纳及原故障语义复用，不宣称native故障可回滚。不得新增确认/还原步骤；已有分配相关UI由反应炉组按用户指示处理，不改后台分配规则。

**失效与消费：** 等级或开放变化使相应固定数量及MAX报价失效；钱包变化按cost_resource_ids交集使支付性及MAX数量失效，尤其MAX=0时也必须订阅原资源ID。×1和×10费用/文本可按level/count及会话固定配置缓存，预算变化仅重验固定数量支付性；MAX须重新搜索当下支付边界，可为新探测数量调用原_quote，不能套用旧+1“所有预算刷新零报价计算”的验证结论。报价不锁价；命令当下重算，成功后以实际回执和已接纳模型更新。原presentation_changed/budget_changed局部dirty、隐藏停止投影、换Session重绑继续适用，不新增全局总线或轮询。
