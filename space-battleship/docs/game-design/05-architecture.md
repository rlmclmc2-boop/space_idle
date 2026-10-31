# 05 游戏对象与直接执行流程

[回唯一入口](README.md)。游戏在主线程中顺序执行。`GameSession`保存玩家进度并调用具名系统函数；Battle持有`SpaceCombatKernel`，由内核保存和推进实时战斗；页面通过Battle读取完成后的状态并绘制。下文为目标实现，标为“现有”的名称指出可接续的源码，其余函数是本方案定义的新接口。

> 配置运行结构与保存身份存在待核实冲突，见 [D9](review/conflicts.md#d9-配置身份与运行配置结构本次发现待核实)。本项暂停裁定与争议条款删改；正文暂留。D9已分开查询包装、文件完整性与配置兼容策略，并补原消息及后续重新引入事实；不能把早期去保存绑定扩大为删除所有配置校验。其他规则继续按原范围使用。

## 1. 实际需要的对象

| 对象 | 职责与存在原因 |
|---|---|
| GameSession | 一局游戏的入口，拥有下面的进度数据与时间余量，并持有Battle模块；按固定顺序调用各系统，避免各页面自行推进时间 |
| ConfigBundle | 一次编译的只读Excel数据、索引、来源坐标；游戏和测试都直接查询它 |
| 具名系统函数 | equipment/research/crew/planet/galaxy/hyperspace/economy各文件保存本系统公式和动作；直接接收session或所需数据，没有各自隐藏的玩家进度 |
| SpaceCombatKernel | 现有C++核改造后的唯一战斗实现，管理双方防御、攻击出生、运动、接触、传说和波次；让大批弹体继续使用现有紧凑存储与快路径 |
| combat_setup.gd | 把槽位与成长结果组装为native配置，计算逻辑舰体与炮口输入；只在实际变更时更新，不逐帧重编译装备 |
| Battle与SpaceCombatPresentation及Godot页面 | Battle持有native核和原生表现器，提供出击、撤退、结波与展示所需的具名接口；页面提交画布、材质与绘制回调，GPU绘制弹体/接触并显示文本，不结算命中或直接访问内核 |
| SaveFiles | 串行写保存文件、备份和导入校验；文件写入需要独立生命周期，业务动作不等待磁盘 |

建议文件位置为`src/game_session.gd`、`src/state/`下的具名进度结构、`src/systems/{battle,campaign,economy,equipment,enhancement,reactor,research,crew,planet,galaxy,hyperspace}.gd`、`src/combat_setup.gd`、`src/save_files.gd`和`src/ui/`页面。C++继续在`addons/native_battle/src/`；`config_tools/`是独立Excel编译命令，`tests/excel/`与`tests/run_cases.gd`是测试数据和运行入口。文件按真实职责拆分，无需为每个函数配一个接口类。

系统函数可以直接调用另一个具名函数，例如探索完成调用`crew.add_experience`，购买调用`economy.can_pay/pay`。调用顺序在入口或完成函数中写明；函数不通过UI信号寻找下一步工作，也不创建异步业务任务。新玩法通常增加一个规则函数、配置列及测试场景，不增加一层调度基础设施。

## 2. 数据放在哪里

| 唯一所有者 | 字段及使用方式 |
|---|---|
| session.campaign | 最高到达、生涯最高、通关集合、永久授予、当前关/战点/距离、航行/战斗/撤退/等待状态、驻守策略和返回目的地；出击/通关触发equipment清锁 |
| session.economy | Amount钱包、带来源的收入样本、原生生产窗口、宿主可拾取物及领取标志；定时物在生成时持有固定最终amount与productionBase，移动和领取不重新读取收入倍率；native只生成掉落，不写余额 |
| session.equipment | 船型、全部保存槽位、付费等级/装备ID、switchReadyAt旧兼容字段（不再锁定换装）、启用范围；reactor子数据保存等级和模块分配 |
| session.enhancement | 强化购买等级、排列、分支；全局攻击/来袭历史由native核保存，宿主读其计数，不存第二份可改计数 |
| session.research | 科技等级/工作量/当前项、投入额和比例、下次刷新时刻、原生实际收入历史峰值 |
| session.crew | 船员经验、岗位和唯一占用登记；登记含crewId、kind、targetId，kind为system_job/planet_explore/planet_build/galaxy/hyperspace之一；施工targetId含planetId与buildingId，探索只含planetId |
| session.planets | 每颗星球探索度、探索者引用、施工工作、ready/built、征服与自动模式 |
| session.galaxy | 区域、蓝图seed、节点和建筑状态、探索/建设/升级剩余工作、收入计时及随机状态 |
| session.hyperspace | round/run、四路线记录、手动与挂机各自凭据、仓库实体、装备/预设引用、挂设成长、收藏/过滤/改造最近结果 |
| session.notifications | 教程进度、解锁seen/read、研究完成和奖励未读；父级红点由子项计算 |
| session.time | 接受但未执行的游戏时间段、固定步余数、暂停原因、离港现实等待、现实收入窗口时间；不是每个系统各自计算帧差 |
| session.settings | 声音、数字显示、跳过教程、自动保存间隔、页面偏好；保存到独立设置文件 |
| Battle所持native核内部 | 玩家实时盾/甲和模块损失/记忆保护/延期；敌人、武器冷却、攻击/弹体/光束、事件队列、暂态Buff、传说状态、攻击/来袭历史、战斗随机与ID分配 |
| 表现对象 | 镜头、插值、shader参数、音效/粒子池、页面控件、纯显示统计；均不写上述状态 |

native核由Battle从新档/读档持有到结束会话；没有敌人时仍可按航行规则恢复玩家、处理合法遗留弹体，不因为换波重新创建玩家防御。Battle读取`player_view()`、`enemy_views()`等只读数据并转换为出航容量、盾甲耗尽、战斗展示等语义；Campaign和页面不持有内核对象，也不调用内核方法。显示副本不是战斗权威。保存需要计数和防御时从native一次读取。重铸明确重置native历史，新遭遇不重置跨战斗历史。

Campaign只依赖Battle的防御容量判断、出航重置、死亡撤退、恢复与结波接口；这些操作由Battle保持原native调用顺序。Battle持有原生表现器并把内核绑定到retained/GPU表面，页面只交付画布、材质和光束回调，并请求战斗展示。敌人绘制在Battle读取原生视图后直接完成；弹体仍走原生GPU路径，不逐帧拷贝全部几何或重建配置。更换native核时，适配集中在Battle。

派生装备结果是`CombatConfig`：各武器/防御数值、当前有效强化/传说、来源ID、掉落倍率和几何引用。`build_combat_config(session)`只组装下面定义的静态输入；核用共享C++数值函数完成03的历史与动态层，UI读取核计算的模块明细。只保留一个`combat_config_dirty`标志及原因列表；相关操作结束或战斗前重算，清标志。不用领域版本号串联缓存。

船员占用先检查`crew.can_assign`，通过后同一函数依次解除旧任务引用、写新占用和新任务引用。没有异步间隙；保存加载时从任务重建登记并检查一人多用。用于任务完成的crewId和任务ID不接受UI临时指定。

## 3. 一次玩家动作

页面直接调用具名入口，如`session.buy_levels(slot_id,count)`、`session.assign_crew(crew_id,target)`、`session.claim_hyperspace(run_id)`；这些入口调用`equipment.buy_levels(session,slot,count)`、`crew.assign(session,crew,target)`、`hyperspace.claim(session,run_id)`。Godot主线程输入事件与frame调用顺序执行；native内部没有页面回调，页面在业务函数返回后刷新，因此不需要动作路由总线或通用请求队列。函数返回`{ok, reason, values}`，失败原因是稳定枚举供显示；普通按钮不需要持久命令ID或读版本锁。

每个有费用/引用的直接动作，或批量操作中的当前子动作，先检查其全部条件再开始写：目标存在且可用→岗位/容量/锁定等约束→按当前数据计算实际费用→所有资源足额→需要的native配置格式与数值合法。检查通过后顺序扣费、改字段、更新占用/派生数值、通知native，最后标记保存脏并返回结果。期间不`await`、不写文件、不调用页面信号。本动作参数错误或资金不足时不改变本动作状态，随机也不前进；这不要求撤销批量操作此前已成交的子项。单槽+1/+10须整批付得起；全体升级按武器槽后防御槽逐槽处理，买不起跳过、已成交不回滚，具体口径唯一见[03第1节](03-progression.md#1-舰体槽位与升级)及下表，公开接纳顺序见本页[现行模块交接契约](#现行模块交接契约)。内部程序错误不是可继续游玩的失败分支；停止推进并保留上一有效存档，不把部分计算结果写为正常存档。

预览只是当前费用/保留范围的显示；实际按钮携带选择，函数重新计算。若改造确认页显示的是某件物品的具体形态，点击时比较droneId及所选词缀/锁定槽仍匹配，不匹配返回“对象已改变，请重开预览”，无需所有业务统一乐观锁。固定费用且结果不影响配装约束的改造在条件通过后才推进正式随机。定向改造的费用依实际抽数，升传说等随机结果也可能改变最终配装合法性：这些函数复制这一架机的随机状态到局部变量，完成有限抽样得到确切费用与结果；检查结果组合合法且钱够才扣费、写结果并把局部随机状态赋回，不足、组合非法或达到抽数上限则丢局部变量。普通升阶的概率失败按04属于收费结果，不能当成条件不合法而免单。预览也只用该局部状态，不改变真实流。领奖以凭据Pending→Claimed避免重复；改造窗口一次操作保留operationId及最近结果用于同一次回调重入去重，不维护所有按钮的永久日志。

| 直接动作 | 必须先查的条件 | 通过后的调用顺序 |
|---|---|---|
| 出击/驻守/撤退 | 关与战点有效、解锁；不能以无装甲拒绝有护盾的出击或恢复 | 收取应结算物→改变航程→native开始/结束相应波→更新显示 |
| 槽位+1/+10/MAX | 槽身份、等级/材料门槛、全部费用 | pay→升级槽位→刷新配置→native按03升级规则调防御 |
| 全体升级 | 舰体与启用槽合法 | 武器槽再防御槽顺序逐个报价/购买；买不起跳过；全部结束才刷新UI，不在槽间执行自动岗位 |
| 换装/换舰/无人机装备或预设 | 最终槽位组合（首防御槽不可为空、类型可选）、封存、容量、品质限额、Higgs炮数量 | 写最终配装→修正无人机装备序列→截断反应炉分配→刷新native并按refit保防御比例 |
| 强化/反应炉 | 等级费用或合法排列/节点/模块分配 | 扣费或写选择→重算属性/容量→按03对应动作调防御 |
| 科研选择/投入 | 科技前置、资源、合法比例 | 写当前项/投入；推进时才按片段扣实际投入 |
| 船员/星球任务 | 解锁、空闲/占用、工程状态 | 更新引用和占用→写任务→重算受影响属性 |
| 星系启动 | 区域已开放且未启动 | 生成蓝图一次→写节点与工作状态 |
| 超空间开始/退出/领取 | route/run/round、岗位、无票模式、探索时长、容量和返回点 | 按04写凭据及任务/占用→必要时换战场；领取先检查全部仓位再入库/入账并标Claimed |
| 拆解/改造/兑换/挂设 | 实体保护、引用、可改形态、锁词缀、费用、最终配装约束 | pay→正式随机→改实体与材料→记录最近结果→刷新native |
| 收取/已读 | dropId或通知ID有效、尚未处理 | 收取入账和峰值→标已收→刷新配置；已读只改该通知 |
| 导入/新档/重铸 | 文件或所选保留集完整合法 | 按06独立构造新的会话，成功才替换当前session；这是低频整局操作 |

例如19→20级升级，报价同时包含普通费用和10简并物质，成功后应用第一阶1.6进化倍率。普通防御付费升级补新旧容量差，实际换装保比例，研究/强化/分配按03保持绝对值并钳容量。飞行中的攻击保留出生数值；配置更新只影响随后出生或明确动态读取的部分。

## 4. 一帧怎样运行

Godot入口`GameSession.frame(real_dt,focused)`只由主场景每帧调用一次。测试直接调用同一个函数。现实钟由入口传入经过的时间，启动/加载另传UTC；随机用固定的native战斗流与session的世界/任务/改造流，存其状态即可，不建立通用时钟或随机工厂。

```text
frame(real_dt, focused):
  update_pause_and_departure(real_dt, focused)
  accept_paid_time(real_dt)           # 01微粒公式；暂停时不接收业务时间
  while not paused and not departing and not stopped_on_error
        and enough_time_for_next_step() and frame_budget_remains:
    step_game(1/60)
  publish_changed_ui()                # 此时才发页面通知
  save_files.request_if_due()        # 只复制完成步骤的数据
  presentation.draw(kernel, visual_dt)
```

`step_game(dt)`显式调用01共享顺序：记录手动超空间耗时→推进生产游戏钟→`hyperspace.advance_online`→`planet.advance`→`galaxy.advance`→`crew.advance_jobs`→`economy.spawn_timed_resources`→`research.advance`→`economy.collect_due_drops`→`research.refresh_auto_input`→刷新发生变化的CombatConfig→推进当前航程和`kernel.advance_combat`→取战斗结果→处理波结束/死亡→更新解锁通知。武器临时效果、恢复、接触、延期等全部只在advance_combat内部按到期时刻推进；共享阶段不递减这些字段。同刻顺序按01第3.2节；本步完成的科研/探索等只舍去自身完成后尾段，新任务下一步积累，其他阶段仍执行完整dt。

`economy.spawn_timed_resources`读取生成时的战点倍率、资源采集挂设与对应研究收入因子，写入最终`amount`和独立`productionBase`。之后的`collect_due_drops`、手动领取、移动到玩家位置及终波强制领取对定时物只使用保存的数值；研究在本步生成之后完成也不能改写这批物，下次生成才使用新因子。此读取时点只属于定时物，普通敌人掉落仍按01的领取规则。

星球完成直接增加探索度、推进施工、发经验；船员若升级则立即重算岗位效果和反应炉容量；后面的共享阶段读取新值。普通掉落入账更新原生窗口与AI峰值，战斗前刷新新属性。战斗结果取回后产生的新掉落本步不重新跑整个共享阶段：有立即强制领取条件就直接领取，其余留在宿主掉落列表等待手动或后续到期。强制领取导致的AI峰值改变在下一次native推进前同步。

完成一个固定步后才打开新解锁提示并持有对应暂停原因；玩家关闭提示时直接释放该原因。正在执行的步不被页面回调打断。进入暂停或离港时，即使已有待执行时间也停止循环；余量保留，不退还已扣微粒，恢复后接着消费。循环预算耗尽则保留未消费时间，下帧继续；保存记录已扣微粒的待执行区间，恢复不能重复扣。无需为整个步骤创建可回滚副本。运行错误使会话停止并显示错误；磁盘错误仅影响保存状态，不倒退游戏。

## 5. 以现有native/GPU为基础

### 5.1 现有实现和需要补入的规则

`combat_execution_kernel.h`已有Actor、Weapon、Attack、Instance、Flight、Timed、Defence，内部roots/ejections/repeats队列及反馈数组；`advance`不回调Game。保留generation句柄、活跃弹体索引、MotionArena、出生快照、接触检测、光束周期和紧凑激光路径。`combat_presentation.h`/`combat_retained_presentation.h`读取该核的活跃顺序和generation，使用MultiMesh与shader绘制；这些是目标结构的基础。

现`native_execution_compiler.gd`只允许部分范围：手动超空间被拒；武器分支只放行熟练B2、连发B1/B3，防御分支全部被拒；传说只放行scatter_pulse、prism_tower、laser_charge、strange_matter、precise_guidance、wild_missile、endless_beam。其数值入口要求普通double且全局计数小于2^53。现`native_execution_session.gd`在数值边界、非终波/终波结束都交回旧游戏。这些限制不进入新运行流程。

| native中续用并改接新数据 | 必须在同一核补齐 |
|---|---|
| 四武器、导弹离管/运动、连发/连锁、光束、敌盾甲/抗性/反应装甲、基础强化防御、现有七传说算法 | 02全部尚未接入的强化A/B分支：熟练A/B1/B3、连发A（B2第二代禁用）、武器天生率0/critical主效果25%与B3保底效果及原率爆伤判定、其他暴击分支、适应/记忆/延期全部分支；不得只删compiler拒绝条件 |
| 已有玩家模块损失、记忆保护、延期债务及计时 | 五传说higgs_cannon、dodge_counter、drone_master、black_hole、drone_rebuild；含同次冻结射线贯穿、共同闪避冷却、统御减伤、黑洞双方拦截/累计、重建禁用与重算；规则见04 |
| 现有掉落抽样、敌死亡反馈、紧凑激光反馈 | Amount全链路、int64历史计数、手动超空间编队和完成结果、无旧逻辑交接的连续波次/撤退/返回、配置变更及长期字段保存/全新战场恢复 |

宿主负责为所有启用普通槽和合法无人机产生武器定义，提供品质/等级/词缀/挂设数值和传说选择。核负责每个真实攻击和动态效果，不把黑洞、重建或分支放到GDScript帧后再补扣血。挂设收入、无人机仓库/改造和任务奖励仍属宿主，因为它们不参与接触计算。

### 5.2 静态输入、动态计算与新增状态

03的属性顺序在C++纯函数`evaluate_module`实现，宿主不把完整final数值当作base再次送核。每个配置模块传入：`charged_base`（Growth→进化→AI取整→反应炉取整后的Amount）、强化有效等级/启用效果/分支参数、按规定次序排列的planet/crew/galaxy/drone外部因子、周期/运动参数和来源ID。核取当前整数历史计算`ceil(charged_base×history_factor)`，再乘适用分支、依次乘外部因子；临时攻击Buff和暴击在攻击出生时继续处理。无论宿主预览还是核执行，都调用这个C++函数；预览显式传当前历史和临时状态，不能在GDScript复制一次熟练/适应公式。

攻击历史在规范主攻击创建时增加，再按02公式读取；来袭历史在尝试到达时增加，随后重算受影响防御上限，保持当前绝对防御并协调模块缺损，上限下降钳制。显示的总盾/甲是各模块剩余的求和；核中旧player_hp/player_shield兼容字段仅作只读投影，不能与模块损失同时独立写入。

新增规则以核内实际字段和函数实现：

| 状态 | 由谁更新 |
|---|---|
| 每武器同主目标计时、暴击后剩余加强攻击数、暴击叠层/到期、待连发代数 | `create_attack`读取/消费，`advance_combat`内部到期事件清除；来源失效时清该源状态 |
| Attack的critical与critical_bonus_applied两标志及已计算damage | 出生时写入，此后只读，随Attack生命周期退役；来源武器失效或临时效果到期不改已出生攻击快照 |
| 每防具同敌来袭层、周期护罩容量/到期、保护抗性/禁获期限；全局记忆减伤/清队减伤到期 | `receive_player_hit`和防御周期更新，敌死亡清对应来源层；与02分支规则逐项对应 |
| Higgs冻结起点/终点/full_width、活敌命中点和已命中集合 | 发射函数当次筛选线段带宽内目标并按距起点升序逐一命中，清场失效则停止；不建立飞行到达计时 |
| dodge_counter共享冷却；drone_master当前品质系数 | 来袭截获前处理，冷却内仍承伤；品质系数在装备/禁用集合改变时重算 |
| black_hole周期、吸收截止、我方Amount累计 | 双方命中入口先检查吸收；结束时对当时活敌发规定释放，不从伤害反馈再估计 |
| drone_rebuild次数、禁用droneId集合、叠层因子 | 致死检查中挑牺牲机并同步重算来源/容量、满防御、清债；成功则同次伤害不产生终止死亡 |
| strange_matter延期包、制导每批目标因子、野性批计数、棱镜塔及连接、无尽待机 | 沿用已有核内队列和上下文，按04与新来源身份接续 |

为重建和统御提供每架机的品质、词缀贡献及武器定义，核保存各机分项而不是只有宿主求好的全局总和。禁用一架时，核在同一来袭处理中删其活动贡献、重选有效传说/来源、使用同一`evaluate_module`重算；不会回调宿主等待配装重编译。宿主装备实体仍存在，UI读取核的禁用集合。遭遇结束清禁用后重新启用原装备贡献。

### 5.3 native对宿主的具体函数

```text
initialize(CombatConfig, player_initial, history_counts, rng_state, next_ids)
validate_configuration(CombatConfig, change_kind) -> error_or_ok
update_configuration(CombatConfig, change_kind) -> void
start_wave(WaveSpec) -> void
advance_combat(dt, GeometryInput) -> void
finish_wave(final: bool) -> void
begin_retreat() -> void
finish_retreat() -> void
clear_encounter(reason) -> void
take_results() -> BattleResults
player_view() / enemy_views() / presentation_membership() / presentation_beams()
read_history() -> {attacks:int64, incoming:int64}
write_persistent_state() / read_persistent_state(data)  # 历史/随机/ID，不含逐弹体和残血
```

`initialize`创建一次核，新档历史为0、随机为新seed、ID从初值开始并满防御。读档先恢复nativeState中的history_counts/rng_state/next_ids，重开战点也不清历史或回退ID；再按保存目的地建立全新满防御战场，允许重刷。`WaveSpec`含EncounterId、终波标记、敌人/武器/掉落定义、资源倍率和逻辑生成位置。开始前由配置和航程检查引用，start_wave只安装已验证编组。函数均为主线程同步调用，执行中不接受页面调用。

`validate_configuration`检查全部来源与数值，不修改核；同一动作随后调用`update_configuration`，中间没有其他操作。更新使用03的具名change_kind，直接改武器当前配置和对应防御；来源替换增加generation、取消尚未出生的来源任务和依赖该源的持续效果，已飞出且规则允许存续的弹体保留原Attack快照。普通数值升级不换来源身份、不重置冷却。换小舰按04卸下多余无人机，核同步删除其后续发射源。反应炉减容量先在宿主按模块序截断分配，再计算送核值。

`BattleResults`是本次取走的事实列表：有顺序号的命中/死亡/出生/退役表现事件、完整DropCreated值、是否玩家终止死亡/波清空/终波清空、全局历史计数当前值及伤害统计。玩家终止死亡只在当前盾甲均耗尽且重建失败后置位，不能从装甲投影单独计算。结果不是等待宿主批准的战斗方案；它记录核已经完成的扣血。`take_results()`移动并清空数组，宿主在同一函数内全部处理，不在中间调用UI或保存。随后再次调用只得空列表。

### 5.4 命中、掉落、奖励与波次

每次有效命中在核内按02顺序计算并直接扣盾/甲；我方普通炮及Higgs在发射函数内立即执行该步骤，敌炮/激光/导弹等则由接触触发，更新层数/历史和死亡标志；一名敌人只能第一次从live变dead时抽掉落。结果中的DropCreated带唯一DropId、资源ID、基础量、死亡时冻结倍率、逻辑位置和自动领取期限。掉落编译时已验证资源；宿主收到后直接加入列表，不在这里重新抽奖或校验“是否愿意接受”。表现事件可以合并，DropCreated和死亡/波完成结果不可丢。

宿主顺序消费：登记掉落→读取历史/伤害统计供显示→如果玩家终止死亡则开始撤退→否则处理波清空。重建成功在核内完成，不发送终止死亡；同刻互杀按01第3.2节的实际事件顺序处理。普通拾取按01入账并更新窗口/峰值，之后需要时刷新核配置。native内熟练/适应直接用自己的历史计数，避免宿主取结果前同一步后续攻击用旧计数。

* **非终波清空**：`finish_wave(false)`停止该波敌人发射、移除死敌可选目标；普通已飞出的合法弹体继续保留，失去目标的导弹按孤儿寿命处理，已发敌弹仍可在航行中接触玩家。普通光束失去目标结束；无尽光束按04待机等待后续目标。未实际离管且来源/目标已无效的计划按02取消或允许重选，不能为新波复活旧敌源。宿主进入航行，普通掉落继续存在；下个战点调用start_wave加入新编队，使用新EncounterId和全新actor generation，旧句柄不能命中新生敌。
* **终波清空**：核完成该次死亡及其允许的同刻派生，然后标记final_cleared，退役弹体、停止出生/连发/离管/光束及该遭遇攻击计时队列。保留已经形成的反馈/掉落供take_results取走。宿主把所有遗留物按自动领取口径收齐，主线记录通关、刷新解锁，进入3秒等待；超空间按04结算本run记录与奖励凭据后返回主线目的地。终波后不会再让遗留敌弹击杀玩家。
* **玩家终止死亡/主动撤退**：先接收已经发生的结果，`begin_retreat`结束敌群与攻击、清本遭遇传说禁用和临时队列，按02/04清延期和终止效果；宿主设置01后退目的地。撤退期间不发射；`finish_retreat`重建当前配置满防御并恢复可用无人机，按既定目的地进入航行或驻守。无装甲但有护盾不能转入选关或再次标记死亡。
* **换场/退出手动超空间**：`clear_encounter(reason)`清该场敌人/攻击，保留跨战斗历史和宿主进度；掉落先按该模式既定领取规则处理。每个run的route/level/luck/奖励凭据独立；切回主线用保存的目的地创建新波，不从旧Game接管对象。

攻击定义不可变，运行实体只改位置、生命期、目标与已触发记录。命中ID为`(EncounterId,AttackId,EmitterId,ordinal,targetId)`；EmitterId覆盖弹体、光束和计时释放，generation防止池复用产生旧回调。各参数的读取时点如下。

| 参数 | 取值时点 | 改变后的影响 |
|---|---|---|
| 等级、付费进化、研究、反应炉、外部静态倍率 | 攻击诞生 | 新攻击使用新值，旧弹体不追溯 |
| 熟练计数/临时武器增伤、暴击率/暴伤、暴击抽样 | 规范攻击诞生 | 存快照；同批成员共享规范攻击规则，同一次AttackId共享02定义的暴击判定序列与额外攻击判定；先按P抽critical，B3且critical为真时再按不含无人机C的R抽critical_bonus_applied；分别存两个标志和已计算damage。齐射/连发继承，新的独立攻击才重新抽样 |
| 连发是否触发、倍率、延迟、额外攻击机会 | 主攻击诞生 | 延时触发不再重抽；来源generation失效可取消待发任务 |
| 主目标列表/导弹轮转列表 | 主攻击诞生；待离管无效目标可按规则重选 | 飞出后不重锁普通导弹 |
| 连锁候选 | 第一次有效主命中（含即时炮）；光束连接建立/允许重绑定边界 | 连锁目标在载体出发后冻结，目标死则该次无效 |
| 目标护盾恢复、抗性、反应装甲/精准制导层 | 命中时 | 使用命中时真实防御，不冻结敌人未来状态 |
| 光束倍率 | 每个计划伤害跳时刻 | 用该跳持续时间与诞生参数 |
| 新奖励金额、领取加成 | 死亡生成/拾取执行分别取值 | 按01收入表，不全在发射时冻结 |


### 5.5 大数、几何和图形

06的Amount在C++实现一份算术，GDExtension向Godot提供相同操作和编码。钱包/研究使用该值，核的Actor.hp/shield、Weapon.base、Attack.damage、Flight.damage、Defence.maximum/loss/buffer、延期、黑洞累计、DropRule.amount/base、反馈amount及伤害统计全部改用Amount；概率、短时倍率、坐标/速度/秒数仍为double。会无限成长的乘积不能先double相乘再包Amount，逐项转换乘入；攻击/来袭/批次/ID用int64并检查范围。原生计数不再经double或2^53守卫，不因数值变大转给旧逻辑。

由宿主的逻辑姿态函数提供碰撞包络/炮口/玩家点，沿用`input_ballistic_geometry`/`input_geometry`/`input_player_point`所需的紧凑数组；几何变化时更新，静态舰体保留接触缓存。表现炮口独立调用`input_presentation_muzzles`，只改变绘图。GPU只收到坐标、角度、颜色、年龄和归一化血条等有限float，绝不承载伤害Amount；大数文本由Amount格式化。命中来自C++中的即时炮/射线判定、飞行接触或光束跳；shader或动画回调不能请求扣血。

沿用native retained数据访问，由Battle把核绑定到原生表现器，不逐帧把所有弹体序列化成Dictionary再让GDScript移动。页面所需的小型防御视图和结果列表可以转Godot值；接触反馈保留值拷贝，实体退役后仍可画火花。只有显示预算允许丢弃纯火花/文字，业务队列完整保留。

## 6. 页面连接与资源

页面包括战场/HUD、装备升级、AI、反应炉、舰体、强化、船员、星球、微粒、星系、超空间路线/仓库/改造/过滤、存档、敌情和教程档案。页面通过所属模块公开查询、具名操作或注入的协调端口连接，跨模块接纳由GameSession负责；无需每页额外Presenter/ViewModel类。显示查询返回金额、可用动作和禁用原因；属性明细来自build_combat_config相同结果，临时Buff另列。

主场景在本帧业务结束后一次刷新改变的页面。出生/接触/死亡映射到native表现、音效和池化粒子；掉落表现用宿主DropId绑定，鼠标逆变换到逻辑位置后以点/线段扫过查询拾取对象，再调用`session.collect_drop(drop_id)`。界面动画不延迟奖励到账，也不因面板隐藏停科研/星系。

静态`assets/`、舰体烘焙、shader、粒子/音效、星球外观、星系交通演出继续使用其资源ID；纯表现代码移除对旧Game可写字段的依赖。`game.gd`旧业务、旧测试与含另一套公式的balance模拟器/fleet_battle_runner退出新运行入口。删除`level_editor.tscn`、`scripts/level_editor.gd`和依赖游戏的配置/关卡/平衡编辑挂接；共用纯表现资源仍保留。无游戏依赖的命令行Excel编译、校验、测试运行与结果导出按各自职责保留或重写，不开发新编辑器。
**实现事实（main@7a85481，非目标布局）：** 当前舰桥按舰船、成长、星图、超空间、档案、设置分页；未开放系统及空页签隐藏。舰船页包含航行/驻守、装备/舰体和属性明细；星图包含人员、星球外观、星系地图/交通及重铸选择；超空间再分路线、仓库、改造、过滤。仓库可浏览主仓、溢出与封存，并使用现有通关门槛解封。档案包含飞行手册、当前敌情和通知；存档与个人偏好位于设置页。上述分页不冻结为设计要求；整屏构图、持续可见战斗与面板并列的导航及适配验收，以[13全局规范](13-art-interaction.md#20-整屏构图与全局ui)为准。

`Battle.attribute_details()`直接查询native已提交的武器、防具、当前倍率及临时标记；查询不推进时间、随机或计数，不在UI复写战斗公式。Planet/Galaxy的`visual_snapshot`与Crew的`galaxy_assignments`仅提供表现副本；旧星球/星系纯表现资源消费这些副本，暂停与倍速来自Session。

战场HUD从native读取当前/最大盾甲，以Amount安全比例绘制条形显示；数字与来源名在表现边界格式化，金额及存档仍保留原精度。舰体尺寸统一取资源`static_height`、`player_display_multiplier`及对应`playerVisualScale*`；敌舰配置宽高作用于实际alpha凸包包络。相同顶点供绘制和原生命中使用，不再独立放大贴图。炮台使用批准锚点及各武器的native真实目标建立同一姿态和真炮口，数值与屏幕发射坐标消费同一组端口；活光束按自身真实绑定目标更新，保留已接受的目标/端口修复。我舰`playerVisualScale*`参与上述共享舰体尺寸；当前`enemy_opening_*`敌舰在旋转后按普通框或条目`display_size`等比适配，覆盖旧`enemy_width`中间尺寸，`enemyVisualScaleSize*`不再决定这些key的最终大小。保留字段名不表示旧倍率仍生效；完整参数与覆盖顺序见[尺寸参考8.2–8.5](reference/ship-scale.md#82-我方五档实际倍率与舰体逻辑尺寸)，本次只校正文案，不改变实现。完整伤害明细位于档案。

Battle在重新出击、撤退开始/恢复及超空间返回使用同一遭遇退役路径：丢弃敌方表现描述、敌炮口与旧反馈，再按native过渡后的演员集合重建几何/姿态；新波敌炮台按UID绑定演员，不依赖上一遭遇的存储索引。**HUD实现事实（main@7a85481，非固定矩形契约）：** 当时防御、余额、伤害摘要由BattleHud负责，区域为y708–830、838–894、902–927，四余额两列两行；EconomyView负责掉落绘制/拾取。此处仅记录消费归属和当时矩形，不能据此要求保留大面板、空框或重复读数；目标信息层级与整屏/战场验收见[13](13-art-interaction.md#22-全局信息层级与适配)和[M1/V1](art/modules/battle.md)。

## 现行模块交接契约

模块级状态读取、操作/结果、变化通知、前端本地状态及跨模块接纳约束统一见[14模块前后端连接契约](14-ui-contracts.md)。本节保留入口锚点，不复制端口表；现有、候选未合主线与待补项按专页版本标记区分。
