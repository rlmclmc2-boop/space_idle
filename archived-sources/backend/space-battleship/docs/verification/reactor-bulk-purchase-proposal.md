# 反应炉手动×10/MAX：Owner最小契约与实现记录

**下述提案为`c6170694`历史设计核对；按根线程继续授权实施的当前候选待原双审、未合main，实际出口和定向证据见文末。** 用户已要求升级×10/MAX且确认/还原都不需要；本候选仅补缺失的Owner报价与MAX执行接口，前端呈现与分配UI处理归反应炉组。唯一规则入口仍为[设计README](../game-design/README.md)，新增契约唯一正文见[Reactor 9.2.2](../game-design/contracts/reactor.md#reactor-bulk-purchase)，不复制费用公式作为另一个权威。

## 固定现场与证据

| 对象 | 固定版本与Git blob | 定向事实 |
|---|---|---|
| 当前Owner | feat/amount-safe-previews@b734dc2e9e004b12d7e76ba1de9a00394eb5561c；src/systems/reactor.gd blob `302b6f58997aa2f52889c7f74c563c4e849b24b2` | purchase(count,automatic,inputs,pay,publish)已支持一次整批；purchase_preview仅+1，无公开MAX查询/执行。 |
| 反应炉消费者 | [17710fc787431c569b930cf952fe5c8dd094f18f](https://github.com/rlmclmc2-boop/space_idle/tree/17710fc787431c569b930cf952fe5c8dd094f18f)；src/main.gd blob `cd7bf8af0a9250c0d9457d3e25ccb185025fabeb`，src/ui/reactor_scene.gd blob `7e560d07a2d27f81d8090d8520188ef5f42760cf` | main单参purchase_preview(can_pay)；scene第218行purchase(1,false,...)，尚无×10/MAX消费。 |
| 共享消费者 | [224fa5005e8d0a7c89aa6e7570a78ead71408583](https://github.com/rlmclmc2-boop/space_idle/tree/224fa5005e8d0a7c89aa6e7570a78ead71408583)；src/ui/reactor_scene.gd blob `c60785f80c162bc5cc1e867009249583bd667aa5` | scene第220行仍purchase(1,false,...)，第222/223行确认/还原属于分配UI；共享Reactor源码blob与当前Owner完全相同，不能把已有多级purchase当公开MAX报价。 |

两远端版本经已连接GitHub fetch_file按完整SHA只读核对；定向git fetch长时无输出后中止，无checkout/分支变更，不把未完成fetch当对象已拉取。当前原目录未被其他组推进；M10 WIP SHA256=208cb3d6d24dd214b642f8dda470a3326152856bd608658d335ca85f93966158、179项tracked与262项untracked元数据保留，不stage。

## 已有路径与最小差异

- Reactor.purchase先核运行/开放，原_purchase→原_quote（原Amount等比逐项ceil总价）→Economy.payment产生候选钱包→_submit求候选效果→Session.publish_reactor；后者先native成功，再accept、贡献及钱包接纳。count=10本来就是整批准入/整批费用，不要求10次动作；automatic=false本来就不触发均分。源码均不因本次文档改变。
- 缺口确为公开批量报价、MAX搜索和执行时重算；仅交本提案尚不能完成UI功能。拟对既有purchase_preview增可选count，另增purchase_max_preview与purchase_max，完整字段、机器边界和错误语义以9.2.2为准。原+1单参兼容，不另写购买算法；手动新容量不自动分配，原自动岗位不变。
- 原_quote的Amount失败不能当成余额不足；signed-int边界不是新游戏等级上限。MAX=0须明确不可执行，且公开cost_resource_ids避免空costs导致预算增长后永远不刷新。MAX命令重新搜索当下数量，再一次原purchase；不消费陈旧预览或让UI自行重算。

## 审后必要验证边界

后续实施需原审通过；仅验证本次新增出口和复用路径，不扩大后台范围：固定×10与原_purchase/真实payment/publish等级及钱包一致，恰好支付与少1单位整批拒绝；MAX的n可支付/n+1不可支付、0、等级/预算改变后重读及执行当下重算；Amount错误/比较错误传播、signed-int安全终止、极大值沿原口径；读纯度/返回隔离、零失败通知、一次支付/发布、automatic=false分配不变；+1原消费者兼容与局部资源dirty。实际UI、取消确认/还原按钮及共享集成由反应炉组验证。

本执行者尚未实际压缩。当前只固定最小文档候选供审，不声称接口已实现、消费者已接入或完整验收通过。

## 实现候选与必要定向证据

实施基线`c61706942675a25857c425cdf775d28c89154298`；本次仅改Reactor所有者，消费者两个固定版本及UI源码均未动。可消费入口以[Reactor 9.2.2](../game-design/contracts/reactor.md#reactor-bulk-purchase)为唯一正文：`purchase_preview(can_pay,count=1)`、`purchase_max_preview(can_pay)`、`purchase_max(inputs,can_pay,pay,publish)`。原+1单参兼容；×10执行仍`purchase(10,false,inputs,pay,publish)`。报价给cost_resource_ids，MAX=0也保留原资源身份，前端必须按此过滤预算事件，不再只用空costs.keys。

- 原_quote/_purchase/purchase/_submit及Session.publish_reactor源码保持不变；固定数量仅读脱离候选，×1/×10费用文本按已接纳level/count缓存，预算仅重验支付性。MAX只保存局部搜索边界，不写领域状态/候选/钱包；仅InsufficientResources作为不可支付边界，其他错误完整返回。MAX命令格式化先于支付/发布，成功回执附实际count/costs；不可能成交后因新增格式化返回失败。
- [固定Owner探针](../../foundation/tests/_reactor_bulk_purchase_probe.gd)使用原c617 Reactor原始Git字节作报价对照，生产配置与现有FoundationAmount/native；61项断言通过。覆盖初始+1原价、精确×10及少1单位整批拒绝、固定数量缓存/结果隔离、MAX的0与资源ID、1/2/9/10/31/100/500级n可付及n+1不可付、读纯度/零事件、报价/比较/中途搜索/显示错误、支付/发布拒绝及signed-int边界。
- 实际Session/native：×10整批一次payment/publish；少1单位不改钱包/等级且不publish；MAX预览5后预算降到2，点击当下重算实际买2，实际count/costs与钱包一致；两种成功动作均保留原非零手动分配7，未自动均分。此为明确边界夹具与真实接纳路径，不代表自然游玩或完整事务组合验收。
- 当前main入口check-only退出0；两份正式[日志与SHA256清单](reactor-bulk-purchase-evidence/manifest.json)无ERROR/WARNING。源码/文档diff-check通过，原始入口日志末尾空行按原字节和Git blob哈希保留。未运行消费者UI、完整游戏、性能、长期保存或全部native故障组合；消费MAX资源dirty及去除确认/还原仍由反应炉组验证。

复现：按foundation入口使用Godot4.7.2与同一native/config。将c617的Reactor原始Git字节写临时.gd，设置SPACE_IDLE_REACTOR_BULK_BASELINE、SPACE_IDLE_NATIVE_EXTENSION、SPACE_IDLE_GALAXY_PROBE_CONFIG，以`--headless --path . --log-file <临时日志> --script res://foundation/tests/_reactor_bulk_purchase_probe.gd`运行；入口检查仍`--check-only --script res://src/main.gd`。不提交临时基线、DLL、生成配置或存档。本接替尚未实际压缩。
