# 05 游戏对象与执行结构

[唯一入口](README.md)。本页维护运行对象、时间推进及native/表现连接。玩法规则见01–04，数据保存见06，模块公开端口与接纳协议见14。

## 1. 实际需要的对象

| 对象 | 所有权与必要接口 |
|---|---|
| GameSession | 协调固定步、跨模块贡献、付款及native提交；向模块提供必要公开事实和具名callable |
| 领域Owner | Equipment、Enhancement、Reactor、Research、Economy、Crew、Planet、Galaxy、Campaign、Hyperspace各自持有本领域状态、候选和规则 |
| Battle / SpaceCombatKernel | Battle持有并驱动唯一native战斗核；核管理防御、攻击出生、运动、接触、传说与战斗随机，Battle向宿主和页面提供具名接口 |
| combat_setup / 共享几何 | 将装配与成长结果组装为native静态配置和逻辑几何，按实际变更更新 |
| 表现与页面 | 原生retained/GPU表现及Godot页面消费公开状态，维护绘制、插值、焦点与控件 |
| SaveFiles | 接收payload快照，串行写入与回收持久化结果；生命周期见06 |

运行配置直接读取发布JSON，由实际消费者校验所需字段。源码按上述职责位于`src/game_session.gd`、`src/systems/`、`src/ui/`、`addons/native_battle/src/`与`foundation/host/`；构建和配置发布命令见[foundation](../../foundation/README.md)。

## 2. 数据放在哪里

领域Owner独占自身已接纳状态与候选；Session通过公开端口协调。状态读取、操作、结果和通知的具体分工见[14](14-ui-contracts.md#5-既有跨模块接纳与通知约束)。前端本地选择/草稿见[14§6](14-ui-contracts.md#6-前端本地状态与资产接口)，持久化集合见[06§5](06-data.md#5-新存档格式与生命周期)。

native核随会话由Battle持有；换波沿Battle生命周期接口处理玩家、敌方和合法在途对象。Campaign通过Battle读取防御及航程所需事实，页面通过Battle查询与表现接口消费。装配配置更新和战斗动态读取按第5节；直接父攻击身份及保存水位的未决差异见[当前问题](review/conflicts.md#c4-parent身份与保存水位待裁定)。

## 3. 一次玩家动作

Godot主线程顺序执行输入命令和frame。页面调用领域具名动作或注入的Session协调口，接纳完成后消费结果。费用、占用、随机和批量部分成交由所属玩法规则定义；候选、钱包、native与通知的顺序统一见[14§5](14-ui-contracts.md#5-既有跨模块接纳与通知约束)。

危险事务的预览/确认/幂等见对应模块接口；导入、新档和重铸的会话替换见06。飞行中的攻击保留出生快照，配置更新影响后续出生或规则明确的动态读取部分。

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

### 5.1 当前执行归属

Battle/CombatSetup组装战斗描述，由native核执行普通与手动超空间战斗、强化/传说效果、Amount伤害与防御、int64计数和长期状态。核维护Actor、Weapon、Attack、Instance、Flight、Timed、Defence及事件队列，使用generation句柄、活跃弹体索引、MotionArena、出生快照、接触检测和光束周期。原生retained/GPU表现读取同一核，绘制层维护MultiMesh与shader资源。

宿主为启用普通槽和合法无人机提供武器定义、品质/等级/词缀/挂设数值及传说选择；核计算真实攻击与动态效果。挂设收入、仓库/改造与任务奖励由所属宿主Owner处理。身份/保存水位未决内容见[当前问题](review/conflicts.md#c4-parent身份与保存水位待裁定)。

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
* **换场/退出手动超空间**：`clear_encounter(reason)`清该场敌人/攻击，保留跨战斗历史和宿主进度；掉落先按该模式既定领取规则处理。每个run的route/level/luck/奖励凭据独立；切回主线用保存的目的地创建新波。

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

页面通过所属模块公开查询、动作与通知连接；所需跨模块命令由Session协调。可见显示帧合并更新，隐藏停止局部投影。对象身份、Amount与事件消费见[14](14-ui-contracts.md)。资产以稳定资源ID和公开状态连接；构图、导航、材质和可见完成标准见[13](13-art-interaction.md)。

## 现行模块交接契约

唯一正文见[14模块前后端连接契约](14-ui-contracts.md)。
