# 超空间前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 超空间：hyperspace_panel | Hyperspace `routes/online_status/manual_receipt/warehouse/module_growth/filter_configuration/legend_collection/player_catalog/material_ids`；钱包由Economy `budget`提供 | Session `start_hyperspace_manual/start_hyperspace_single/start_hyperspace_auto/claim_hyperspace/equip_hyperspace_drones/set_hyperspace_hangings/dismantle_hyperspace_drone/exchange_hyperspace_materials/save_hyperspace_preset/apply_hyperspace_preset/preview_hyperspace_forge/forge`；模块 `organize/set_favorite/set_filter/import_filter/export_filter/set_legend_collected/release_sealed` | 主线没有领域变化信号，当前界面每秒读取并保持选择；不是已具备对象级通知 | 仓库区/筛选/选择、编队与改造草稿、预览fingerprint/source/operation_id/完成状态。原请求绑定、失效和幂等仍有效。 |

## 3. 候选展示扩展与尚未补齐的交换

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 超空间 | 只读 `forge_display_limits(id)`；页面补究极核心余额、预兆/究极词缀/传说参数、装卸对象与具体拒绝原因 | 仓库/挑战对象级通知仍无实现。若需增补，只加受影响对象/状态的最小通知，不重写成全模块事件广播。 |

| 候选查询 | 已有候选字段 |
|---|---|
| Hyperspace.forge_display_limits | `affix_limit/hanging_limit/reroll_ranges[]`；范围行 `kind/key/minimum/maximum`，普通词缀另有tier。不表示随机结果已取得。 |

## 10. 实现候选：超空间只读预览与星球自动设置

[本节版本与实施范围](../14-ui-contracts.md#10-实现候选超空间只读预览与星球自动设置)。

| 出口与消费者 | 最小输出与语义 |
|---|---|
| Hyperspace `routes()` → M9路线行 | 保留route/weapon/cleared，加`best_time: float或null`，只指当前最高已过层有效最佳游戏秒；无记录为null，不把更低层最佳、在线10秒下限或现实倍速后的秒数替代它。 |
| Session `hyperspace_idle_preview(route: String, automatic: bool, crew_id: String="")` → M9单次/自动确认 | 成功回`ok/route/level/automatic/duration`，duration是现行完整游戏时长；单次`crew=null`，自动`crew={id,level,luck}`取现行Session实际来源的开始快照。拒绝保留原reason，不输出伪造时长/人员目标；不返回receipt/run_id/RNG或奖励。输入不收客户端等级、幸运、容量。 |
| Hyperspace `preview_filter_import(text: String)` → M9导入前审阅 | 成功回`ok=true/candidate`，candidate是脱离当前规则的规范v2五字段version/enabled/mode/action/conditions；枚举ID目录复用player_catalog的weapons/qualities/affixes/legends四类，minimum_level是数值条件。失败沿原`InvalidFilterShare/InvalidFilter`及规范化准入。 |

Session预览与两个开始命令共用准备链，保留拒绝顺序：单次为RunState→开放→prepare_idle；自动为RunState→AutoRunning→开放→Crew准入→prepare_idle。prepare_idle继续负责UnknownRoute、在线任务占用、最佳时间和原时长等判断；预览不调用reserve/accept、不推进随机/任务/序列、不发通知。合法恢复/装配已校验保留一致性，不新造占用模拟器；预览不锁定资源，开始仍按最新状态重新准备，只有开始自动才保留船员。

## 12. 实现候选：M9仓储、挂设、改造与确认前读取

设计`cad1ee17`及分册修正`09af963c`已双审；本节运行候选待定向双审、未合main。实现与定向证据见[M9实现记录](../../verification/m9-readonly-implementation.md)，不代表UI接线、完整V9或游戏验收。原第3节b7bb候选是历史版本；本节出口以当前分支为准。

| 出口 / 消费者 | 最小输出与边界 |
|---|---|
| Hyperspace `warehouse()` → 容量条 | 原深复制实体/保护/预设字段保留，补`main_capacity/overflow_capacity`复用现行容量；`retention_capacity`独立。读取不整理或处理仓库。 |
| Session `hyperspace_module_details()` → 挂设成长/开放 | `rows`给实际五类id、unlocked/level/exp、required_exp及有限progress_ratio、per_copy_bonus和当前装备来源aggregate_contribution、unlock_stage及available/reason。经验与贡献保留现行float域，共用原求值；不可表示为null和对应growth_reason/per_copy_reason/aggregate_reason。available取实际cycle_reached，不用终身最高；阶段不足不清除已接纳贡献。这些是来源贡献，不是最终全局收益。 |
| Session `hyperspace_hangings_preview(id,module_ids)` → 所选机安装确认 | 复用原prepare_hangings，成功只投影规范String id/hangings和`admission_scope=hyperspace_prepare`；拒绝保留原reason。实际已购槽、封存、究极、重复/未解锁/阶段原判断保持；溢出项不新增禁止安装。 |
| Hyperspace `forge_display_limits(id)` → 改造参数区 | id/forge_revision、affix_limit、允许增长hanging_limit、实际hanging_slots和preserved_hanging_slots分开。reroll_ranges普通词缀含index/key/tier，传说含effect_id/parameter；各行给当前原始值、minimum/maximum、locked/modifiable/reason。锁定项范围可见，封存/究极阻止修改；额外究极词缀继续取warehouse，不挤占普通限额。范围不是完整操作许可。 |
| Session `preview_hyperspace_forge(id,operation,args)` → 当前操作Quote | 原forecast及其costs/draws/局部drone候选保持，补source{id,forge_revision}、cost_amounts（原费用转Amount后规范文本）、can_pay/payment_reason；装备中且可支付时，loadout_admission复用替换该机的原prepare_loadout并只投影具名结果。未检查时为null；成功仅`hyperspace_prepare`范围，不保证完整native组合许可。随机候选不当已获属性；确认仍原forge重验、付款与operation_id幂等。 |
| Session `hyperspace_loadout_preview(ids)` / `hyperspace_preset_preview(name)` → 编队/预设确认 | 取真实船型容量/轮次、已接纳普通槽的最高付费级及原成长，复用prepare_loadout/prepare_preset。仅给规范ids、预设逐机entries和ok/reason、admission_scope=hyperspace_prepare，不暴露contributions。原整组拒绝及输入顺序保持；不承诺普通炮+无人机native全部检查。新查询不跟随_pending_slots；原命令准备仍优先pending，accept/discard后新读跟随actual。 |
| Session `hyperspace_dismantle_preview(id)` → 拆解详情 | 原prepare_dismantle保护/局部随机准备后，仅给id/removed_ids、原materials/ultimate_cores、确定hanging_copies；hanging_kinds=pending_settlement，不返回具体随机挂设种类或未来成长。确认仍走原拆解、世界贡献与实际reward。 |
| Session `hyperspace_exchange_preview(source,target,amount)` → 连续兑换 | 与原命令共用完整准备，amount仍是希望收到的正整数目标量；成功给source/target/payment/received规范Amount文本，不返回候选钱包。保留RunState→材料ID→解析/正整数→倍付→原payment含扣源→目标旧余额+received的Amount.add顺序与错误。可支付不等于完整兑换准入；查询成功已包含候选扣源及目标加款。确认重走完整准备后才接纳/通知。 |

所有新读取仅返回已接纳事实或脱离候选，不接纳、扣款、推进奖励/幸运/本机随机流、改修订号/序列或发送领域通知；不为读取新增RunState.fail。原业务随机、费用、准入、候选pending及部分失败政策保持。预览不锁对象、价格或资源；forge_revision仅绑定本机改造来源，不代表预算/挂设/保护/进度/船型的全域版本。

沿当前可见读取与命令后受影响事实重读刷新；来源/参数变化清旧确认，对象消失清详情；实际回执与下一预览分开。当前读取不增加对象事件框架。保存宿主摘要、真实几何、未定乘数与未来收益仍排除。
