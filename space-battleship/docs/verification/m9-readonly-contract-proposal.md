# M9剩余只读截面：最小待审提案

仅文档，未批准、未实施接口/规则/UI。承接[原剩余清单](frontend-readonly-gap-followup.md)，按[设计唯一入口](../game-design/README.md)读取14、04§4/6–7和M9。后端固定`feat/amount-safe-previews@ab6e887349cd4db1e0162471130686d2c2f30ca0`；M2/M5定向复查通过不扩大为M9或完整游戏验收，main仍暂停。

## 需求与版本

前端只取`design/g1-internal-organizations@a3e05ea05418841821e2acfec6899b900d8d0b90`的`docs/ui-redesign-plan/g1-internal/g2-hyperspace-restoration.md`“Godot接入与最小缺口”及`g2-forge-restoration.md`“Godot还原与接口边界”，对应仓库/挂设工位、编队及预设确认、拆解详情、连续材料兑换、改造Quote/参数区；浏览器有限响应不是运行实现。

| 版本 | 可复用与限制 |
|---|---|
| main `e93c221239a10d377b2ca89dd395ebcfa99c9819` | 已有warehouse/module_growth/module_contributions、prepare_hangings/loadout/preset/dismantle、preview_forge和Session原命令链；这些准备/查询不等于完整UI已接通。 |
| 当前 `ab6e8873` | 上述M9仓储/改造核心仍沿原实现；另有[14§10](../game-design/14-ui-contracts.md#10-实现候选超空间只读预览与星球自动设置)的路线最佳/单次自动预览、过滤导入只读候选，不重复新增。当前Hyperspace Git blob为`3337867789d4c8b5a9d2bcf48c43f92144f8699f`，main为`cd58e3c04b739318d45e67ac8964ba3a0c421c5b`；不能把整文件当main相同。 |
| 早期 `b7bb3de33287783721a8bbd9417f2ea040ad32ff` | forge_display_limits可作局部参考：affix_limit、max(品质hanging_limit, preserved_hanging_slots)、可重抽范围；尚未进入main/当前分支。它跳过锁定词缀、未给当前值/词缀索引/实际已购槽/完整操作准入，不能整批照搬。 |

## 现有公开事实：不新增重复字段/算法

- warehouse已深复制main/overflow实体、presets.entries及其hangings，并公开equipped/favorites/sealed、reforge_count/retention_capacity。实体已有hanging_slots（**实际已购槽数**）、preserved_hanging_slots、hangings、普通/究极词缀、形态、forge_revision等；实际槽数直接复用，不能以品质上限替代。
- 装备、收藏、封存、引用预设名的保护来源可按公开稳定id关联，不增保护账本。未知/被移除对象清旧详情；取消收藏不能绕过其他保护。主仓/溢出数量可由公开数组取长度，不再加一套计数状态。
- module_growth已有各挂设unlocked/level/exp，module_contributions已有**当前装备挂设的来源贡献**；后者不是每份贡献或最终收入/研究/容量，UI不能从名称/说明串算收益。player_catalog已有四类枚举目录（武器/品质/词缀/传说），不是挂设参数目录。
- 改造操作继续preview_hyperspace_forge/forge，局部随机候选不当已获得结果；过滤、路线与任务预览沿已交候选。本自然项不新增过滤影响扫描、任务推进或奖励生成器。

## 按实际消费者限定的最小增补

方法名仅说明职责，需双审定稿后才实现；Hyperspace拥有定义/成长/准备/改造，Session只装配真实进度、舰型、普通装备来源及Economy公开事实，不建每屏VM。

| 缺口 → 消费者 | 现有权威/最小读取方案 | 不能扩大的语义 |
|---|---|---|
| 实际容量 → 仓库主仓/溢出容量条、整理/满仓反馈 | 在warehouse加`main_capacity/overflow_capacity`，分别复用_warehouse_capacity与现行overflow_capacity；保留原retention_capacity | 主仓容量含现行重铸增长，不硬编码200/10，不把重铸保留容量当主仓容量。读取不organize、不腾位、不扫描或自动拆解仓库。 |
| 挂设成长/开放 → 当前所选机的挂设控制台 | 所有者对实际五个module id给当前unlocked/level、exp及下一等级required_exp的必要显示文本/有限比例，`per_copy_bonus`与当前aggregate contribution分别标注；给unlock_stage、当前轮次准入available/reason。复用_module_definitions/_modules及原_modules_after_credit中的所需经验求值、module_contributions中的每份贡献求值，可最小提取共用纯助手 | 不调用_credit_modules再回滚，不UI实现pow或升级循环；保持现行业务数值类型。所需/比例不可用时null+只读原因，不伪造0、不改业务上限。开放使用Session实际cycle_reached，与原prepare_hangings同源，不误用终身最高；门槛阻止安装不等于抹去当前已接受贡献。 |
| 挂设选择准入 → 当前机挂设草稿/应用 | 复用仓库hanging_slots/hangings与模块事实；若需应用前原因，由Session以真实进度薄包装prepare_hangings(id,ids)，只投影规范目标id数组及原ok/reason | 该检查使用实际已购槽而非hanging_limit。Unknown/封存、究极、重复/未解锁/阶段不足沿原顺序/原因；不擅加“只有主仓可改装”限制，原溢出区可按原准入改装。究极有槽不代表可修改。 |
| 改造槽数/限额/当前范围 → Forge对象参数与保护区 | 实际hanging_slots/形态/普通与额外词缀原值继续warehouse；只补所选对象的affix_limit、允许增长的hanging_limit及普通词缀/传说参数范围行。行以id+forge_revision+词缀index/key/tier或传说parameter定位，给current/min/max、locked/modifiable与原因；锁定项仍可显示范围但不冒充可修改 | 配置上限、保留上限、实际槽数独立；究极锁操作但不清掉已存槽/词缀。复用_quality_row/_affix_ranges/_legend_parameters和原preview_forge限制；额外究极词缀不挤占普通affix_limit。catalog只有ID不能代替参数范围；不输出整份私有配置。 |
| 改造报价可支付/必要配装预检 → Forge Quote/确认 | 继续现有Session.preview_hyperspace_forge；在原forecast上最小投影source id/forge_revision、原costs经原Amount转换的规范文本/显示金额、draws和Economy.can_pay结果。若已装备且候选会改变组合，复用原forge确认内prepare_loadout的replacements路径给具名预检结果；范围/费用/保护可展示，随机候选不渲染为已获得新属性 | 不复制定向/保底/现代化费用或抽样算法；不把forecast.ok当付款或最终配装成功。只对当前选择的操作/参数求值，不每显示帧穷举全部改造；确认仍由原forge重验并保持operation_id幂等与配装限制。 |
| 普通编队/预设应用前预检 → 当前多选编队与预设确认区 | Session薄包装当前prepare_loadout或prepare_preset，用真实船型drone_capacity、当前轮次进度和只读武器来源；只投影规范ids与预设entries和具名ok/reason/准入范围，不把武器贡献字典整本给UI。装卸ID及逐机挂设差异可由已公开当前序列/entries比较，无需第二比较算法 | 原整组拒绝、传说/究极/封存/引用/挂槽限制保持；不部分装备，不把UI多选顺序偷偷排序。当前prepare_loadout只覆盖它实际检查的范围，不承诺native所有组合检查；具体边界见下节。 |
| 拆解前结果 → 所选无人机拆解详情/确认 | prepare_dismantle已复用_protected与_dismantle_reward：只需具名只读薄投影id/原原因、确定移除对象、原材料量/核心返还及挂设副本确定份数，随机副本种类标待结算。份数从原准备结果/原局部计算投影，不由UI品质公式推算 | _dismantle_reward使用本机forge_rng_state初始化**局部**RandomNumberGenerator，不推进真实流；无需新抽样器。局部推演出的具体副本不当已入账物，不承诺未来成长/最终全局收益；确认走原Session拆解及世界贡献发布，实际reward优先。 |
| 材料兑换预览 → 输入“希望收到数量”的连续兑换区 | 从exchange_hyperspace_materials提取同一完整原准备计算供命令/只读共用：原Amount解析/正整数判定、倍付计算、Economy.can_pay/payment的候选扣源，再从paid.wallet取目标旧余额并执行Amount.add(old, received)，成功后才形成完整候选。只在脱离预算上求值，不接纳；必要时投影源/目标当前余额与支付/收到量，内部候选钱包不持久化或整本返回UI | amount仍是**收到目标量**，支付量沿现行2倍原计算，不按旧演示倒置单位。保留RunState→材料ID→Amount/正整数→倍付→支付候选（含扣源）→目标旧余额+received的Amount.add等原顺序和错误；0/小数/同材料/不足仍原拒绝，后续Amount错误也原样返回。can_pay=true仅表示可支付，不能当完整可兑换许可；只有包括目标加款的整段准备成功才可给完整准入。查询不accept_budget/通知，确认仍沿原完整准备重验并接纳，不另建换汇算法。 |

## 准备结果与“可提交”的边界

当前prepare_loadout检查容量、主仓未封存、引用唯一、传说/究极数量及它自身的Higgs无人机计数；Battle.validate_drones只核结构与容量。完整普通炮+无人机的native配装检查仍在原提交链。薄预检应标明`admission_scope=hyperspace_prepare`，保留原reason，不因prepare成功就给“所有限制已通过/保证可提交”。若消费者必须在确认前承诺完整native许可，需先定向核对并提取原共享纯验证入口；当前没有可直接用于该承诺的公开完整出口，不能调用Battle.prepare_player/_growth_setup/native提交再回滚来充当查询，也不自行重写Higgs规则。

原Session._hyperspace_weapon_source调用Equipment.drone_weapon_source，后者在候选阶段会优先读_pending_slots。新只读预检须复用同一最高付费级/成长计算、**明确选用已接纳普通槽来源**，最小提取接受槽数组的纯助手或已接纳读取路径；原命令准备的候选语义保持，不能顺手改成全部忽略pending。查询也不得写Equipment/Enhancement/Battle的_pending或污染已接纳缓存。Hyperspace的局部prepare不等于整条Session/native链已具备原子预览，本提案不新增全局事务或第二份配装账本。

## 读取纯度、确认和刷新

所有新读取仅投影已接纳事实与脱离候选；不reserve/accept/forge/credit/organize/advance，不推进奖励/幸运/本机随机流、forge_revision或序列，不发领域通知，不为读取新增RunState.fail。原prepare校验可复用，但只读上下文不能自报船型容量、角色级数/幸运或轮次进度。输入无效保留原reason，不将失败值包装成合法0或空仓。

source id/forge_revision仅绑定当前改造对象，不是全域revision：挂设变化、收藏/装备/封存/预设引用、模块成长、进度、预算或舰型均可能在forge_revision未变时影响结果。可见时沿现行读取，命令完成重读受影响仓储/实体/成长/预算；参数/来源改变清对应旧预览，对象消失清详情。确认走原命令最新重验，预览不保留对象或价格，实际回执与下一预览分开；不为这些消费者新增对象事件框架。局部随机候选只作为原准备的内部依据/待结算响应，不能当已获得物、已付费或已发布战斗状态。

## 审核后必要验证与剩余

若获准实施，定向验证才启动：容量随原重铸计数一致；已购槽/上限/究极锁区分；挂设成长所需/每份与聚合、锁定/阶段原因；预设逐机挂设与普通编队原整组准入；准备时pending普通槽不污染新读、accept/discard后更新；改造/拆解预览前后保存快照与三类随机流/修订号不变；兑换源/目标/正整数/不足及can_pay成功后候选扣源/目标Amount.add失败时的顺序、错误和预算不变均与原命令等价；预览后状态变化确认重验，原幂等/部分失败政策不变。未执行游戏测试，不宣称M9接线或完整V9通过。

保存宿主的结构化摘要透传仍是[原清单M10行](frontend-readonly-gap-followup.md)剩余，不混入本自然项。已交路线/过滤三项和M2/M5不重做；真实几何/参数、未定历史乘数/未来收益、保存事务及UI品质均排除。未批准前不实施上述新增。
