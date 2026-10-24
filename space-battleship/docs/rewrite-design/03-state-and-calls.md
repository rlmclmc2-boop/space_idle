# 03 状态与直接调用

## S01 结构与唯一所有者

这是单进程单逻辑线程设计。Godot负责宿主和UI；C++ native负责战斗热路径与共享数值；GDScript组织非热点玩法。模块是职责划分，不是一套服务容器。目标目录可用 `game/{progression,economy,equipment,enhancement,research,crew,reactor,hyperspace,planets,galaxy}`、`combat/`、`presentation/`、`platform/`、`tools/`；不强制每个域复制controller/service/repository三层。

| 所有者 | 持久事实 | 会话事实 | 不拥有 |
|---|---|---|---|
| Progression | cleared/reached/lifetimeMax、旅程位置、守关/死亡偏好、earned/read/seen解锁集合 | 航行/遭遇/撤退状态、提示队列 | 资源、战斗HP |
| Economy | 每种可花费资源/材料/核心、必要收入峰值与生产进度 | 掉落实体领取状态、有界收入记录 | 装备等级、第二套精确余额 |
| Equipment | 选中舰船、每模块装备ID/购买等级、槽位配置 | 换装禁用到期时间（是否跨存档见09） | 血量、防护、派生面板数值 |
| Enhancement | 购买级、全局攻击/受击历史、顺序、分支 | 无；临时分支效果在Combat | 独立宝石背包 |
| Reactor | 等级与分配 | 无 | 游戏加速时钟 |
| Research | 科技级、工作量、选中研究、投入、自动比例/已过时间、收入峰值、未读 | 派生研究速度 | 科学家、techPoints |
| Crew | 各crewId等级/XP、岗位、升级模式 | 购买任务计时 | 复制星球/银河工作量 |
| Hyperspace | 历史、后台工作/奖励状态、仓库/预设/收藏/筛选、挂载成长、私有随机状态、重铸封存 | 手动战场引用、未付费请求、报价 | 第二钱包、主线战场快照 |
| Planets/Galaxy | 探索、建筑、激活、征服、自动偏好；实际蓝图/节点等级/工作量/随机状态 | 显示插值无归属 | UI相机/模型、其他域加成副本 |
| Combat | 无普通战场持久现场 | actors、weapon sessions、flights、CD、HP/shield、保护、债务、效果计时、战斗RNG | 配置源、存档文件、页面节点 |
| UI/Presentation | 仅明确用户偏好 | 选中、滚动、草稿、控件、特效/轨迹、动画血条 | 可消费余额、伤害判断 |
| Session/Platform | SaveDocument组合/设置 | 当前mode、time、单个Combat引用、配置引用 | 各域全部字段的副本 |

ID为稳定业务身份，显示名称可变。派生数值通过 `Attributes.query(module, context)` 计算；非热点可直接计算，只有证明需要的缓存才按明确依赖失效。攻击快照是该次攻击所需事实，不是整份世界快照。

## S02 操作契约与失败

普通入口 `operation(args) -> Result{status, code, changedIds, payload}`；status为applied/no_change/rejected。拒绝不花费、不抽随机、不部分修改；no_change不发伪变更。错误码给UI翻译，不把显示文字当逻辑条件。所有操作在两次完整逻辑推进之间或其明确域阶段执行，不允许UI回调重入。

不建立全局事件业务总线、每步全量快照、跨域通用事务或每层独立revision。一次操作先检查全部条件，预计算可能失败的值，再在同一同步段完成修改，最后通知UI。需要持久预览的无人机报价只记录对象版本、请求和必要依赖；用户确认时重验，不能把这种机制推广至每次恢复一滴血。

| 调用 | 输入与校验 | 直接调用顺序与结果 | 错误/UI/验收 |
|---|---|---|---|
| upgrade_equipment(slot,count/mode) | 启用槽、合法装备、费用/数值范围、资源 | Equipment报价→Economy支付→Equipment改级→Attributes计算→Combat应用变化→局部UI；不写盘 | insufficient/locked/invalid；保留选择；A-EQP |
| change_loadout(ship,slots) | 舰船解锁、槽与无人机适配、冷却、传说限制 | 先算最终装备及无人机合法集合和新容量→一次安装→按既定剩余比例调战斗防御→通知 | 不得先收费/摘装备再失败；A-EQP/A-DRONE |
| settle_kill(actorId) | Combat已完成唯一死亡转换 | 战斗产出一次掉落结果→Economy建立待拾取→Progression检查波次→Presentation反馈 | 重复死亡通知不能重奖；A-BTL/A-ECO |
| collect(dropId,mode) | 未领取、可拾取、尚未过期 | Economy计算损耗并收款→记录收入→刷新科研峰值/生产输入→通知UI | 重复/过期返回拒绝；A-ECO |
| research_step(dt) | 当前研究合法、资金可供时段、可完成边界 | Research算分段工作和投入→Economy支付实际时段→Research推进/完成→Attributes→Crew仅完成后续研 | 资金耗尽切到免费基础速度，不负余额；A-RES |
| assign_crew(id,target) | 已解锁、目标合法、占用冲突 | 按旧分配结完已接受时间→Crew更改唯一岗位→目标读取新贡献；没有第二份派遣权威 | busy/locked；不偷撤探索者；A-CREW |
| complete_exploration(planet) | 有效进行中一趟 | Planets结探索/建设→Crew发XP→激活资格改变→刷新视图 | XP恰一次，建设ready未激活无收益；A-WORLD |
| activate_building(id) | ready、前置满足 | Planets改active→贡献重算→Reactor容量收敛→Combat合法重配→通知 | 失败不先激活；A-WORLD |
| claim_hyperspace(runId) | completed_pending、空间/奖励合法 | Hyperspace已冻结奖励→Economy收材料→Inventory入库/挂载成长→完成run→UI | 满仓保留原奖励不重抽；A-HYP |
| forge(quote) | 报价依赖一致、可修改、资金足够 | 使用私有RNG计算一次完整改造→Economy支付→Drone改动/RNG推进→Attributes/Combat→通知 | 预览不扣钱、不推进正式RNG；A-DRONE |
| reforge(request) | 船坞active、未征服、保留名单/解封条件合法、模式允许 | 预计算09重置清单→停旧Combat→域内重置/保留→新旅程/Combat→统一UI刷新 | 无中间半旧会话；不假装自动保存；A-RESET |

跨域加成规则：资源收益由Economy统一应用；装备属性由Attributes统一组合；Research只提供科技贡献；Galaxy/Planet/Crew/Drone只返回贡献，不改equipment/config基值。收入峰值查询不是精确账本，支出不是收入，派生生产不反哺其生产输入。

## S03 Combat边界API

`create(configCombat, loadoutStats, encounter, rngState) -> Combat | error`；`advance(gameDt) -> StepResult`；`apply_loadout(change)`；`read_actor(id)`；`read_metrics()`；`drain_outcomes()`；`reset(reason)`。创建前验证全部能力和数值，不运行半场后才发现效果无实现。StepResult报告接受时间、完成结果、是否终止；不通过UI查询推进。

内部状态归native。GDScript只传完整配置边界变化或命令，不逐弹回调。outcomes是有界消费批次，不保存永久事件流；只包含业务所需击杀/掉落/统计与表现事件。渲染可读常驻结构或借用只读缓冲（使用期限到下一次推进），不能写入。跨场景ID采用会话代号+单调局部ID，旧引用无效；不重建分布式句柄服务。

后续扩展例：新普通武器填Excel并选择已有模式；新攻击模式扩展native模式函数但复用伤害管线；新科技effect增加一个明确贡献函数；新船员岗位复用已有玩家操作。没有真实第二用途时不抽象新框架。
