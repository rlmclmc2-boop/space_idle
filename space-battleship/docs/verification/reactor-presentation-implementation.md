# 反应炉最小展示与局部通知：实现候选

分支`feat/amount-safe-previews`，实施前固定`3d14ded89ce8e91395d64d23a49d9d520edb6818`。该设计已获根线程及反应炉原独审核限定通过；**本运行候选待原双审、未合main**。唯一规则入口仍为[设计README](../game-design/README.md)，正式字段见[反应炉分册9.2.1](../game-design/contracts/reactor.md#921-实现候选真实展示与局部变化通知)。原M10 WIP保留、不纳入提交。

## 出口与接线交付

| 出口 | 当前实际字段/约束 |
|---|---|
| `Reactor.presentation_model()` | 成功给ok/level/capacity/allocated/remaining/load/can_allocate/reason/modules；modules给id/enabled/manual/free/effective/factor/has_free/ratio/load。文本是原Amount规范文本，比例为有限float。仅读已接纳缓存，未知或开放集合不匹配返回ReactorSnapshotUnavailable，未开放ReactorLocked。无purchase_quote，不接收外部新inputs预测current。 |
| `Reactor.purchase_preview(Economy.can_pay)` | 固定+1，ok/count/costs（resource id→规范String）/can_purchase/reason。成本和文本缓存只跟随已接纳level/会话固定配置；预算变化仅验该原成本可支付性。原_purchase/_quote及等级范围判断复用，确认仍原purchase；不保证之后native提交必成。 |
| 原allocation_plan_preview / apply_allocation_plan.actual | 保留原规范文本、命令与拒绝政策，current/target/actual行增同口径enabled/ratio/load/has_free，顶层增load；均分/Amount求值沿原算法。 |
| `Reactor.presentation_changed(changes: PackedStringArray)` | level/capacity/availability/allocation/free/effect/readiness；替换_state或开放事实**之前**捕获首次基准，同步调用栈结束后deferred核最终净差，合并发送；无净变不发。读取/prepare/discard/普通拒绝不发。 |
| `Economy.budget_changed(resource_ids: PackedStringArray)` | 四类真实钱包写入之前捕获首次基准，deferred用Amount.compare核净差；缺键/零、表示差异、本轮净回原值不误报。保留原notify/display/drop通知顺序；notify=false不漏新预算事实。 |

消费者固定`implement/reactor-centered-godot@170849dd`，仅只读核对其main/scene：reader调用和上述字段/信号形状一致，已移除旧choices连接，预算回调按costs.keys交集只标记quote dirty。**本提交不修改或运行该消费者。** UI组在其原分支集成本候选；不得在当前旧8b消费者同时保留choices全场景invalidate而宣称无双刷新。成本资源及本地化用公开costs，不读_parameters；时钟context独立给game_time/paused/running。

## 所有权与净变化边界

- Reactor._adopt、成功restore_state和真正refresh_availability变化，只排一次deferred检查；基准在赋值前保留。比较已接纳level/容量/模块顺序/assigned/free/value及准入/就绪，不扫描整份save、不重新_evaluate或_quote。发送前清queued/取走基准，重入随后独立排队，发送后不写回旧快照。
- 直接purchase/allocate/distribute/refresh、整组提交、Session.publish_reactor、publish_equipment_refit、_publish_world_values、进度开放、refresh_growth及初始化/恢复均由原_adopt/开放事实汇点覆盖。实际Session/native购级、外部世界值与配装重建已定向运行；其余分支以同汇点源码追溯和模块装配覆盖，不冒称全玩法遍历。
- Economy只在restore_state、accept_budget、collect_drop、credit_yield四类原_wallet写入前排队。支付候选/验资、掉落出生/移动/登记、窗口裁剪与显示格式化不触发新预算信号；正增量因Amount精度未改变最终余额也不误报。
- 新报价读口不调用presentation_model或allocation_plan_preview；预算单独变动不重新计算价格、不格式化模型或求比例。真正level变动才换价；输出及传给can_pay的原成本均深复制，不能由客户端修改缓存。
- C>0时ratio=manual/C、模块load=effective/C、核心load=Σeffective/C，均用原to_ratio有限饱和。合法C=0由原_evaluate得到免费/有效量0及效果1；不是把未知置0。非法C=0/F>0夹具只验证拒绝展示，不当新规则或合法玩法证据。

## 必要定向证据及限制

[固定探针](../../foundation/tests/_reactor_presentation_probe.gd)使用生产编译配置与同一FoundationAmount/native DLL，显式装配等级、预算、开放、免费量及候选窗口。修改前Reactor/Economy取3d14原始Git字节；基线Session只把这两项preload指向临时原版，不复制业务算法。另沿原077cd522 Research源码运行既有Amount回归。

- 最终103项断言：当前/target/actual原文本及数值、原命令/状态/钱包结果与基线一致；读取纯度及返回深改隔离；未知、零容量、免费独立负载、极大Amount和饱和。
- 首次接纳/余额替换前基准明确检查；prepare/discard/拒绝零新通知，同帧多次一次净变化，A→B→A及同结果发布零次，deferred回调重入不被旧基准覆盖。
- 旧choices计数保持原行为，新presentation-only观察者仅一次模型读取；无净变整组命令仍可能发旧choices，因此UI组必须按170849dd的接线移除旧全刷。此项不是实际UI读取计数验收。
- 四类预算写入、静默接纳、零入账/精度不变、缺键与零、窗口/显示/掉落出生移动、实际领取、重入已覆盖。缓存报价预算刷新时pow/sum_ceiled_geometric/to_ratio/to_display均零调用；成本变更只跟随真实接纳level。未写模拟消费者或以夹具冒充真实UI。
- 实际两个Session/native对照覆盖purchase、外部世界容量/免费量发布及publish_equipment_refit接纳，结果/钱包/已接纳Reactor状态同基线；通知后读取到完整钱包与等级。显式世界来源调整是边界夹具，不是自然解锁/游玩证明。
- 新探针、既有候选纯度回归、既有Amount预览回归、当前main入口check-only均退出0，无ERROR/WARNING。四份[原始日志、源码/基线/依赖及不变方法清单](reactor-presentation-evidence/manifest.json)可追溯；按局部-text保存CRCRLF原始stdout，单独核Git blob，不为消除空白提示改日志字节。

首轮受限运行的系统证书库提示不计正式证据；正式日志在正常宿主权限采集。未改变生产条件来适配夹具。未运行Linux消费者/新UI，未测完整游戏/native全组合、性能、原生故障或长期保存；这些不是本次通过项。没有独立复测或实现双审通过声明。

## 复现

沿foundation/README.md使用清单匹配的Godot4.7.2、API/native与配置。设置SPACE_IDLE_NATIVE_EXTENSION、SPACE_IDLE_GALAXY_PROBE_CONFIG；将3d14的Reactor/Economy原始字节写临时.gd，基线Session仅改这两个preload，分别设置SPACE_IDLE_REACTOR_PRESENTATION_BASELINE、SPACE_IDLE_ECONOMY_PRESENTATION_BASELINE、SPACE_IDLE_REACTOR_SESSION_BASELINE。Godot执行`--headless --path . --log-file <临时日志> --script res://foundation/tests/_reactor_presentation_probe.gd`。既有两回归仍用原脚本，Amount回归另设置SPACE_IDLE_RESEARCH_BASELINE为077cd522原Research；入口检查仍`--check-only --script res://src/main.gd`。不提交临时基线、配置、DLL、缓存或存档。
