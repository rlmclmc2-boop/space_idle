# 前端剩余只读缺口：定向续核提案

仅提案，未实现、未修改规则或配置。按[唯一入口](../game-design/README.md)读取14、04§1–2、03§5及对应还原资料；沿[既有四批审计](https://github.com/rlmclmc2-boop/space_idle/blob/4bbb2f5b915f6e137d60cfd6082d82c525dc40d7/space-battleship/docs/verification/frontend-contract-audit/83112e84.md)续核，避免重复申请已有端口。只列既定玩法下的必要展示，未定规则与共享几何另案排除。

## 固定版本与状态

| 范围 | 本次核对版本及边界 |
|---|---|
| main | `e93c221239a10d377b2ca89dd395ebcfa99c9819`；读取源码，不操作main。14§2较早的08bf基线不能代替本次源码核对。 |
| 当前后端候选 | `0ec9572715a9555774e4ee56b891fff71c2725ff`，`feat/amount-safe-previews`，未合main。包含成员/设施/节点事实（`91bd955c`、迷雾修订`372f8499`）及Amount预览；`6f6f9fd2`浅拷贝本项双审通过，不表示候选整支获准合并。 |
| 较早展示候选 | [14§3](../game-design/14-ui-contracts.md#3-候选展示扩展与尚未补齐的交换)指定`b7bb3de33287783721a8bbd9417f2ea040ad32ff`。其中forge_display_limits、各presentation扩展不能当main或当前分支已有；本次直接核对该查询。 |
| 前端需求 | `design/g1-internal-organizations@a3e05ea05418841821e2acfec6899b900d8d0b90`，只取`docs/ui-redesign-plan/g1-internal/`下tasks、hyperspace、colony、forge、enhancement、maintenance还原资料及godot-restoration对应端口段。浏览器有限响应不是运行实现。 |

## 三项优先增补

| 缺口 → 消费者 | 已有源与当前边界 | 最小提案（方法名为说明，待审核） |
|---|---|---|
| 路线最高已过层最佳时间、单次完整时长与自动候选 → M9路线行/单次确认/选船员自动确认 | main与当前候选Hyperspace文件一致。`routes()`只有route/weapon/cleared；`online_status()`有已接纳任务的duration/work/crew快照，不能当尚未开始的预览。`prepare_idle()`按当前路线历史最佳计算原时长并返回脱离receipt，不写任务/随机流；`Crew.hyperspace_candidate(id)`只读准入和level。Session.start_single/start_auto组合开放、自动/在线占用、人员准入后才reserve/accept。 | `routes()`最小增加当前最高已过层`best_time`（游戏秒，无有效记录为null，原cleared保留，不下发整份history）。增加一个Session具名`hyperspace_idle_preview(route, automatic, crew_id="")`，内部复用开始入口的现行准入及prepare_idle；只投影route/level、ok/reason、完整duration游戏秒、automatic时的crew_id/level/luck快照。单次和自动复用同一入口，不各造页面模型；不返回内部run_id/RNG/奖励凭据。 |
| 分享串导入前审阅 → M9过滤工作台导入预览/确认 | `player_catalog/filter_configuration/export_filter`足够给目录、当前规则、导出；`import_filter(text)`做有界前缀/base64/JSON/整数规范化后直接`set_filter`，后者校验并写_filter。因此它是命令，不能调用后回滚当查询。 | 在Hyperspace拆用原解析/规范化与纯校验，`preview_filter_import(text)`只回ok/reason与脱离的规范candidate五字段及稳定ID条件。import_filter继续复用同一解析校验并接纳；不新增另一过滤求值器、影响预览或仓库扫描。确认仍用原import_filter(text)。 |
| 星球当前自动设置 → M7星球详情/自动开关/人员关联卡 | main及当前`visual_snapshot(id)`均只有running/exploration/elapsed/duration等；`status_rows`是文本；候选facility_facts不含automatic。`set_automatic`是命令，save_state是保存快照，均不充当页面读取口。[14§8.3](../game-design/14-ui-contracts.md#83-planet设施事实)已明确该缺口。 | 在既有`visual_snapshot(id)`加只读`automatic: bool`，读取同星球已接纳设置；沿原未知/不可用返回空快照，不另开planet状态层。与running分别呈现，关闭自动仍是本次完成后停止，不变成cancel。当前候选setter已在设置实际变化后发status_changed；main没有该通知补丁，接main时需最小补通知或明确沿当前刷新，不能冒称main已有。 |

预览边界：Session自行取RunState、解锁/进度、Crew、永久幸运等来源；客户端只传route/automatic/crew_id，不自报等级/幸运/容量。只读组合不调用start/reserve/accept、publish、advance或随机抽样，不消耗run_id，不写保留/任务/凭据；不得调用prepare_auto_continuation代替新任务预览。保留原准入顺序与reason；拒绝时duration/crew目标未知，不伪造0时长或成功。开始时按最新真实来源重验，预览不是预留；进行中消费online_status已绑定任务，浏览路线变化不得改它。

过滤预览不改变current；空串、格式/大小/版本/类型/自身键/条件错误沿同一校验返回原因，不能自动禁用或抹空旧规则。UI绑定原始分享串与candidate，编辑、取消或切换来源即清旧确认；确认对当前串重验，不信任客户端candidate。不增加全局revision或通用事务。五类目录已存在，无需再新增目录口。

## 其余前端：复用与必要缺口清单

以下承接既有审计，并按当前候选排除已补部分；不把每一行解释成独立新接口或本轮实现授权。

| 缺口/消费者 | 现有源 | 最小新增／无需新增 |
|---|---|---|
| M9仓库容量与保护、挂设工作台 | `warehouse()`已有main/overflow/equipped/favorites/sealed/presets（含逐机hangings）及retention_capacity；`module_growth/module_contributions/prepare_hangings`、舰型drone_capacity已有。 | 保护来源/引用预设名可由已有公开事实按稳定id关联，无需新账本。warehouse只补主仓实际capacity（复用_warehouse_capacity）及overflow_capacity；挂设进度需由Hyperspace最小补所需经验/显示进度/当前来源贡献与开放原因，复用现有定义/成长/贡献，不让UI按等级重算。 |
| M9每机允许槽/改造范围、费用可支付 | 实体形态/当前词缀/锁定/forge_revision来自warehouse；Session.preview_hyperspace_forge复用原局部随机返回候选/costs/draws；Economy公开金额/支付查询。较早候选forge_display_limits已给限额及可重抽范围。 | 先审核并复用该候选只读截面，补实际hanging_slots与上限含义，不能把上限当已购槽。报价按既有Amount输出必要canonical/显示金额及不足原因；Session如需显示最终配装准入，复用确认已有prepare_loadout，不把操作预览ok当整组可提交。随机候选不作为已获得结果；不新造改造算法。 |
| M9编队/预设确认、连续兑换 | warehouse已给当前序列/预设entries；prepare_loadout/prepare_preset/prepare_hangings给原准入，Session持有真实容量/进度/武器来源；兑换现行amount是收到目标量。 | 本次装卸/挂设差异先用公开稳定id与entries比较；整组允许性如需预览，由Session薄包装原准备链，不能UI重跑准入。兑换仅在原Amount路径投影目标收到量/源支付量及不足，保持原单位；不新增付款账本。 |
| M9拆解与通知 | prepare_dismantle复用_dismantle_reward；后者用本机forge_rng_state的局部RandomNumberGenerator，未推进真实流。现有查询无对象通知，页面每秒读取。 | 若展示拆解报价，包装现有只读结果，随机副本仍标待结算，不需新抽样器。命令完成先重读受影响仓储/实体/成长；进度可见时沿现行刷新，不以“每屏要通知”新造事件层。后续确有外部失效缺口才补所属对象最小通知。 |
| M6/M7/M8人员、设施、选中节点 | 当前候选member_facts/facility_facts/node_facts已覆盖[14§8](../game-design/14-ui-contracts.md#8-已审待实施成员设施与选中节点的最小只读事实)的最小字段；Crew.step_assignments/galaxy_assignments给当前人员。main未包含这些新增。 | 沿已实现候选接线，不重开全量模型；当前设施来源倍率不是未来领取后最终收益，节点迷雾不泄露预生成类型/目标等级。其余未来贡献/完整岗位效果请求沿既有审计，未确定显示范围的不在本轮新增；Planet automatic仅按上表补。 |
| M3/M4金额预算 | 当前Amount候选已有allocation_plan_preview/apply_allocation_plan、Research.budget_preview及Session公开输入；main没有。较早presentation候选另有工作/效果舞台输出。 | 复用已审Amount候选及明确需要的presentation截面，不重复建比例/ETA端口。持续科研仍原下限/周期及逐资源动作，关闭与本次0草稿分开；未合main状态保持。 |
| M2装备、M5强化比较/报价 | main quote_slot已给确定数量报价；原MAX搜索、Enhancement._quote_purchase/_describe/_combat是权威；较早presentation候选有部分状态但仍含文本。 | 确定数量无需新报价；按既有审计仅补实际数量/总费、固定比较所需具名值及完整效果摘要，不解析中文或内部战斗键。真实历史动态乘数沿native事实，未明确口径的效果/未来收益不在本轮定稿。 |
| M10保存/危险事务、档案 | SaveFiles busy/dirty/saved_change/last_result/last_failure、Session.dirty_since_save已有；import_candidate/prepare_reforge已有summary，main预览包装压成message；替换结果已有persistence字段。通知/敌情/统计原查询已有。 | 宿主薄透传已有结构化摘要及保存/替换结果；不新建保存状态机。通知与教程无需新接口；统计稳定选择若必需才补源ID，BattleView仍唯一消费伤害回执。无需为浏览器示例状态新造协议。 |

## 固定源码定位与审核边界

优先三项直接核对：`src/systems/hyperspace.gd::routes/filter_configuration/set_filter/import_filter/online_status/prepare_idle/accept_idle`；`src/systems/crew.gd::hyperspace_candidate/reserve_hyperspace`；`src/game_session.gd::start_hyperspace_single/start_hyperspace_auto`；`src/systems/planet.gd::visual_snapshot/set_automatic/facility_facts`。其余行对应原审计及本次已读prepare_preset/loadout/hangings/dismantle、warehouse/module_growth/preview_forge、main预览与SaveFiles公开状态；没有把命令、保存入口或字符串解析写成只读端口。

若方案获准，验证只覆盖相应读取纯度、错误/规范化与开始/确认最新状态重验：自动预览前后保留/凭据/run_id/随机流及通知不变，导入预览不改_filter、确认仍拒绝非法串，Planet读取反映实际设置且不推进/取消。预览所得秒数沿游戏时间，不新增现实ETA推算。本轮仅链接/差异和固定源码核对，未跑游戏测试；main暂停，真实参数与未决规则不纳入本提案。
