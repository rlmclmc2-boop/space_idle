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
