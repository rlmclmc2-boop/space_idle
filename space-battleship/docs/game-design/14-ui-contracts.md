# 14 模块前后端连接契约

[唯一入口](README.md)。本页定义公开读取、命令、结果、通知和跨所有者接纳；各模块字段由对应分册维护。呈现标准见[13](13-art-interaction.md)。

## 1. 版本与使用边界

后端Owner拥有规则、费用、容量/开放、进度、随机和真实状态；前端读取公开事实，提交稳定对象ID与候选输入，显示实际结果。跨模块动作经GameSession协调口或注入callable，普通动作调用所属模块。

本页及分册是接口要求。分册第2节的既有连接记录以`main@e3b38d7b6d8256f6031e1b086c7db7812b6a441f`为核对起点，后续具名节补充接口要求；接入时按[11](11-stage6-contract.md)的当前固定源核实所需端口与消费状态。资源值与结算见[资源契约](contracts/resources.md)，数量/费用控件见[13§2.3](13-art-interaction.md#23-所有模块共享的状态与反馈)。

## 2. 主线现有模块连接

公开方法由`src/systems/<模块>.gd`或`src/game_session.gd`提供，前端由`src/ui/`消费。选择所需分册：

| 模块 | 唯一接口正文 |
|---|---|
| 战斗/航程/拾取 | [战斗/航程/拾取](contracts/battle.md) |
| 舰体/装备 | [舰体/装备](contracts/equipment.md) |
| 反应炉 | [反应炉](contracts/reactor.md) |
| 科研 | [科研](contracts/research.md) |
| 强化 | [强化](contracts/enhancement.md) |
| 船员 | [船员](contracts/crew.md) |
| 星球 | [星球](contracts/planet.md) |
| 星系 | [星系](contracts/galaxy.md) |
| 超空间 | [超空间](contracts/hyperspace.md) |
| 档案/通知/设置 | [档案/通知/设置](contracts/persistence.md) |

## 3. 当前接口缺口的处理

消费者列出实际需要的输入/输出及固定版本中的缺口，由接口Owner维护相应公开端口。

## 4. 查询、操作结果与单一消费事件

- 查询读取已接纳事实；返回值按其副本/只读约定消费。Amount保留规范文本精度，概率、坐标和秒数使用约定类型。
- 命令提交稳定ID与候选输入。拒绝显示领域reason并保留可修正草稿；成功显示实际费用、余额和结果，各命令附加字段见分册。
- 消费事件按模块指定的唯一消费者取走；持久状态使用独立查询。伤害事件见[战斗分册](contracts/battle.md)。
- 危险预览持续到确认、取消或失效，绑定对象、来源和输入；确认沿所属事务的幂等与当前校验语义执行。
- 变化通知使相关对象/选项失效，在可见显示帧合并读取；隐藏停止局部投影，重开读最新事实。各模块明确自己的通知或轮询方式。

## 5. 既有跨模块接纳与通知约束

以下协议定义后端所有者的协调；前端通过各分册的动作或注入callable进入。

模块化的边界是业务入口和结果，不是信号连接顺序。模块只能拥有自己的候选与已接纳状态；`GameSession` 只协调具名端口，不读取候选内部字段来决定下一步，也不以 UI 通知承担接纳。入口返回 `ok=true` 表示本次业务交接已完成；`ok=false` 且 `fault` 不为真表示普通拒绝，当前子命令的所有者保持原状态。批量购买可能先接纳已成交子项，再返回后续子项的拒绝，已成交部分不回滚。native 或几何在提交中发生致命故障时 RunState 停机，不假装已回滚。通知只在所有受影响所有者完成接纳后发出；监听者同步读取应得到同一批状态。发出通知后，外层调用不得再写回该批的旧候选，以免覆盖监听者的重入操作。

| 所有者 / 入口与输入 | 输出与成功含义 | 状态、拒绝、故障和通知 |
| --- | --- | --- |
| Equipment `equip_slot`、`buy_all_levels`、`resize_mounts`：部位/选择、当前装配事实、报价与支付、`publish_equipment_refit` 或 `publish_equipment_levels` | `ok` 表示 native 接受且装备候选、钱包、船型/必要撤退已接纳；批量购买允许已成交部分保留，空批次返回 `NoChange` | Equipment 独占槽位候选和槽位账本；Session 调用 `accept_prepared`，再发布 `slots_changed`/`loadout_changed`。普通报价、支付或 native 拒绝丢弃候选；致命故障停机。防御换型按[03第1.4节HealthAdjustment](03-progression.md#14-容量改变时的生命规则)保留同类总当前/总最大比例并重建模块损伤；未决仅为[03第1节首槽换型](03-progression.md#1-舰体槽位与升级)本身使两类当前余量均为0时是否立即进入死亡判定。 |
| Enhancement `purchase`、`set_order`、`set_branch`：可用性/装甲数、报价、native 发布口 | `ok` 表示强化状态、native 值及钱包/必要撤退全部接纳；无变化跳过 | Enhancement 独占强化候选，经 Session 的 `publish_enhancement` 后显式 `accept_prepared`；不发业务接纳信号。拒绝不写强化或钱包，致命 native 故障停机。 |
| Reactor `purchase`、`allocate_text`、`distribute`、`refresh`：容量、开放模块、支付与 native 发布口 | `ok` 表示分配状态、native 值及钱包/必要撤退已接纳 | Reactor 独占 `_prepared_state`；Session 调用 `accept` 后更新贡献和钱包。普通拒绝丢弃候选；致命故障停机。`choices_changed` 仅作接纳后的 UI 提醒。 |
| Planet `claim_build`：建筑、贡献发布口 | `ok` 表示建筑、世界贡献、native 和必要撤退均已接纳 | Planet 独占建筑候选；Session 通过 `accept_prepared_claim` 显式接纳，再发建筑/开放通知。普通拒绝不改变建筑或世界贡献；故障停机。 |
| Campaign `advance`、`observe_battle`：固定步长、native 战斗结果、终波领取口 | 返回位置变化事实；清关和新关事实在完整关卡位置/战点更新后可见 | Campaign 独占关卡、波次、驻守和撤退。`take_progress_changed` 交给 Session 同步 Research、Reactor、Equipment、Crew、Planet、Galaxy 的开放缓存和必要贡献；之后才发布进度与状态通知。终波收取先批量接纳，随后统一通知。普通关卡拒绝不推进；native/几何故障停机。 |
| Economy `payment`、`accept_budget`、`collect_due`：费用、候选钱包、拾取时间和收益因子 | 支付只返回候选钱包；`accept_budget` 后才归属变更；批量领取返回 `collected` | Economy 独占余额、掉落和收入历史。通知可延至跨模块接纳后；终波多个掉落合并通知。拒绝不扣款或领取；已领取后续致命故障停机，不虚构回滚。 |
| Battle `commit_player`、`commit_values`、`advance`：准备好的战斗描述与变更种类 | native 接受后返回 `ok`/`defence_changed`；结果只含已发生的战斗事实 | Battle/native 独占战斗状态与攻击出生快照；普通拒绝不接纳外部候选，`fault` 触发 RunState 停机。Session 只根据公开结果完成其他所有者接纳。 |
| Research `refresh_progress`/`advance`、Crew `refresh_availability`/`contributions`、Galaxy `refresh_availability`/`contributions`：Campaign 开放查询或时间/分配事实 | 返回开放变化或贡献；成功后由所属模块持有状态 | 各模块独占自己的开放缓存与进度。Session 先同步相关缓存及贡献，再调用独立 UI 通知端口；不以模块私有字段或消费者刷新顺序作为契约。普通拒绝保持归属状态，推进中故障停机。 |

一次命令的时序为：模块校验并保留候选 → Economy 给出候选钱包 → Session 组装并提交 Battle/native → 所属模块显式接纳 → Session 接纳钱包、世界/研究/反应炉贡献、船型与必要撤退 → 发布各模块展示通知。没有效果的命令跳过提交；部分批量成交只提交已成交部分。通知可同步重入，新命令必须看到上一批完整状态，上一批外层调用此后不再改写它。

终波的 native 掉落登记与强制领取先静默进入 Economy；Campaign 完成清关事实，Session 同步开放缓存，再按本步最终收入刷新贡献，最后合并发布掉落/余额、开放和进度通知。非终波新掉落也在该步 Campaign 处理完成后通知。致命 native 或几何提交故障的公开结果保留 `fault=true`，供调用者区别于普通拒绝。

## 6. 前端本地状态与资产接口

选择、草稿、焦点、展开、滚动、pan/zoom、显示变换和临时反馈归前端；等级、钱包、占用、进度、随机、贡献及保存事实归Owner。刷新保留未提交草稿，对象失效时清除旧详情及提交目标。

资产、布局与业务以稳定对象ID和公开端口连接；画布、可见边界、锚点、图层与导出约定见[13及M/V](13-art-interaction.md#3-按模块读取设计与验收)。

## 7. 已实现出口：敌盾与双条的最小战场展示契约

见[战斗分册](contracts/battle.md#7-已实现出口敌盾与双条的最小战场展示契约)。

### 7.1 实现前基线与已实现出口

见[战斗分册](contracts/battle.md#71-实现前基线与已实现出口)。

### 7.2 身份、快照与失效

见[战斗分册](contracts/battle.md#72-身份快照与失效)。

### 7.3 隔离、Amount与绑定边界

见[战斗分册](contracts/battle.md#73-隔离amount与绑定边界)。

<a id="8-已审待实施成员设施与选中节点的最小只读事实"></a>
## 8. 实现候选：成员、设施与选中节点的最小只读事实

### 8.1 共同读取与身份边界

公开数组与嵌套行是脱离所有者的快照或递归只读值；查询投影已接纳事实，未知值用约定null/空字段。Amount以规范文本输出，有限float仅表示绘制比例。会话替换/恢复及对象失效后重建绑定和缓存。各模块的对象身份见对应分册。

### 8.2 Crew：成员事实

见[船员分册](contracts/crew.md#82-crew成员事实)。

### 8.3 Planet：设施事实

见[星球分册](contracts/planet.md#83-planet设施事实)。

### 8.4 Galaxy：选中节点事实

见[星系分册](contracts/galaxy.md#84-galaxy选中节点事实)。

### 8.5 失效通知与独立落地边界

可见帧合并读取，隐藏停止投影，重开取最新事实；定义、Amount文本和未变快照按实际来源变化重建。

## 9. 已审设计：反应炉整组草稿与科研预算的Amount安全预览

### 9.1 单位与共同读取边界

- 比例输入为整数基点`0..10000`，10000表示100%。Amount金额、容量、速率、工程量、倍率及任意时长以原规范文本输出；业务复用原Amount求值。比例先在Amount域除10000，再乘基准并floor，不能先把大额转float/Number/BigInt或用控件位置重算。有限float只用于基点控件/进度条，不重建数量。
- 预览只读已接纳状态与同一次同步新读的来源；不调用命令、prepare/accept、推进、扣款、抽样或保存，不制造RunState故障。现行_capacity会写容量缓存，_required_work会写required_work；纯预览不得直接对所有者真状态调用它们。须提取无副作用求值或在脱离所有者的数据（含会写入的嵌套缓存）上求值，不借读取填写业务字段/缓存。返回行及嵌套数据均脱离所有者或递归只读。
- 结果分开`current`（已接纳）、`target`（本草稿条件下）、`source`（外部必要的公开结果事实）；`can_apply/reason`只说明本次检查，不承诺下一次提交必成。未知值用null及具体原因，不补0/×1。Amount短文本由提供方格式化，canonical全文保留用于精确提交；UI不从短文本还原值。
- 净收入不向非负Amount塞负数：用`direction=surplus/deficit/balanced`与非负`amount`文本表示差额。持续时间用Amount的`div`求游戏秒，可供提供方格式化；`to_ratio`被限制在[0,1]，仅能作显示比例或既有有界分段系数，不能作为秒数。

### 9.2 Reactor：整组分配预览

见[反应炉分册](contracts/reactor.md#92-reactor整组分配预览)。

### 9.3 Research：单工作点预算预览

见[科研分册](contracts/research.md#93-research单工作点预算预览)。

### 9.4 草稿、来源变化与失效

草稿与来源变化的消费方式分别见[反应炉](contracts/reactor.md#草稿与来源变化)、[科研](contracts/research.md#草稿与来源变化)。

## 10. 实现候选：超空间只读预览与星球自动设置

见[超空间](contracts/hyperspace.md#10-实现候选超空间只读预览与星球自动设置)与[星球](contracts/planet.md#10-实现候选超空间只读预览与星球自动设置)。

## 11. 实现候选：装备比较、强化摘要与成交回执

见[装备](contracts/equipment.md#11-实现候选装备比较强化摘要与成交回执)与[强化](contracts/enhancement.md#11-实现候选装备比较强化摘要与成交回执)。
