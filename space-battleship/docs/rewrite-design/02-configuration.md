# 02 Excel 配置规格

## C01 权威、输入集合与生成结果

确认规则：有效配置内容保留；Excel 是唯一可编辑配置权威；JSON/运行资源只由 Excel 单向生成。旧总表、published 副本、历史 JSON、导入缓存不能补缺。代码拥有行为实现、类型和结构约束，不拥有另一份可调平衡数值。

当前逐表、逐列、逐行盘点见 inventory/workbooks.csv、fields.csv、rows.csv；这些是审阅证据而非配置源。small-config-content.json 抄录小表的字段说明、类型和实际单元格以支持审阅；不得在游戏、构建或测试中加载本目录数据。

正式源集合是 config_excel 下 26 个顶层 Excel（以清单实际列举为准），排除 level_monGroup_generated.xlsx 的候选生成身份。published/{mon,monGroup,level}.xlsx 是派生副本；根目录太空战舰.xlsx 是历史总表，不参与自动合并。若将候选关卡采纳为正式内容，编辑器必须明确写入正式 level/monGroup/mon Excel，再重新生成。不能让两份表争夺同一字段。

实现接口：`compile_config(source_set, destination) -> ConfigBuildResult`。source_set 明确列出全部必需工作簿和版本；先读取每份源的稳定字节，解析、全量校验、交叉引用、计算生成值，再写一个完整新包。结果包含配置 ID（源字节、schema 和编译器版本摘要）、源列表、错误坐标、输出路径；不返回“部分成功可继续”。输入在读取期间变化即拒绝并要求重试，不能混合两次读取。

运行 `load_config(package) -> Config | ConfigError` 仅载入一个完整不可变包；发布游戏不要求携带编辑 Excel。开发/构建不得因源缺失把上次生成包当作本次成功。运行期切配置只在显式重开会话边界，不在一半战斗或一半消费中热替换。

失败时保留旧有效包，错误注明文件、sheet、行、列、规则；UI 显示“导入失败，尚未应用”。构建失败不发布新版本。包可以采用单文件临时写入后原子替换；不重建跨进程配置发布服务、全仓 journal、运行期多代路由或每条业务操作的配置事务。

## C02 表与字段语义

逐列坐标、原描述、类型提示和公式缓存情况均在 fields.csv；以下定义每组字段的解释、消费方和约束，不能以名字猜语义。

| 表 | 字段解释及约束 | 消费契约 |
|---|---|---|
| ship | name 稳定 ID；des 显示名；para_1/2 武器/防御槽数；para_3 移动参数；para_5 尺寸；para_6 同装备限制。未命名空列不生成键 | 装备/表现；槽数是有界整数，尺寸为正；解锁来源为 unlock |
| equipment | name+level 唯一；一级是基础；dmgtype 为伤害/抗性类型；dmg/dmgMulti 伤害基值/成长增量；cd 秒；res_N/cost_N/costMulti_N 成组费用；para1..4 按武器类型解释，见05 | 装备投影→同一内核，禁止 UI 自算 |
| enemy_weapon_base | id 武器族；dmg/cd/dmgtype/para1..3 是敌方缺项的显式 Excel 回退源，不能借玩家行调参 | 编译时展开成完整敌方武器，不在热路径寻找默认值 |
| mon | id；des；equipment 有序武器；dmgMultiple；health；armourType；res 掉落；size；shield/shieldType/shieldRecovery/shieldDelay；reactiveReduction；archetype_id/intelTrait/intelName/intelVisualRef/intelMechanics | 数值字段给战斗，intel 字段给情报；描述文字不推导数值；空可选护盾规范化为 Excel 明确零值 |
| monGroup | id/des；mon 有序槽位列表，保留空位；combatTier 分类 | 10槽/15槽解释见04；ID合法不代表已加入主线 |
| level | id 连续；length 路程；monGroup 含战斗点/组顺序；atkRatio/lifeRatio/resRatio 终点倍率；entryAtkRatio/entryLifeRatio 可选正起点；jewelRatio/planetExpRatio 独立用途；rewardReferenceGroups 奖励参考关系 | 主线、战斗、异空间奖励引用；不能把 reached 当 cleared |
| res | id 资源身份、name 显示名 | 经济所有余额/成本按 ID，禁止用译名做键 |
| unlock | name 稳定解锁 ID；type/target；level/mode；title/desc | progression 是唯一阈值解释者；科学家旧解锁不自动生效 |
| enhance_config | id/value/unit/des；68条具体参数保留，成本、概率、间隔、门槛/位置偏移按05/04解释 | 强化/战斗；概率0..1，间隔正，门槛整数有序，派生次数有界 |
| ai_tech_tree | id/name/description/tier；base_seconds/growth；effect/factor；unlock/requirements/legacy_unlock | 研究；effect 是已注册枚举，requirements 固定级或10*k+1，禁止任意表达式 |
| crew | id/name/description/icon；basePower/defaultAssignment/unlockId/defaultTargetId；equipmentSlotCount 为预留字段 | 船员；预留字段不创建船员装备玩法；无旧等级字段 |
| crew_assignment | id/targetType/effectType；baseValue/levelScale/powerScale；interval/maxCrew；description/titleTextId/descTextId；targetCategory/upgradeModes | 显式注册岗位处理器；历史 effectType 名称按当前业务映射，不恢复旧机制 |
| crew_config | id/value/des/targetType，经验与效果参数及UI模板 | 06定义公式；文本不能控制公式 |
| planet | id/name/unlockId；baseTime/baseExp；tags/visual；reforgeStartLevel/minTime | 探索/呈现；具体公式08；最小时长与无底限异空间耗时不可混用 |
| planet_build | id/name/des；min_planet/planet_rule/planet_value；order/previous_id；unlock_explore/build_explore/extra_crew；type/config1/config2 | 适用范围、前置、建设趟数、激活后的效果，见08 |
| planet_buff | id/planet_id/source/source_id/condition；buff_type/target/value/stack/order/des | 永久贡献；add/max 等限定聚合，重复计算不得累积回基础值 |
| galaxy | id/key/name/order/unlock_type/unlock_value/next_galaxy；地图/起始尺寸；building_slot_count/slot_seed；探索/升级工作率、耗时/间隔/并发、special_cycle/core_asset/des | 蓝图+建设，数值与布局分开；全部字段列见账 |
| galaxy_build | id/key/galaxy_key/name/group/max_lv/effect_type/base_effect；asset_lv1..5/visual_category/des | 实际激活等级贡献；资产路径只呈现 |
| galaxy_config | key/value/type/des；逻辑结算、隐藏显示、相机、交通艇上限 | UI tick 不替代业务时钟；隐藏仍在线推进 |
| weapon_motion | id/value/unit/description/scope；逐项29个参数在内容账 | 玩家/敌方单位换算独立；rail_* 标注表现的参数不得偷偷改变伤害 |
| battle_design | id/group_id/tier/counter/base_level/min_upgrade/target_seconds/status/description；pair_id/attack_variant/attack_type/paired_group_id | 设计与生成工具；counter不是敌方攻击类型；实验目标不是强制战斗结果 |
| hyperspace_config | 15张子表：基础、路线、品质、舰型容量、阶级权重、词缀定义/区间、挂设成长、传说定义/参数/常量、费用、固定规则、外观 | 各键精确内容见账和07；editable=false为说明或协议，不是任意开关 |
| hyperspace_enemies | 敌人、武器安装、编队、槽位、路线编排、奖励参考、成员分配、早段回退预算 | 全链引用校验；显式位置不得误当F9评分图；早段预算是Excel正式数据，不是测试缺源回退 |
| hightech | name/描述/para1/para2 与旧tpCost*混合 | 先完成C03逐字段裁决；不能整表删除，也不能恢复科学家 |
| config | name/des/para_1 键值；初始装备、移动、拾取、撤退、离线、自动资源、反应炉、chrono、显示比例及换装冷却 | 键清单全部录入内容账；科学家/旧科研键进入C03，不能静默带入 |

所有 ID 引用必须存在且类型相符；所有范围含“未配置”和0的区别必须显式。费用资源成组，概率与权重不能互换；权重总和>0、最小值<=最大值、时间单位明确、前置图无环、路由指向已有组、预设/装备容量可表达。读公式仅接受工作簿已计算缓存并记录公式文本；缺缓存报告坐标，不读旧产物补值；不另造Excel计算器。

## C03 已废弃、候选废弃、仍有效

确认不恢复：旧jewel表；jewelCreat/jewelCombine/equipmentSocket/baseCriDmg；旧crew_level表及crew.baseLevel/maxLevel/expGroup/baseExp/expGrowth；旧charge表；科学家购买/分配、旧techPoints/hightechLevels状态及空壳API。当前crew_config、ai_tech_tree、enhance_config和有效装备成长继续保留。jewel_auto实际调用共享强化+1；hightech_scientists实际表示研究完成后续研，名字不能激活旧逻辑。

待决D03：config.scientistCost/hightechLimit/techPointGet/hightechCostGrowthLevel与hightech.tpCostBase/tpCostMutiple/tpCostMutiple2仍有历史校验/函数残留，不能据此认定为现行玩法。建议删这些旧科研参数；hightech.name关联解锁及熔炉有效参数保留，迁移到明确用途的Excel表。待用户裁决后执行精确删列/行，不在本次设计提交改Excel。

待决D04：equipment_evolution.json含20级进化、1.6/1.5倍率、材料费用及色板，目前不是Excel源。代码仍消费，不能确定是否属于用户所说已删除成长。业务成长/材料部分必须裁决保留迁入Excel或删除；纯色板表现保留。不能默默补回成长，更不能把色板一起删掉。

## C04 JSON独有配置迁移账

| 当前产物/内容 | 新唯一Excel归属（计划名称） | 迁移原则 |
|---|---|---|
| ui_text + contract 可编辑文案/参数/绑定 | ui_text.xlsx | 文案、键、所需参数/分类分别列；必需参数结构由代码校验；旧JSON编辑入口改写Excel |
| ship_weapon_visuals、模型/挂点配置、外观目录的可编辑manifest值 | presentation.xlsx | 保留实际值与来源资产路径；静态图片/模型不变；运行JSON生成 |
| equipment_evolution | equipment_evolution.xlsx（仅D04批准内容） | 表现与成长字段分组，不默认激活争议成长 |
| enemy_fleet_analysis、battle_result_analysis、auto_level_generation、level_generation_config | analysis.xlsx 对应子表 | 阈值/预算/默认输入全部迁入Excel；淘汰exact/fast双规则标识时保留原报告身份不可冒充新内核 |
| hyperspace各JSON、space_enemy_* | 现行hyperspace_config/enemies Excel | 逐JSON路径映射到列/生成公式；结构校验器是代码，不让schema JSON成为可编辑玩法源 |
| game_data、ai_tech_tree | 现行分表 | 只生成；不能深合并旧JSON里的缺席键 |

inventory/runtime-data.json列出全部19份当前运行JSON和键；正式实施须逐项迁入上述归属或标为纯生成结构，未完成者构建不宣告配置迁移完成。新增Excel文件名是设计，不是本轮已创建事实。

验收：A-CFG；覆盖C01..C04。数据源失效和合法Excel默认行是不同情况：前者拒绝，后者按显式字段继承生成。
