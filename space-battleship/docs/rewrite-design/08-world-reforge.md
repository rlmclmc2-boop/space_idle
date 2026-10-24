# 08 星球、银河与重铸

## W01 星球探索

状态按planetId：degree、conquered、crewId、tripRemaining/active、autoEnabled、buildingStates。Crew拥有占用身份；Planets拥有趟次工作。首星球由unlock表（当前30清关）开放，后续须planet_buff的planet_unlock效果及自身解锁。不得因表有行直接开放全部。

`start_exploration(planet,crew)`要求星球解锁、船员已解锁且空闲、无重复探索；时长=max(minTime,baseTime²/(baseTime+degree))。本趟开始记录所需时长，暂停冻结、离线不补。结束先对本趟开始时已有建设资格项目累计建设，再degree+1并检查新解锁，避免跨门槛这一趟提前施工。探索本身只给degree与XP，无直接攻防加成。

XP=round(baseExp×level[clamp(max(lifetimeMax,highestReached))].planetExpRatio×galaxy.crew_exp)，等级系统未开则0；共享经验见06。完成/召回释放该趟占用，自动偏好不改变。空间站激活后默认autoEnabled=true；无船员不自动招人，有效偏好只由用户开关改变，重铸/换人/读档不悄悄关闭。

UI显示星球、探索度、船员、倒计时、收益预览、自动开关、召回及建筑入口；预览用同公式，不通过UI读取创建进度。非法目标/占用冲突/未解锁拒绝，无XP/计时改变。保存degree、趟次工作、选择、自动偏好和建筑；普通死亡无影响。A-WORLD。

## W02 星球建筑与永久加成

适用范围=min_planet及planet_rule(all/only/exclude/tag)，planet_value是列表或标签，order排序、同序ID稳定。previous_id用于前置关联，不按显示顺序猜。建筑状态locked→building→ready→active；达到unlock_explore才进入building；每探索完成且extra_crew达标才+1 build_progress，到build_explore变ready并释放建筑船员。ready不生效，显式`activate_building`后生效且持久，导航显示未领取徽标。

| type | 激活效果 | 来源 |
|---|---|---|
| auto_explore | 开启默认自动探索偏好；仍需合法船员 | station行 |
| refinery | 单星倍率=(1+config1×degree)^config2，各星相乘，只影响铁/铀直接掉落；生产采用精炼前收款基数 | refinery行 |
| equipment | 同式倍率作用共享装备投影，不改购买等级或费用 | workshop行 |
| shipyard | 开放重铸操作，不自动重铸；后续星船坞有适用条件和前置ID | shipyard/shipyard_later |

planet_buff：conquer来源只能征服后；condition为always/conquered/building_complete（必须实际active）；level_bonus:equipment/enhancement只改有效等级；free_charge不占反应炉分配且可>100%；crew_exp_share让所有合格船员各获完整探索XP；planet_unlock开放下一星；luck:all提供永久异空间幸运。按同字段聚合add→mul→max，基础为有add时sum，否则有mul时1，否则0，结果=max(base×product,maxValue)。显示按order，不让显示排序影响算式。

不明确的level_bonus:hightech残留不可自动作用新AI等级（D03）；实际当前PlanetBuff字段映射不消费它。配置校验需拒绝未支持effect，而非UI照显示业务不生效。激活影响容量时按03收敛反应炉和战斗状态；普通保存、隐藏不丢ready。A-WORLD/A-REA。

## W03 银河蓝图与开始

Galaxy owns regions{key,status,blueprint,nodes,buildElapsed,upgradeWork,assignments}。门槛来自unlock表和征服条件；状态locked→available→exploring（当前含建设）→developing→complete。核心初始化已有，功能节点按配置总数建立一次蓝图并保存；type/plannedType、requires、connections、nodeId、随机状态是业务事实，UI不能重抽或回写。

普通类型按shuffle bag、特殊类型按special_cycle生成，先完整计划后建设；无合法候选不消耗随机、不取类型。候选取最近depth且前置已建的空节点，再随机选一；同时只施工一个新建筑。无已派有效船员时不推进工作、收尾、升级、派发间隔或随机选点。核心和视觉桥不自动成为建筑效果。

## W04 银河建设、升级、生产与显示

每功能节点初建工作=explore_work_total/node_count；速率=explore_power_base+crewCount×explore_power_per_crew，达到工作后再等construction_time固定游戏秒；每新节点前有build_interval派发延迟。多船员只加速有工作率的阶段，不缩短固定收尾。所有功能节点激活后进入升级，共享upgrade_power_base+crewCount×upgrade_power_per_crew按并发中的节点均分，最大并发concurrent_upgrade_count；目标级工作量upgrade_cost_lvN，完成+1级。所有节点max_lv才complete。

可见/隐藏tick控制批处理/显示频率，不改变已接受游戏时间。换船员前按旧人数结完待处理区间；不把过去时间乘新人数，也不离线补建设。避免旧隐藏pending_time+新通用积欠双重记账：新Session只给已确定crewCount的区间，Galaxy同步结到最近完成边界再接受修改。

单建筑贡献=base_effect×当前激活等级，状态active/upgrading才有；区域内同效果相加，crew_exp/equipment_value/charge_max/gem_fragment每区域加1后区域间相乘；iron_auto_ratio/uranium_auto_ratio跨区域相加。每income_interval结算：金额=该资源过去60游戏秒直接收入productionBase之和×自动比例×本次累计结算游戏秒，派生收入不进入该基数。产出与帧率无关；不足一个区间的时间保存。这是当前rates与advance两处组合后的实际口径，不除以60；窗口用于取样，不自动把其总和当每秒速率再平均。作为R保留建议交审阅，不能以单位整理名义改变产量。

显示保留已批准平台/总部/桥/交通艇、视角、缩放、施工脉冲。逻辑蓝图的nodeId/type/前置不因布局重画变化；可视位置仅派生。交通艇数量上限max_transport_ships、脉冲上限max_visual_pulses、出发延迟/间隔来自Excel；艇到达不得产资源或完成建筑。隐藏停止视觉更新，显示时从状态恢复，不重放所有动画。

接口start_region/assign_crew/advance/read_layout；非法前置、无有效船员、未知类型拒绝/不推进；配置失效报告不生成替代类型。保存完整蓝图、节点工作/收尾/升级/级、收入余时及RNG；普通死亡不重置。A-WORLD/A-UI。

## W05 重铸操作

必须星球已解锁、船坞active、该星未征服、没有手动异空间。UI先展示本次永久收益、起始关、逐域保留/清空、无人机保留名额/解封条件；用户确认后提交一次操作。操作先验证全部名单、容量和新状态，再整体替换会话；不自动保存、不以删存档代替重置。

主线从planet.reforgeStartLevel开始，前关视为已越过但不补战斗收入；旧已见提示不再刷，恢复到该阶段的合法已获得解锁；crew/planet永久解锁保留。新战斗满状态按普通新会话初始化，旧弹体/债务/报价失效。

## W06 保留/重置矩阵（R建议，D09审阅）

| 内容 | 重铸后 | 理由/关联 |
|---|---|---|
| 普通铁/铀余额 | 保留 | 当前reserve不随本轮成长清空 |
| 强化碎片/购买级/历史/分支/顺序 | 清零/初始 | 新一轮成长；永久赠级另算 |
| 装备/舰船/模块购买级 | 回新轮起始配置 | 不用有效赠级回填实际级 |
| AI科技/工作/投入/峰值 | 重置 | 当前新轮科研状态；用户需确认完整范围 |
| Reactor等级/分配 | 回Excel初始 | 不留超新容量分配 |
| 四材料/核心 | 清零 | 当前重铸路径如此，须确认 |
| Crew级/XP、Planet探索/建设/自动偏好、已征服成果 | 保留，当前星征服生效 | 占用任务是否继续按D09明确，不复制旧战场 |
| Galaxy蓝图/级/工作 | 保留建议 | 与永久世界进度一致，需D09确认 |
| 无人机 | 仅显式keep，封存；其他删除不返拆解奖励 | 名额含本次增加，默认清装备/预设 |
| 路线历史/传说seen/collection/挂载成长/筛选 | 建议保留；后台run取消/领取规则须D09确认 | 不是照搬旧序列化字段 |
| chrono、收入窗口/生产钟、熔炉峰值 | 分别明确；不以“全profile重置”笼统处理 | chrono建议保留，D10熔炉另决 |
| seen/read教程、音乐/引导/保存间隔 | 保留 | 不重复提示，不重置用户偏好 |
| 战斗瞬态、未确认报价、旧会话引用 | 清空 | 防止跨轮重复结算 |

D09未批准前不能执行重铸实现；保留“用户审阅”是规则决策，不要求以后每次游戏内重铸再次向开发者审批。
