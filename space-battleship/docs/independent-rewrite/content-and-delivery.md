# 内容、存档与交付

## 1. Excel 只有一套权威

选择 `config_excel/` 为可编辑源目录，不再把根 `太空战舰.xlsx`、拆分工作簿、published 副本、JSON 模板同时当权威。根总表如需给人浏览，可以从这套工作簿导出，但无导回覆盖入口；实现结束删除正式项目的旧总表输入通道。多文件 Excel 仍是一套权威，并不要求把所有玩法挤到一个工作簿。

每张表保留稳定 ID、字段、中文说明、类型/单位，前三行约定可继续使用。删除的是旧发布/兼容结构，不是有效行。正式源不可缺；没有文件时不得从旧 JSON、Python 默认值、已缓存 Excel 或历史基线恢复。编译错误指出 `文件/工作表/行/列/原因`，而不是运行时变成“按钮无法点击”。

`compile_content.py --source config_excel --out build_content` 是唯一开发/发布入口：完整读入声明的源→按类型和外键检查→按确定规则生成一次不可变目录→写 manifest→成功后替换产物目录。不做游戏进程内热发布、增量混合来源、临时覆盖测试正式表。26 个现存工作簿的体量足够先采用全编译；若将来测出编译慢，再在此入口内部缓存，缓存永远不改变缺源失败语义。

运行时只加载已编译 `Catalog`：启动检查文件完整性、schema/native ABI，构建索引一次；不逐帧验证整张表，不每次 hit 检查类型。发布包无需分发 Excel、Python 或编辑器，这不意味着源可以缺：开发启动、测试编译、发布构建都先要求对应权威源；成品游戏只要求合法已编译包，不要求玩家安装 Excel。

## 2. 现有工作簿的目标去向

| 现有源 | 目标处理、消费者 |
|---|---|
| equipment.xlsx | 保留 level=1 的有效装备基础、费用、成长和武器参数；删除废弃高等级历史行的运行依赖；Equipment/Stats/native |
| enemy_weapon_base.xlsx | 保留敌方基础参数；敌人缺字段的继承在编译时完成，不让运行时回落玩家武器 |
| weapon_motion.xlsx | 保留弹道参数并补足缺失常量；同一份供 native 和纯表现引用，不在 presented_game 初始化时再改值 |
| ship.xlsx | 保留舰型、槽数、容量/装备限制、关联资源；Equipment/FleetGeometry |
| mon.xlsx / monGroup.xlsx / level.xlsx | 保留有效敌人、装备挂点、奖励、显式编队、主线遭遇和入口倍率。旧“自动生成”行若被有效关卡引用也保留；不因删除编辑器删关卡 |
| level_monGroup_generated.xlsx | 保留工作簿及公式，编译时与 level 按显式来源标识合成唯一遭遇表；重叠引用按当前正式使用的来源选取，不自动覆盖人工关卡、不让运行时读两个来源 |
| battle_design.xlsx | 保留正式规则/显示布局所消费的条目；纯关卡编辑/实验分析配置不进入运行包。字段用具体消费者分类，不能整表当废品 |
| res.xlsx | 保留资源定义和显示资料；扩展资源/材料 ID，使 Wallet 不靠散落字符串约定 |
| config.xlsx | 有效行按 economy/journey/reactor 等有类型 sheet 拆出；不再解析逗号文本万能配置。删科学家和旧科技点等无有效消费者的行 |
| enhance_config.xlsx | 所有当前共享强化和分支数值原样保留；编译为六组 typed 参数 |
| ai_tech_tree.xlsx | 保留 8 节点、前置、倍率和当前门槛；去 legacy_unlock 翻译，把门槛一次性转为新 unlock_id |
| hightech.xlsx | 仅迁走仍在使用的门槛/文案关联；不恢复旧科研等级、科学家或炉成长。迁完不留旧 hightech 运行表 |
| unlock.xlsx | 所有有效关卡/功能门槛、教程文案和顺序保留；清理明确退休的通知，不把 old key 当新功能 |
| crew.xlsx / crew_assignment.xlsx / crew_config.xlsx | 保留当前成员、岗位及系统等级效果/经验；弃用已由导入器丢弃的旧成长字段 |
| planet.xlsx / planet_build.xlsx / planet_buff.xlsx | 保留全部现行探索、建筑、征服和美术描述；以稳定 ID 联结 |
| galaxy.xlsx / galaxy_build.xlsx / galaxy_config.xlsx | 保留节点/工作/加成/建筑资源/布局/表现预算；可见性参数只影响渲染，不左右经济 |
| hyperspace_config.xlsx | 保留有效路线、品质、词缀、挂设、传说、费用和外观。删除“兼容说明”里的旧档许可范围及无消费者占位，不恢复 ticket 付费 |
| hyperspace_enemies.xlsx | 保留敌人、武器安装、编队/槽、路线编排、奖励参考、成员分配、早段预算；补齐下述冻结 JSON 中仍有效的来源数据 |
| config_excel/published/*.xlsx | 删除副本，不作为运行/测试回退。运行读取编译包，构建只读原始源 |

上述目标整理首先发生在编译后的 typed 数据中；现有含公式的工作表保留坐标和引用，不为了统一文件名就搬走公式区域。新增硬编码/JSON 内容落到新 sheet；确需移动既有单元格时连同引用调整，并由工作簿计算保存缓存，不能用字面值替换公式来省事。

“有效”标准是正式玩法可达或被正式奖励/配置引用，不是旧导入器恰好读过。迁移时输出一张简短 `content-migration.csv`（源表/ID→目标表/ID/保留或退休原因），只用于一次内容审阅，不新建长期审核系统。没有被当前消费者使用、但确为未来作者已写好内容的行可留源中 `enabled=false`；不擅自启用。

## 3. JSON 和硬编码迁表：可直接执行的清单

### 现有 JSON

| 来源 | 目标权威/产物处理 |
|---|---|
| game_data.json | 编译产物，不再保留 previous projection、fallbacks、机器绝对 source_files |
| ai_tech_tree.json | 从 ai_tech_tree.xlsx 编译，不保留独立补丁入口 |
| equipment_evolution.json | 新 `equipment_growth.xlsx/evolution`：仅迁经下述调用链核实的 interval、first/later multiplier、material_id、material_cost_per_tier、palette/strength |
| hyperspace_config.json / hyperspace_visuals.json | 从对应现有工作簿 sheets 生成 |
| hyperspace_entity_schema.json 的 templates/frozen_inputs/sources_origin | schema 中只留程序结构规则；实体、顺序、奖励引用、形状模板中实际内容迁 Excel。删除固定历史 hash 作为玩法许可条件 |
| space_enemy_reward_sources.json / reward_early_frozen.json | 将仍有效的 1960 来源关联、95 早段回退条目转为 Excel `reward_sources`、`early_reward_rows`，使用显式稳定主键/外键，不再把 JSON 当隐藏源 |
| space_enemy_reward_catalog.json / recipes.json | 从主线奖励 + reward_sources + early_reward_rows + 成员分配确定生成；分配保留每成员资源块序号，不能把总奖励平均分摊冒充原奖励 |
| space_enemy_candidates.json / space_enemy_routes.json | 从 hyperspace_enemies 的敌人/编队/路线/引用编译；不再从旧 JSON 模板追加缺行 |
| ship_weapon_visuals.json | 新 `visuals.xlsx/ship_mounts,weapon_profiles`；武器安装、美术资源 ID、变换和特效设置迁入；纯网格/贴图数据仍是资源文件 |
| ui_text.json / ui_text_contract.json | 新 `ui_text.xlsx` 存 key/text/params/context/enabled；一次迁移有效 UI 文案，参数列与文本占位符一致；生成字典，不让 JSON 编辑器反向改文本 |
| auto_level_generation / level_generation_config / enemy_fleet_analysis / battle_result_analysis JSON | 按用途拆分：有效模拟/分析/生成参数迁 analysis.xlsx，只给开发工具消费；编辑器专用参数退休。已生成的正式内容归 level/mon/monGroup，普通游戏无需先启动生成器 |

早段回退是现有**有效奖励内容**，迁表后仍可作为显式奖励来源；这里禁止的是“源丢了才用旧缓存回退”。两者不能混为一谈。奖励映射缺引用时编译失败，不能猜一个同名敌人或把冻结哈希删掉后任意重算掉落。

### 两项内容有效性的核实

本轮只读检查了 xlsx 内 XML，未运行 Excel 重算或测试：根总表含 2,565 个公式缓存，`level.xlsx` 含 630 个公式且均有缓存，`level_monGroup_generated.xlsx` 含 203 个公式且均有缓存。可见不是“以后可能有人用公式”，而是当前有效内容已经依赖它；上述数量只作为本次取证，不变成固定校验门槛。

`equipment_evolution` 的保留依据是指定基线的正式消费链，而非文件存在：`database.gd:equipment_combat_growth→evolution_factor` 计算付费级进化倍率，`attribute_projection.gd:equipment_stat` 明确剔除虚拟等级赠送的进化；`database.gd:equipment_cost` 与 `equipment_state.gd:prepare_upgrades` 消费进化材料费用；`main.gd:refresh_evolution_visuals` 消费色阶。由新档正常升级可达，不是未调用的历史 JSON。故只迁这三类仍消费的内容：进化倍率/间隔、材料费、纯表现色阶。业务算法全部重写为统一近似大数；不恢复已经退休的高等级行上限、旧宝石成长或科学家成长。本判断仅对应指定基线的实际生效内容，不赋予其他历史成长有效性。

### 需要配置的代码常量

| 当前定位 | 新表与字段（初值来自基线） |
|---|---|
| import_workbook.DEFAULTS / game CLEAR_ADVANCE_DELAY/MAX_TRAVEL_SECONDS/RETURN_DEPARTURE_SECONDS | journey_rules：旅行/清关/返回/撤退时长；economy_rules：起始资源、自动拾取/生产块；不重复保留 Python 默认 |
| game REACTIVE_* | damage_rules/reactive：stack_limit=3、reduction=0.2、reset=2.2、volley_gap=0.16 |
| ai_tech_tree 的 AUTO_INPUT_SECONDS/MIN_INPUT_RATIO、公式 9/10/4/5 和线性前置系数 | research_rules：工厂刷新、投入下限、AI 效率基准/尺度、投入对数除数、峰值对数除数；prerequisites 表存 a/b |
| presented_battle_game 的未迁弹道字段与常量 fallback | weapon_motion：补齐实际使用项，已有列不造第二份；导入缺失报错，不能恢复老导弹数量/冷却/伤害补丁 |
| game 的起始阵形/敌列/船位、project.godot 中可调战场尺度 | visuals.xlsx/battle_layout；保留已存在 battle_design 与显式编队字段，明确同项只归一个 sheet |
| 装备进化色阶、武器缩放/挂点、炮口参数 | visuals.xlsx 与 equipment_growth.xlsx；模型/纹理本身和美术生成脚本不迁为表数据 |
| 固定宝石/核心拾取等待、最低伤害/舍入口径的可调项 | economy_rules、damage_rules；算法枚举如 shield_first 留代码，算法选择不是任意字符串脚本 |

不迁表：数组容量策略、内存布局、ABI 版本、1/60 执行步长、线程安全规则、UI margin 等普通程序/布局常量。可配置“数值”与算法本身分开；不把每个 if 都包装成策划开关。纯视觉现有高效参数保留，不以清理为由替换资源或 shader。

## 4. 编译格式与内容增量示例

目标包可以按领域分 JSON（core、campaign、hyperspace、visuals、texts）并用一个 manifest 绑定；不需要为本项目开发数据库或二进制编辑器。ID 索引在加载时转成数组/整数索引，native 描述一次性构建。

manifest 只有 `schema_version, native_abi, input_files[{relative_path,sha256}], outputs[{path,sha256}]`。hash 用于判断本次包一致性，不用于永久锁住基线内容。保留现有 Excel 公式及随工作簿保存的计算结果。编译器读取工作簿缓存的有效值，不执行 Python 版 Excel、不把公式改写为字面量，也不从旧 JSON 替补结果。公式缺可用缓存时指出单元格，请用 Excel 等兼容计算程序重算保存；本方案不默认更换作者的公式工作流。公式编辑后的重算保存与现有 Excel 使用方式一致，不另建公式审核框架。

新增一类敌人：mon 加行，明确 armour/shield/weapon/reward IDs；monGroup 加成员与位置；level 或 hyperspace 路线加引用。一次编译后 native 可以生成，不修改编辑器或 Game。新增一种现有效果词缀：只新增对应枚举和范围行即可。新增“击中后弹射”类从未有的机制：给 native 加一个直接效果函数、枚举/typed 参数和共同命中入口，再加一个功能用例；不引入嵌套规则 AST。

需要的检查只有类型/必填、唯一 ID、引用、概率/周期/数值范围、前置关系无环、有效 effect 枚举与资源存在。检查逻辑集中编译器；运行时不重复 Excel 结构审计。未实现的正式效果不能被编译“静默跳过”。

## 5. 新存档

新目录和新格式，例如 `user://rewrite/profile.json`、`format=1`；无需识别 v11 或旧材料版本。不自动读取/覆盖旧路径。新界面只导入本格式，旧档选择后明确提示格式不支持，不尝试半迁移。

```text
format, catalog_schema, saved_at
progress, wallet, equipment, enhancement, research, reactor
crew(assignments), planets, galaxy(nodes,seed)
hyperspace(history,job,pending_rewards,supply), drones
income_window, pending_pickups(仅 S1 获批), journey_checkpoint, time_credit
native_persistent(counters,rng), preferences
```

不保存静态数据库、派生 Stats、UI 节点、表现事件、全部 GPU 缓冲、旧命令 receipts、冻结 proposal、领域恢复游标。沿用基线的小型 Journey 检查点：普通战斗重新生成当前遭遇，手动挑战中断后返回；不为退出恢复新增全弹体 checkpoint。待拾取物是否纳入小检查点单列为 README 的 S1 建议，不作为已批准规则。

保存：逻辑边界收集一次数据→写同目录 temp→flush/关闭→替换主文件，保留上一份有效备份。自动保存 dirty 时才写；不在每个命中写盘。保存错误提示并继续当前会话，不能把失败的新文件当成功。保留显式保存和已设定时保存；不新增退出时自动保存或因保存失败拦截退出。退出回到最后成功保存的进度，这项既有行为不在重写中暗改。

读取：解析/版本/ID/值域/跨引用检查一次→构造 Profile→派生 Stats→创建 native→恢复 Journey→原子替换当前会话。没有存档就新档，已有但损坏不当新档覆盖；提供恢复备份或用户主动新建。导入/重置会话沿用同一入口，导入成功前不销毁当前档。

SaveStore 在当前进程中串行写入，不为此增加多进程只读模式或跨进程事务框架。wall saved_at 与粒子入账一起形成新的保存快照；重载同一旧备份只能回到该备份，不引入在线账号防作弊系统。

## 6. UI 与正常入口

App 构建壳、导航和当前页；BattleView 常驻，其余大页面第一次打开时创建、关闭时停刷新。每个页面只读自己的一份摘要，变化时更新控件，不为一次铁收入 build_ui 重建全树。资源条、科技进度等允许低频刷新；战斗显示每帧走原批量路径。

保留：开始/继续/选关、驻守与死亡策略、暂停与加速、装备/舰体/反应炉、强化及分支、科技树/投入、船员派遣、星球建造/征服、银河、异空间路线/无人机/改造/筛选、敌人信息、设置/存档传输、解锁教程、必要伤害统计。具体文案迁表；余额不足、未解锁、槽满等在命令返回后就近显示原因，不弹堆栈。

把主场景的继承链换成组合：`BattleView`、`Navigation`、`CurrentPage`、`Dialogs`、`ResourceStrip`。弹窗不再持整个 Game 可写引用。保存/读档页面调用 App/SaveStore；打开弹窗是否暂停使用一种显式策略，不能依赖对话框是否抓到键盘焦点。

普通启动只依赖打包 native、内容和资源；开发启动脚本先调用内容编译，再启动 Godot。native 缺失/ABI 错误直接说明安装包不完整，不悄悄退回另一套战斗。

## 7. 按用途处理工具，删除规则不扩大

用户要求删除的是“脱离游戏不能运行的编辑器”，不是凡引用 gameplay 的工具。编辑器用于修改/发布正式内容；模拟器用于运行实验；分析器读取实验结果；批次器组织多次实验。这四种用途分别处理，不以文件名前缀一刀切。

| 用途/基线定位 | 新方案处理 |
|---|---|
| level_editor.tscn、level_editor.gd、游戏内 config_panel、对应写回/发布入口 | 属于依赖游戏的内容编辑器，删除。不要给它们适配 Session，也不为其实现新 editor API |
| F8 关联 balance_panel/runner/scan/report | 保留模拟、策略比较、参数扫描、时间线和报告用途；业务 runner 重写，用新的 Session + 同一 native 无画面运行。实验数据使用副本，不写玩家进度或正式 Excel |
| F9 关联 enemy_fleet_panel、生成/预览/关卡候选功能 | 保留编队生成、参数筛选、预览、候选输出用途；删除其中直接编辑/发布正式表且必须依附游戏的控件。候选输出为独立 Excel 草稿，只有作者纳入权威表才进入正式内容 |
| fleet_battle_runner/sampling/batch_retest、fleet_result_analyzer 的批量对战/抽样/复测/统计用途 | 不在本次删除授权内，保留这些能力并按新 API 重写。未挂载的旧页面不冒充当前可用功能，也不为恢复历史页面结构投入开发 |
| tools/result_analyzer 独立结果查看 | 保留读结果/筛选/排序/导出用途；当前 entry 还引用 F9 混合窗口且提示旧分析页不可用，新查看入口只读结果文件，不加载游戏或重做编辑器 |
| 独立 Excel/文案工具、Blender/纯资源生成 | 能脱离游戏运行的可用部分原样保留。独立编辑器不适配新模型或输出格式，不承诺把 JSON 输出改成 Excel；原有 JSON 输出不接入正式内容权威链，正式内容仍由作者维护 Excel。纯资源生成的现有可用能力保留 |

具体新实现只有 `tools/simulation_runner.gd`（请求→一组隔离实验→结果文件）和 `tools/result_viewer.gd`（只读结果 UI）；在开发菜单保留“平衡模拟”“舰队实验/批次”“结果分析”入口。批次请求含配置包、实验 overrides、seed、时长、次数、阵容范围、采样间隔；结果含这些输入和胜负/耗时/收益/伤害摘要。只跑一个或有限数量隔离实例，批次逐项推进，不创建另一套战斗规则。快速运行是关闭显示、连续执行同一 native 逻辑，不恢复旧 fast 估算结算。实验 overrides 不成为第二正式配置源。

按实际用途切割旧混合文件后，旧 Game/旧业务实现可以删除；保留的是功能，不是把旧 balance_game 和多套投影继续挂在新架构上。F8 在 battlefield 中还绑定了动效开关，不能把冲突直接解释成“分析不需要了”；新调试菜单提供无歧义入口，动效开关移到显示设置是 S4 建议；未批准则保留工具入口并另配无冲突动效键。快捷键整理列入 README 可见变化表。

旧 config_snapshot/config_publication 的运行中编辑发布通道删除，单编译器保留内容构建职责。模拟分析参数中的有效阈值、标签、生成规则迁 `analysis.xlsx`；仅编辑器控件布局/旧兼容字段退休。普通玩家包仍不依赖这些开发工具。

## 8. 测试按新业务重写

本次不运行测试。下列是设计审阅后实施时的验证方案，不是本次通过记录。

测试以新公开命令和 native 结果为对象；旧脚本数量不构成新覆盖要求。不保留验证旧字段/旧继承/移交/编辑器的测试。本稿不指定默认复用的旧测试代码；先依据新规则重新写测试。历史用例只能提供场景线索，不能变成要求新设计保留旧结构的约束。

唯一测试内容源是 `tests/fixtures/excel/`：独立的一组小型工作簿，不拷正式全表，不运行时从正式表补缺项。初始夹具包含三关/普通与最终遭遇、四武器、盾甲两类、两舰型、两个船员、两个星球、一小银河、四异空间路线、所有受支持强化/传说的微型参数行。测试源的必要资源可共享正式纯美术，但其玩法表和预期结果独立。

每次测试入口从独立 Excel 编译到临时目录，创建 `Catalog(temp)`。缺一份声明的测试 Excel 时整个相关测试无效并报失败，不标绿、不 skip、不用上次生成的 JSON。正式 Excel 缺失时发布构建同样失败；不要求每个无配置的 Amount 单元测试硬依赖 Excel。

| 测试组（少量集中文件） | 必要断言；不搞庞大组合检测框架 |
|---|---|
| content | 独立 Excel 可编译；删源失败；错误引用给出单元格；变值确实改变结果；来源 JSON 不能单独兜底 |
| amount_and_growth | 普通/大数运算、盾破溢出、经审阅确定的普通舍入规则及近似累计费用公式、MAX 多币限制、极大值有限精度和数量级；不要求逐级精确复刻或材料精确往返 |
| combat | 有飞行时间的弹体命中前不扣血；玩家炮/希格斯发射同刻瞬时命中且只扣一次；光束蓄力与跳伤；导弹批次/重选；盾恢复/抗性/最后一击仅一个奖励。按表驱动小用例覆盖六效果 A/B 和 12 传说，再挑连发×暴击×连锁、黑洞×延迟、重建×防御三组交互 |
| commands_and_progress | 连点不超支、在飞升级保持快照、换舰/换槽、工厂资源耗尽、派遣唯一、建筑启用门槛、银河隐藏仍进度 |
| journeys_and_rewards | 普通推进/驻守/撤退、手动挑战返回、挂机满仓固定奖励、一次领取、改造 RNG 预览不消费、重铸重置表 |
| save | 新档往返、小检查点续程、损坏不覆盖、失败写入保留前档、导入失败当前会话不动、待领不重发；若批准 S1 再覆盖保存拾取物 |
| simulation_tools | 同一小表/seed 下无画面实验与会话结果一致；小批次结果可读取、筛选和复测，不借用旧业务测试 |
| view_smoke（少量人工/截图） | 各武器炮口→中心命中对齐，护盾/尾迹/光束保持表现；关闭显示后相同模拟输入结果一致；主要 UI 流程可用 |

不用旧程序作为所有测试的金标准。新测试期待值来自小表和本设计的公式，例如护盾 10、原伤 30、盾抗 50% 的穿盾余伤可手算；这能发现新旧共同的错误。少量旧测试如确可独立验证保留的纯表现/native 路径，可在实现时具体选择并说明价值；这不是默认代码复用方案，业务测试和旧大数精确记账断言不沿用。

性能只需三种代表场景：原 native 已支持的普通战斗、丰富编队含全部机制、极高增长数值；记录固定机器/分辨率/倍率下的帧时间、native 时间、分配量和活动对象数。与 b4729b9 的对应 native 路径比较时使用等价夹具，不混机器分数。重点确认没有全弹体跨语言复制、没有 GPU 回退、关闭 UI 不改变模拟速度。不在本次捏造测量值或设置未经测量的“提升 80%”目标。

## 9. 实施顺序与每步可交付物

审阅通过后由 sol medium 在新分支实施。工作拆成可用的纵向段，每步交付代码和最少必要测试；不合并一个只有抽象壳而玩法全空的“架构基础”。

1. **权威内容与数值**：保留公式缓存读取的编译器、测试 Excel、Catalog、统一近似 Amount/批量费用及按 S5 审阅结果确定的普通成长/单次舍入；迁有效数据和隐藏 JSON 来源，先给迁移 CSV 审阅。交付可从独立小表生成新档和明确费用/属性，缺源失败。正式工作簿内容不为适配新代码偷偷删效果。
2. **主线可玩闭环**：App/Session/Journey/Wallet、现有 native 运动与基本四武器、盾甲/奖励、现有高效显示接线、装备升级、新档保存。可从新档进关、命中、获资源、升级、清关、撤退和继续。仅在开发分支使用新入口，正式发布不在两套结算间切换。
3. **战斗规则完整**：Amount 接入全部生命/伤害，六强化全部分支、12 传说、机内重建/黑洞、完整换装；移除 native scope/白名单。完成这一段才允许宣称 native 覆盖正式玩法。
4. **成长闭环**：科技/投入/工厂、反应炉、船员、星球建造/征服、银河和收益来源；每个完成功能立即接 UI/保存，验证它会实际影响 native。
5. **异空间闭环**：同 native 手动挑战、返回、后台任务、奖励来源、全部无人机管理/改造/封存；按重置表完成重铸。保留主线与挑战共用的效果路径，不写第二战斗算法。
6. **工具用途与切换**：重写模拟/分析/批次的必要入口并接相同 native；删除游戏依赖型编辑器及其专用代码，独立编辑器仅原样保留可用部分，不做适配。把新入口设为正式，删旧业务/兼容/旧业务测试；纯表现迁正式资源路径；清理打包引用；做一次普通完整流程与代表性能比较。确认普通发布包不含游戏依赖型编辑器/测试 Excel，缺 native 不回退。到此才将实现送主线程验收，仍由用户/父线程决定合 main。

原项目文件可在基线提交查询；实现阶段不用把整个 old/ 项目长期留在包里。上述步骤是依赖顺序，不是允许半成品代替用户要求的完整游戏。

## 10. 代码定位与本稿证据

以下均是已读基线源码/工作簿，不是历史设计资料：

| 结论 | 基线定位 |
|---|---|
| 正式入口/显示派生 | main.tscn；battlefield.gd；presented_battle_game.gd |
| 两种 native scope、白名单/移交 | native_execution_compiler.gd:compile；native_execution_session.gd:admit/advance/handoff_to_legacy |
| 紧凑飞行物/typed presentation | addons/native_battle/src/combat_execution_kernel.h 的 Flight/Attack/Actor；combat_presentation.h；battle_slice_runtime.gd:snapshot |
| 可重试阶段与整体复制 | game.gd:consume_external_time/resume_step_context/install_prepared_game；progress_runtime.gd:reforge_planet |
| 基线费用/属性/材料（新稿统一近似） | database.gd:equipment_growth/equipment_cost；attribute_projection.gd；reactor_state.gd；economy_state.gd |
| 正式强化/传说 | enhance_config.xlsx；hyperspace_config.xlsx；enhancement_branches.gd；drone_combat_effects.gd |
| 无科学家的新研究、两个收入时钟 | ai_tech_tree.gd；income_history.gd；game.gd:commit_income_receipt |
| 星球/银河/派遣 | planet_state.gd；planet_buildings.gd；galaxy_region.gd；crew_system.gd |
| 奖励与重铸实际状态 | hyperspace_system.gd:prepare_start/prepare_complete/prepare_reforge；hyperspace_runtime.gd；drone_inventory.gd:reforge |
| 冻结来源 JSON 依赖、Excel 全集 | tools/hyperspace_entities.py；configuration_manifest.json；config_excel 各工作簿 |
| Excel 之外的默认/文案/发布通路 | tools/import_workbook.py:DEFAULTS；tools/ui_text.py；tools/config_publication.py |

本稿没有运行或修改这些代码，也没有运行游戏/测试。实施风险主要是 native 规则补齐和纯表现接线，不是 Git/环境访问障碍；它们已经对应到具体工作与验收，不能以“后续再研究”跳过。
