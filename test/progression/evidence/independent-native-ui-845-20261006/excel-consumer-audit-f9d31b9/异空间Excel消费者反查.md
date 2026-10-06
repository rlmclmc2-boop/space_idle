# 异空间Excel消费者反查

范围：冻结候选 `f9d31b92d2b80af1c4b663173f12e4f6a23b8841`，干净独立checkout。与先前40fcc51比较，scripts/tools/hyperspace JSON/工作簿无差异。本次只读代码与XLSX；未运行Godot、未改工作簿/数值、未运行导入或长测。正向BUG线程盘点尚未收到，下面按消费者给父任务对照，不能声称已完成双方交叉核验。

## 是否真的接入

当前 `config_excel/hyperspace_config.xlsx` 已包含JSON全部52个根字段，Python只读解析结果与 `data/hyperspace_config.json` 完全相等（原文件SHA见audit.json）。`tools/config_workbooks.py:218–280`在增量导入中独立生成JSON并参与原子批量提交；`hyperspace_config.gd:3`读取JSON，`hyperspace_system.gd:11`每个新实例加载一次；`config_panel.gd:209`导入只执行Python，不更新现有实例。需要重新加载场景（323/349）才进入新配置。现有 `test/test_hyperspace_workbook.py`证明的是导入事务测试设计，本次未执行。能改“被消费者读取的现有参数”，不是任意新增玩法字段都自动生效。

工作簿只有path/type/value三列，不含策划中文解释、单位、范围、变更影响、只读标记；当前导入器要求恰好三列且单sheet，不能直接添说明列/页而不调整导入契约。所有公式均拒绝，不能宣称支持Excel公式或缓存公式值。

## 从消费者反查的最小配置面

路径均相对space-battleship/scripts；行号为冻结版本。

| 系统 | 已实际读取的策划参数 | 消费者及边界 |
|---|---|---|
| 探索/能量/门票 | unlock_stage、minimum_level、energy_rate/cap、ticket、minimum_duration；60关补给门槛/能量倍率/材料倍率/爬升秒数 | hyperspace_system.eligible_level/start/online_config/ramp_config；hyperspace_scheduler.charge/ramp_gain。初始满由state.fresh:12直接取cap；自动需先充满cap才开下一次，票耗并不是开跑阈值 |
| 奖励/品质 | routes武器与专属材料；material_base_reward/start_level/level_step；quality_weights；core_reward | drone_rewards.material_amount/generate:8/48。权重归一相对抽取，当前权重总和1.09不是独立概率；ultimate_core时固定1个。普通资源/宝石预算由主线数据与独立space JSON绑定，不在本表 |
| 品质/装备 | quality_limits词条/挂设数、hull_capacities、maximum_equipped/legendary/ultimate、weapon_level_bonuses、ultimate_weapon_bonus | drone_rewards.create_drone:37；drone_inventory.affix_limit/hanging_limit/equipment_valid；drone_effect_aggregator.weapon_bonus:39。传说化保留挂设/蓝来源，双属性同时各占配额 |
| 词缀 | affixes的既有ID、weapon、各阶ranges、amplified；tier_weights；初始生成概率/追加衰减；value_precision、amplification_rate | drone_rewards.affix/count_slots；drone_forge.plan promote/reroll；drone_effect_aggregator.affix_value。新增词缀ID能抽到不等于能投影到战斗：聚合映射是既有key代码 |
| 改造/预兆/传说/究极 | forge_costs、lock_cost_multiplier、reroll_guarantee_multiplier、maximum_forecast_attempts；modernization_cost_base/level_step/legendary_multiplier/tier_weights；已支持策略枚举 | drone_forge.plan:49–150。现代化仅用相应武器路线、≤本轮highest的最高历史成绩，不能表改成指定任意目标。传说效果参数范围决定新抽取/重洗值，旧已存值不会自动重抽 |
| 挂设 | base_exp、exp_growth、effect_growth、unlock_stage | drone_rewards.credit_modules:86；drone_effect_aggregator.project:21–24。单架不重复、同类相加。game.gd:1007/1350/1566/1752/1784/2915及hyperspace_system:23按固定模块ID接入具体系统 |
| 传说战斗常量 | 精确制导stack_multiplier/limit_enabled/limit；奇异物质概率/延时/击杀生成数；激光蓄能每激光值；狂野导弹周期/爆炸比例；闪避冷却；统御品质比例；黑洞周期/吸收时长；重建层数；希格斯炮来源上限；棱镜邻近目标数 | drone_combat_effects各函数；game.guided_missile_damage:2406、fire_context约3328、棱镜约3461；system.equipment_constraints:200。效果ID/行为逻辑不是自由脚本配置 |
| 仓库/重铸/保留 | warehouse_capacity、reforge_capacity_gain、initial_retention_capacity、retention_capacity_gain；overflow_capacity=10固定 | drone_inventory.capacity/retention_capacity/has_space/reforge；hyperspace_system.reforge_state:247。封存领取阈值来自planet/unlock主线表，非本表；重铸fresh后只复制inventory、history、unlocked_drones，其他异空间资源重置 |
| 筛选/预设 | maximum_filter_conditions、maximum_filter_string_length；过滤器运行存档中的mode/action/conditions | hyperspace_filter.valid/import_string；system.set_filter/save_preset/apply_preset。五条件及且/或是用户规则，预设数量固定3，不在Excel；保存名长96也写死 |

## 最关键缺口，按优先级

1. **导入业务校验与启动入口未闭合。** `hyperspace_workbook.read_config`只验证类型树、version、四项时间能量、品质抽签与部分后期倍率。Godot `Config.valid`虽更全，但正常 `load_config`/System初始化直接读取，没有调用；只有显式configure调用它。`modernization_tier_weights`完整性、modernization_legendary_multiplier、ultimate_weapon_bonus、dismantle_amounts、每个传说constants更未完整检查。例如层数倍率漏键、阶权重缺一阶、黑洞period与absorption_duration同时为0均可能顺利导入但消费者出错或热循环。最小闭合：导入前全schema验证，启动同样fail-closed并给可定位字段错误；不改玩法值。验证需同时断言失败不改JSON及旧存档，而非仅看导入返回码。
2. **明确无效字段，避免“策划改了没效果”。** `amplification_start_level`全scripts无读取，聚合器:7固定 `level-4`；`maximum_command_id_length`无读取；policies.legendary_selection、sealed_unlock无读取；hanging_modules.*.effects无读取；precise_guidance.constants.counting_policy无读取；prism_tower.constants.maximum_towers无读取（game约3462固定只允许一个有效塔）。前者数值起点需决定接线或标成只读；其余效果映射/策略多是描述当前不变量，应在表明确锁定/文档字段，不自动扩展功能。单纯保留可编辑value会误导。
3. **配置调小或改ID可能让旧存档整个加载被拒。** game.load_progress_data:263先用新配置校验；模块数量/ID、路线材料、minimum_level、品质上限、仓库容量、舰型名额、legacy传说范围及late_supply_ramp_seconds都是存档兼容边界。例如缩短爬升时长，旧late_supply_work超过新上限即State.valid:55拒绝；仓库容量减少后Bag.valid:76拒绝。需要区分安全数值与需迁移字段；保留旧存值的stored_parameter_ranges不可当新生成范围随意收窄。最小验证是已有存档加载前后字段保留/错误明确，不清档兜底。
4. **敌人编队与普通奖励另有权威。** `hyperspace_route_loader.load_files/prepare`读space_enemy_routes/candidates两JSON并要求四路线40组、4普通4精英1Boss1地区Boss、enemy_tier_offset=0；encounter_database.configure继承所选战斗倍率及最新已清普通资源倍率；reward_binding.prepare再绑定普通掉落预算。现有hyperspace工作簿不能修改编队/敌人数值/普通奖励分配。是否纳入本轮Excel化由父明确，不能遗漏后声称“全部异空间配置已Excel化”，也不应混入主线monGroup。
5. **展示与结算重复公式需同源。** 自动船员时间100/(100+L)、票耗20/(20+L)在system:108–109、commands:160、panel:337重复。当前100/20是用户明确规则，保留不变量；若父未来要暴露参数，需先提公共计算函数，再同时接UI/结算，避免显示旧票耗。现代化成本的起点直接复用material_reward_start_level:135，调奖励起始等级会同时改造价；应给联动说明或确认是否拆独立成本起点，不能暗中改变当前结果。

## 不该误报为可调缺口

触发链深度1（combat_context.can_trigger/derive）；精确制导每发射batch每目标首次命中记一次；自动探索历史进度条无后台战斗；离线不推进（game:367）；失败退已付票；满仓保留completed_pending并阻止后续；记录跨重铸但受本轮highest约束；传说/究极配额与品质硬上限；只有究极可还原；升阶成功只升1阶；预兆最差未锁优先；已装备/收藏/预设/封存不可自动清除（Bag.protected）；奖励round/run幂等。这些属于既定行为/事务安全边界，不应随Excel编辑任意取消。

completion_budget=8、maximum_forecast_attempts、过滤字符串长度、版本号属于运行/安全约束，和策划平衡参数分组。自动full-cap开跑、核固定1个、预设固定3属于当前代码行为，父如需调整须先确认范围，不据写死擅改用户决策。

## 最小验证点（建议，不是已执行）

- 现有XLSX→JSON全量等值 + 无修改导入no-op；每个配置组挑一个既有参数，在临时副本改值→导入→全新实例读取→直接调用消费函数，断言实际结果和UI文案。无需跑进度。
- 奖励固定种子/边界：相对权重、材料整数档位、品质槽上限；词条生成与聚合分别验证，不能只断言JSON改了。
- modernize纯quote算成本/对应路线目标；挂设只装备两架同类相加、仓库不贡献；precision/amp起点验证一个10级机即可。
- 不合法每类字段一次：缺阶、未知效果ID/参数、零周期、越硬上限、重复路线武器；导入输出不变且启动明确报错。
- 原存档载入新配置：容量缩小、挂设ID变化、旧传说0.8–0.9兼容、爬升时长缩短，确认迁移/拒绝策略；不覆盖玩家存档。
- 重铸保留与满仓事务只做定向已有fixture，验证pending领取一次、保护引用不删、history不越本轮；不重跑60关。

本轮未见BUG线程正向盘点或新表格候选；父可直接对照以上五项，优先决定校验闭合、无效字段标记、外部编队是否纳入。未提出新增玩法或美术工作。
