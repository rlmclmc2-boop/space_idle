# 13 待决规则与证据边界

## 状态约定

U：本轮用户明确决定，已成为约束。R：从当前Excel/实际入口核对后的保留建议，完整写入本设计供整体审阅；不是声称历史实现自动有规格权。P：新架构实现建议，审阅后实施。D：冲突或缺乏授权，阻止该项行为实现；不得用旧代码/测试断言擅自补齐。

U清单：只设计后审阅；配置内容保留且Excel唯一权威；测试独立Excel、缺源失效；已废弃成长不恢复；纯表现复用；native/GPU快路径不退回未经效率证明的旧方式；保持命中扣血/死亡与表现；无旧存档连续性承诺；Git交付、不用Library、不合main、不另线程。

## 逐项待决账

| ID | 冲突/未定内容与当前证据 | 建议及需用户决定的选项 | 阻止阶段/覆盖 |
|---|---|---|---|
| D01 | 异空间资料保存原战场，用户允许进入清空；返回位置与HP/CD/临时防护/债务如何初始化未定 | 不保存原战场；选择重建该主线战斗点或已完成点后的航行，明确是否满状态；不能保留隐藏暂停现场 | 手动异空间/保存/重铸；H01,SV01,W06 |
| D02 | hyperspace_config有energy/ticket/minimum_level，实际prepare_start票耗0、下一层从1起；auto_quote亦0，旧资料仍写付费 | 确认当前免费逐层挑战/按最快记录后台为有效玩法，删除不再消费的票耗/充能配置；或明确恢复哪些规则。未定前不恢复收费、不删有争议表项 | H01/H02、C03 |
| D03 | scientistCost/hightechLimit/techPointGet/hightechCostGrowthLevel及hightech.tpCost*仍留在表/导入器，旧科研状态已空壳 | 删除旧科研成本/增长字段；保留hightech现用解锁；熔炉参数结合D10决定并拆到明确Excel；审批精确行/列清单 | C03/RES01 |
| D04 | equipment_evolution.json含业务进化倍率/材料费用，又无对应Excel；“已删除成长配置”未给全名；实际database仍引用 | 确认成长与材料部分是否废弃；若有效迁入Excel，若废弃删除业务；色板/纯表现不受连带删除 | EQ03/C04；不能擅自恢复 |
| D05 | 数值上限混有2^31/2^53/9e15技术限制；不能把所有计数自动定义成无界玩法 | 按09分类建议，确认等级/历史可支持范围；大数可用不等于必须允许无限实体/循环 | N01、native完整覆盖 |
| D06 | 资料说所有武器命中时结算，但现行玩家rail主命中在发射帧；这是旧武器自身时序而非被撤销的新提案 | 推荐保留该武器现行瞬时主命中及后续余辉，不把所有武器改延迟；用户如要求改rail时序需单独批准 | B02，保持总体命中规则 |
| D07 | 现行旧Lab统计HP-only、exact/fast不等于正式运动；重建工具必须同内核 | 推荐默认报告HP与shield分列及总和，并保留清楚标注的HP-only旧指标，旧结果只读不可混并新内核 | T02/T03，不影响游戏 |
| D08 | UI文案JSON编辑、工具分析JSON和纯表现manifest尚未Excel化；迁移格式新建 | 迁移有效配置不改值；判断纯静态资产编译元数据与可编辑配置的清单边界；预留参数不据名称激活玩法 | C04/UI01/T01 |
| D09 | 旧重铸/旧存档有迁移例外；新存档不继承；08列出建议保留/重置矩阵 | 确认科研/材料/粒子/熔炉峰值等整轮重置范围及后台奖励中断，不能凭历史残留字段裁决 | W06/SV01 |

| D10 | 熔炉文档描述随掉落基数生产，旧状态/收取/船员目标仍存在；共享在线推进未发现生产调用 | 明确熔炉仍需恢复为产品功能，还是废弃其入口/参数；保留纯外观不等于恢复经济。若保留，需批准完整产量/等级/周期/保存规则；06仅列已知资料范围 | ECO03/CREW01/C03，不能默默恢复 |
| D11 | 旧装备文档全部首轮完整CD；当前进入航行导弹min(cd,0.4)，其他完整CD | 推荐保留当前差异并将0.4入Excel；或明确统一完整CD | EQ01/B02初始化 |
| D12 | 敌盾实现有最小1吸收；native未统一先将incoming夹1，旧GDS有；完全抗性下仍最小1盾损失 | 推荐以当前native路径逐层公式为统一基准；确认极小伤害和r=1边界后写入独立Excel验收。不得夹带整条旧GDS回退 | B03/N01，边界数值一致性 |
| D13 | 10槽与15槽选敌共用abs(slot−4.5)，与15槽自然中心不同 | 推荐保持当前顺序并移入各阵型显式配置；若调整中心属于战斗规则改变 | B02目标排序 |
| D14 | interference/jewelExplosion仍在命中代码中，但现行六类强化未见相应业务入口 | 不从旧宝石文档恢复；确认其现行合法来源，若无则删除这些孤立业务字段/派生；其纯视觉按用户要求保留 | B08/C03，废弃范围 |

不再待决：发射扣血、显示血量分离、同刻互射新规则、是否保留Excel、是否恢复旧宝石/科学家，均已排除。

## 核对范围与局限

基准b4729b9a9803458b5ac19a4945c2fe0d5f76e51f，工作簿字节SHA/所有列/非空行索引在inventory。逐行盘点确认身份与覆盖，未运行Excel公式重算，也未启动游戏证明运行效果。正文的R规则取自Excel有效含义、当前正式函数与资料交叉核对；冲突列D，不以旧测试判正确。

重点源码证据（定位，不代替正文）：database.equip/ratio/enemy_weapon；game.fire/tick_projectiles/hit_enemy/jewel_hit_player；enhancement_branches/growth；ai_tech_tree；crew_system.auto_jewels；reactor_state；income_history/battle_rewards；drone_forge/rewards/inventory/effect_aggregator/combat_effects；hyperspace_system.prepare_start/complete/claim；planet_buildings/buffs；galaxy_region；native_execution_compiler/session；combat_execution_kernel/combat_presentation/combat_retained_presentation；tools/supported_entrypoints及各正式工具入口。

未执行任何现有或新测试、游戏、构建或性能探针。可交付完整设计与核对清单，不能声称已验证功能等价、性能提速或现有发布二进制与源码一致。D项不是遗漏，更不是默认授权；按表阻止依赖工作。
