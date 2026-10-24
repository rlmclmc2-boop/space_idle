# 05 实现结构与接口

[回唯一入口](README.md)。本章定义建议采用的工程结构，不新增玩法；挂起玩法只能通过08决议后写入规则实现。实现语言以 Godot GDScript 为参考，现有C++执行器可作后端；领域对象不继承Node，不查SceneTree，不读文件，不发全局写事件。

## 1. 目录与依赖方向

```
src/
  bootstrap/        # 启动装配、配置/存档加载、会话替换
  application/      # SessionRunner、命令路由、跨域用例、读模型组装
  domain/
    common/         # Amount、ID、时间、随机接口、错误值
    campaign/       # 航程、解锁、驻守、通关、重铸进程
    economy/        # 钱包、收入样本、收取物
    equipment/      # 船型、槽位、反应炉、属性贡献
    enhancement/    # 全局强化等级/顺位/分支/历史
    research/       # AI研究、投入、峰值
    crew/           # 成员、岗位、全局占用
    planets/        # 探索、建筑、征服Buff
    galaxy/         # 节点工程、建筑/升级、产出
    hyperspace/     # 任务、奖励、无人机、改造、过滤
    combat/         # 战场、攻击、接触、伤害、效果、参考执行器
  ports/            # 配置、保存、时间、战斗执行器、图形快照接口
  adapters/
    godot/          # 输入、音频、视口、资源加载、文件写入
    native/         # 现有native桥、快照编解码、能力检查
  presentation/     # 各页面Presenter、ViewModel、战场反馈消费
content/            # 编译后只读运行包；不可手改
config_excel/       # 人工内容权威
config_schema/      # 固定字段类型与规则ID注册；不藏数值
config_tools/       # 无游戏依赖的命令行编译/校验
tests/
  excel/            # 独立用例数据
  runner/           # 同一会话/命令/执行器的场景运行器
  contracts/        # 数值、导入、保存、执行器合同
```

箭头只能从presentation/adapters/application指向domain；domain.common不能引用其他业务域。跨域规则通过只读输入结构传入，不把整个GameSession传到每个规则函数。application知道多个领域以协调事务，UI不持有可写domain对象。无需为每个值建立十层接口；接口只放在IO、时间、随机、执行器等确实有替代实现的边界。

## 2. 状态唯一归属

`GameSession`持有九个长期领域状态及一个战斗状态，反应炉是EquipmentState子状态，解锁与通知分别归CampaignState子状态和SessionNotificationState（非成长域），玩家设置单独为UserSettings。

| 所有者 | 权威字段 | 不属于它 |
|---|---|---|
| CampaignState | 最高关/已通关、生涯最高、当前航程、驻守策略、永久授予解锁、教程进度 | 敌人残血、钱包余额 |
| EconomyState | Amount钱包、原生/派生收入样本、可收取物及唯一领取状态 | 无人机实体/研究进度 |
| EquipmentState | 当前船、全体槽位及启用范围、换装锁；ReactorState等级与分配 | 实时剩余盾/弹体 |
| EnhancementState | 购买等级、顺位、分支、全局攻击/受击历史 | 同源叠层、护罩倒计时 |
| ResearchState | 科技等级/进度/当前项、投入额/比例/刷新时刻、收入峰值 | 资源余额、研究面板顺序 |
| CrewState | 成员经验/岗位、统一OccupationRegistry | 星球探索工程量 |
| PlanetState | 每星球degree、探索任务、建筑工作/状态、征服 | 船员经验账本 |
| GalaxyState | 区域状态、蓝图seed与节点进度、建设/升级任务、随机状态、收入计时 | 纹理脏块、交通艇实例 |
| HyperspaceState | round/run、手动/挂机凭据、记录、无人机实体/引用、挂设、过滤、收藏、改造回执 | 专用材料余额 |
| BattleState | encounter、战斗个体/模块损伤、攻击实体、冷却、效果/延期、命中/死亡去重、战斗随机 | 全局永久等级、存档文件 |
| SessionNotificationState | 解锁seen/read、研究完成未读、奖励未读及进度绑定 | 解锁判定本身 |
| UserSettings | 声音、数字模式、跳过教程、自动存档间隔、视图偏好 | 关卡与经济进度 |

状态使用明确类型结构；禁止任意字符串键的跨系统Profile大字典。对外返回不可变值对象/副本。`version`按领域修改递增；同一事务的sessionRevision只增一次。派生数据带dependencyVersions，不保存为第二份权威。

占用登记项为`{crewId, kind, targetId, reservationId}`，kind仅一个。CrewState提供统一 `canReserve/reserve/release`，星球/超空间/星系提交计划需携带占用变化。保存校验必须从所有任务重新构建占用，与登记交叉校验，发现一人多用整体拒绝。

## 3. 命令、计划与结果

```text
Command {
  id: CommandId, kind: registered enum,
  sessionId, expectedRevision?: int, payload: typed per kind
}
CommandResult {
  status: Applied | NoChange | Rejected | Deferred,
  reason: ReasonCode, revision, transactionId?,
  payload: typed, events: DomainEvent[]
}
ChangeSet {
  reads: (owner, version)[], writes: OwnerReplacement[],
  debits: AmountMap, credits: IncomeReceipt[],
  rngNext: StreamState[], events: DomainEvent[], postconditions: Check[]
}
```

`plan(command, readContext)->ChangeSet|Rejected`无副作用；`commit(plan)`在会话边界同步检查读取版本、钱包足额、所有后置约束，然后安装所有替换状态。安装阶段不await、不回调UI、不进行文件IO，安装后发布事件和标记存档脏。验证失败不推进随机、不扣费、不部分改状态；版本过期返回`StaleQuote`，UI可重新预览，不能悄悄用新费用扣款。

普通单机按钮请求由SessionRunner生成ID即可，无需通用网络协议。改造、领奖、导入/重铸等可重试动作持久保存最小回执；普通每帧移动无需保存无限命令历史。金额预览与提交共用同一quote函数；显示更大数缩写不改变quote金额。

### 3.1 命令全集与写集合

| 命令组 | 主要输入 | 写集合/失败条件 |
|---|---|---|
| 出击/驻守/撤退/退出 | stage、guardPoint、policy | Campaign+Battle+已收掉落；未开放/非法索引/缺防御拒绝 |
| 购买槽位/全体升级 | slotId、1/10/MAX | Economy+Equipment+BattleRefit；无钱NoChange，非法类别Rejected |
| 配装/换舰 | hullId、slot choices、无人机调整方案 | Equipment+Hyperspace装备引用+BattleRefit；换装锁/容量/封存整体拒绝 |
| 强化购买/顺位/分支 | 数量/排列/节点选项 | Economy+Enhancement+CombatSpec；非法排列/未开放节点拒绝 |
| 反应炉购买/分配/均分 | 数量、module、Amount | Economy+Reactor+BattleRefit；分配钳制按规则，未知module拒绝 |
| 科研选择/投入 | techId、资源、Amount/ratio | Research；未达前置拒绝，不能以UI传来的速度代替计算 |
| 船员调岗 | crewId、岗位/target/mode | Crew占用+相关任务引用+派生属性；占用冲突拒绝 |
| 星球开始/取消/自动/施工/领取 | planet/building/crew | Planet+Crew占用+CombatSpec；未达门槛/ready不符拒绝 |
| 星系启动 | regionId | Galaxy+解锁投影；锁定拒绝 |
| 超空间请求/开始/退出/自动/停止/领取 | route、mode、receiptId | Hyperspace+Campaign/Battle切换+Economy+Crew；旧round、满仓、返回点无效拒绝 |
| 无人机装备/收藏/预设/挂设/改造/兑换 | typed IDs、operation args | Hyperspace+Economy+CombatSpec；引用、版本、保护、上限校验 |
| 过滤导入/导出、图鉴收藏 | filter/IDs | 只更新Hyperspace偏好状态；解析错误不覆盖旧规则 |
| 收取物 | dropId、manual/auto | Economy+Research峰值+通知；重复返回NoChange |
| 已读/引导确认 | topic、stableId | Notification/引导原因；不触发业务奖励 |
| 保存/导入/新档/重铸 | 操作token及验证过候选 | 整会话替换或保存请求；存档IO在提交后执行 |

只写方法可以创建事件；事件消费者不得在同步回调再次修改状态。UI若要响应事件发新命令，排到下一命令边界。自动船员和在线任务也走相同命令/计划函数，不能拥有一套“自动免校验升级”。

## 4. 时间执行接口

```text
SessionRunner.enqueue(command) -> CommandId
SessionRunner.advance(realSeconds, focusState) -> FrameResult
SessionRunner.run_game_time(gameSeconds) -> FrameResult  # 测试入口，无现实微粒消费
SessionRunner.snapshot() -> SessionSnapshot             # 仅完成边界
DomainStepper.next_boundary(readContext) -> GameTime
DomainStepper.plan_interval(from,to,readContext) -> ChangeSet
```

实时入口先接收按倍率分段的已付时间，再重复运行固定逻辑步。测试入口直接注入游戏时间但使用相同阶段计划器；它不能跳过业务费用，只有明确不会模拟“在线加速购买微粒时间”的区别。

每步：处理队列命令→固定共享阶段→战斗段→死亡/清关结果→属性/占用后置校验→发布读模型与通知。边界游标为`{stepId, acceptedTimeSegments, phase, domainCursor, eventCursor}`。事务失败时要区分“无效玩家命令”（拒绝并继续）与“内部执行/IO交接异常”（不继续接受不明状态的业务时间，保留游标）。同一阶段不得边通知边随意回到前一阶段。

D07确认后，以`(dueTime, phasePriority, sourceOrder, localSequence)`对到期事件排序。队列只保存真实任务边界（如光束下一跳、导弹离管、技能结束），不用为每个绘制对象建立通用定时器节点。不会影响玩法的纯线性连续区间可合并；会改变属性/目标/费用的边界必须切开。

## 5. 属性、攻击与战斗接口

```text
AttributeResolver.resolve(StateView, ConfigBundle) -> CombatSpec
CombatSpec {
  version, shipGeometryKey, moduleSpecs[], playerCaps,
  incomeModifiers, legendarySelection, effectRules
}
CombatExecutor.begin(EncounterSpec, CombatSpec, BattleSeed) -> BattleHandle
CombatExecutor.produce(handle, gameDuration, GeometryFrame) -> BattleCandidate
CombatExecutor.accept(handle, candidateId, transactionId) -> Ack
CombatExecutor.abort(handle, candidateId) -> Ack
CombatExecutor.prepare_reconfigure(handle, newSpec, RefitPolicy) -> BattleCandidate
CombatExecutor.export(handle) -> BattleSnapshot
CombatExecutor.prepare_import(snapshot, rulesVersion) -> PreparedHandle
BattleCandidate { id, baseRevision, nextSnapshot, consumedTime, hitReceipts[], deaths[], drops[], events[], rngNext }
```

`produce`只推进私有战斗工作集，已提交BattleState保持不变；死亡的掉落候选交Economy用例在同一个ChangeSet中准备收取物。SessionRunner验证全部候选后，在无回调的同步提交段同时安装领域替换和`nextSnapshot`，再调用不含业务校验/IO的`accept`切换执行器已提交句柄。accept必须是已准备的指针/句柄交换，不允许在此失败；所有可能失败的分配、转换和校验均发生在produce/prepare阶段。任一候选校验失败调用abort丢私有工作集，原战场、钱包、随机、计时游标均不改变。native若无法实现这种私有候选，则使用一步前完整快照+可验证回滚适配；回滚无法保证时不启用该后端。

已提交BattleState的唯一逻辑所有者是GameSession；当前后端可独占其物理存储，但不可自行越过会话commit。缓存镜像只读、带revision。快照保存只读已提交版本，不能保存未accept候选。执行器换出先export已提交状态，在新后端prepare_import并验证完整状态；两边都准备好后同步交换ownerToken，旧端才释放。失败仍由旧后端独占，不让新端启动。BattleState长期历史增量只含规范攻击/来袭计数，应用到EnhancementState一次；属性缓存必须在下一需要该历史的计算前失效。事件与快照有同一revision，UI不能把旧快照和新命中拼成未来伤害。

`AttackSpec`不可变，`AttackRuntime`有唯一可变实体（位置/速度/已触发目标/剩余寿命）。光束与计时释放也有`EmitterId`作为CarrierId的统一实现：所有伤害载体都有ID，即使无可画弹头。命中ID通式为`(EncounterId, AttackId, EmitterId, ordinal, targetId)`；同波重复回调无法重复扣血。

| 参数 | 取值时点 | 改变后的影响 |
|---|---|---|
| 等级、付费进化、研究、反应炉、外部静态倍率 | 攻击诞生 | 新攻击使用新值，旧弹体不追溯 |
| 熟练计数/临时武器增伤、暴击率/暴伤、暴击抽样 | 规范攻击诞生 | 存快照；同批成员共享规范攻击规则，同一次AttackId共享一次暴击与额外攻击判定；连发继承主随机结果，新的独立攻击才重新抽样；D03的第二次暴伤抽样单列保存 |
| 连发是否触发、倍率、延迟、额外攻击机会 | 主攻击诞生 | 延时触发不再重抽；来源generation失效可取消待发任务 |
| 主目标列表/导弹轮转列表 | 主攻击诞生；待离管无效目标可按规则重选 | 飞出后不重锁普通导弹 |
| 连锁候选 | 第一次有效主接触；光束连接建立/允许重绑定边界 | 连锁目标在载体出发后冻结，目标死则该次无效 |
| 目标护盾恢复、抗性、反应装甲/精准制导层 | 命中时 | 使用命中时真实防御，不冻结敌人未来状态 |
| 光束倍率 | 每个计划伤害跳时刻 | 用该跳持续时间与诞生参数 |
| 新奖励金额、领取加成 | 死亡生成/拾取提交分别取值 | 按01收入表，不全在发射时冻结 |

上述时点是新合同对现有快照规则的明确化；若某native后端做不同抽样/触发顺序，必须先登记差异，不能让后端决定玩法。

## 6. UI、表现与输入

每个页面使用一个Presenter负责命令转换、一个只读ViewModel负责数据。页面列表：战场/HUD、配装与升级、AI科技工厂、反应炉、舰体、强化、船员、星球、微粒、星系、超空间路线/无人机/改造/过滤、存档、敌情、教程档案。旧科学家、旧炉子面板、依赖游戏的关卡编辑/数值分析编辑面板不进入玩家界面。

ViewModel含显示值、完整Amount、可用动作/禁用原因和进度，不包含可写domain对象。界面不依据“余额看起来够”自行扣款。模块显示卡和战斗武器都读同一CombatSpec静态部分；战斗临时倍率有独立标识，避免把2秒增益永久显示在成长面板。

战场Presenter消费：出生→创建池化表现对象，PoseFrame→插值位置，ContactReceipt→局部火花/护盾波，DeathReceipt→爆炸，DropCreated→可拾取物映射，DropCollected→飞入资源栏。不同速度只改变表现密度和插值，不删业务攻击。GPU支持批量实例渲染与接触高亮，但不能向业务回写“动画到了所以命中”。玩家鼠标拾取输入先由视口逆变换得到逻辑位置，再由领域几何查询可拾取ID，路径划过拾取用线段扫过。

舰体资产可以继续用现有资源ID；显示倍率仅影响美术外壳时必须明确不改变命中包络。若玩家看到的护盾与命中几何重合要求需要调整，属于几何契约的版本变化，必须与测试一起审查，不悄悄改伤害参数。

## 7. 性能与扩展纪律

业务先以直接函数和小型值对象实现，避免完整状态每帧深拷贝。ChangeSet只替换变化子树，纯连续计时可用局部工作集；快照在发布边界构建。派生属性仅当依赖版本变化重算；舰体/资产解析缓存按配置hash+资源ID；战斗不反复解析Excel/JSON。

新增一个武器要实现规则ID、参数schema、攻击/运动/命中处理、表现映射和测试Excel场景；新增传说登记5个钩子中实际需要的钩子及衍生触发权限；新增资源只改注册表和明确消费者，不假定所有非铁都是铀；新增星系由同一工程/建筑规则接入。禁止用可执行脚本文本作为Excel公式扩展机制。

不预建任何不存在的网络联机、云存档、多人交易、PVP或编辑器体系。未来真有需求时增加端口；当前接口只服务已经核实的游戏功能。
