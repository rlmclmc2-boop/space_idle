# 结构与执行

## 1. 目标文件与依赖

以下路径相对 `space-battleship/`。这是职责划分，不要求每个数据结构单开文件；小型结构就近定义。

```text
main.tscn                         唯一正式场景
app/app.gd                        启动、窗口、页面生命周期、读档入口
app/session.gd                    命令调用、时间、领域执行顺序、自动保存
app/profile.gd                    纯长期数据；不挂 Node、Callable 或资源对象
content/catalog.gd                加载只读内容；按稳定 ID 索引
model/journey.gd                   主线/驻守/撤退/手动挑战的行程
model/economy.gd                   钱包、收入窗口、拾取物、生产
model/equipment.gd                 舰体、模块等级、装备选择、切换冷却
model/enhancement.gd               共享强化等级、排序、分支选择
model/research.gd                  科技、投入、工厂与续研
model/reactor.gd                   等级、分配与凝聚
model/crew_planets.gd              唯一船员岗位表、探索、建筑、征服
model/galaxy.gd                    银河节点工作、建筑、地图显示进度
model/hyperspace.gd                路线、挑战结果、挂机、奖励收件
model/drones.gd                    库存、装备、挂设、筛选、改造
model/stats.gd                     低频静态贡献聚合和战斗配置编译
storage/save_store.gd              新档读写、导入导出、一次性替换
battle/battle_bridge.gd            唯一 GDScript↔native 适配
battle/fleet_geometry.gd           纯数值阵形/舰体中心/炮口；不读场景节点
ui/pages/*.gd                      各功能页面；发命令、读摘要
ui/battle_view.gd                  native 显示数据→现有船体/特效
ui/art/*                          保留的纯表现组件，含从 dev 提升的正式资源
addons/native_battle/src/
  combat_kernel.*                 常驻执行与对外 API
  combat_rules.*                  攻击、命中、防御、已知效果直接实现
  combat_motion.*                 现有运动、目标与紧凑弹体
  combat_presentation.*           现有 native 批量/保留式显示
  amount.*                        统一增长数、成本、计数及批量运算
config_excel/*.xlsx               唯一可编辑内容源
build_content/*.json              生成产物；禁止手改
tools/compile_content.py          唯一编译入口
```

依赖方向：`UI → Session → model + battle_bridge → native`，`model → Catalog`。`SaveStore` 读写 Profile 和必要 native 持久计数；`BattleView` 只读 native 表现接口。model 不引用 UI，不接收整个旧 Game，不访问磁盘。native 不回调 GDScript 处理单次攻击/命中。

这里保留 GDScript 作为低频业务层，是因为研究、建造、装备操作数量小且直接修改更容易；高频战斗仍在 native。没有新增线程调度器或网络式消息系统。唯一异步工作是纯成本报价/磁盘操作等不能阻塞显示的工作，结果回到主线程后重新核价；不得在后台线程写 Profile。

## 2. 状态归属：每个事实只存一次

| 所有者 | 权威字段 | 不再存储的派生/重复数据 |
|---|---|---|
| Profile.progress | 本轮最高关、已清关集合、历史最高关、驻守目标/死亡策略、征服记录、已读教程 | `unlocked`、`grantedUnlocks` 与 UI 解锁列表三套互相修补；解锁由已完成事实和表计算。确有永久授予的奖励存 `permanent_grants`，不存其计算结果 |
| Profile.wallet | 铁、铀、碎片、时间粒子、四材料、核心 | 领域自己的可花费余额；“本次收益”是统计，不能再次入账 |
| Profile.equipment | 舰体；各类别模块的稳定 ID、等级、选用装备、switch_until | `_active` 完整条目复制、临时计划版本和槽位索引身份；活动槽只存索引/ID 引用 |
| Profile.enhancement/research/reactor | 购买等级、排序/选择、各科技工作量、投入配置、能源分配 | 旧宝石库存/插槽、科学家数量/科技点；属性和可购买数量不保存 |
| Profile.crew | 每位船员经验、一个 `Assignment(kind,target,mode)` | 星球 crewId、建筑 crew[]、异空间保留人、银河人数的第二份岗位事实；领域查询同一岗位表 |
| Profile.planets/galaxy | 探索度、建筑工作/启用、征服；银河节点工作、等级、布局 seed | 从工作进度推导的 available/ready 状态、整份冻结 view、pending_online_time 与 native_refit 计划 |
| Profile.hyperspace/drones | 最佳 x1 成绩、挂机 Job、已生成待领奖励、无人机记录、装备 ID/收藏/预设/封存门槛、RNG | 活跃/idle/receipt 三处同一任务内容；库存可用容量、效果聚合另存一份 |
| Journey（运行时，保存小检查点） | 模式、阶段、关/遭遇、距离、驻守参数、返回位置 | `guard_engaged/arrived/index` 等可由阶段与目标推导的独立布尔 |
| native CombatWorld | 双方当前防御、模块损失、武器 CD、飞行物、延迟触发、buff、RNG、战斗时间、攻击/受击历史计数 | `Game.player/enemies/projectiles/cooldowns/jewel_*` 镜像；持久计数也从 native 导出，不在每 tick 两边对齐 |
| UI/表现 | 当前页、滚动、悬停、镜头、粒子、声音、显示寿命 | 会影响扣血/收益的状态。显示节点销毁不会销毁奖励或战斗对象 |

Profile 是保存布局，也是领域的直接存储；领域对象持有该分组引用，不再先写 `_state` 再投影回 profile。native 的持久计数在创建会话时加载、保存时导出；切换遭遇不重置，重铸才按规则重置。Profile 文件中的计数是快照，运行时不作为第二权威。

稳定 ID 分三类：内容 ID（字符串，编译时变紧凑整数）、模块/无人机 ID（存档内持久唯一）、native 临时 Handle(index,generation)。界面不把数组位置当无人机或模块身份；native 槽复用不会让旧飞行物命中新敌人。

## 3. Session 的普通命令流程

公开方法是具体的 `upgrade_module(id,count)`、`assign_crew(id,target)`、`start_challenge(route,level)` 等，不设计动态 command 注册总线。

1. UI 调用时只追加小型命令记录。Session 在下一个逻辑边界按先后处理；暂停时也处理操作命令。
2. 对当前数据检查一次业务条件，计算费用与结果。失败只返回 `reason`；成功先准备本命令涉及的小数据，再在同一同步函数内扣款、改记录、替换战斗配置。
3. 配置来自已经编译合法的 Catalog。`Stats` 只在实际影响战斗时生成新参数；native 已支持全部正式效果，不存在“先改等级再发现要移交旧内核”。配置替换不发 UI 回调，也不 `await`。
4. 最后置 `save_dirty` 和少量页面 dirty 位，返回成功。完成整个逻辑边界之后才发送页面通知；监听者不能在通知期间重入正在执行的命令。

例如升级一个激光模块：核算当前真实费用→确认铁/材料→准备模块新等级与新武器参数→扣费和改等级→native 更新这个模块未来攻击参数→标记装备页/资源条。无需复制钱包、全部星球、整个 Game；已有弹体持有旧攻击快照继续飞。玩家快速连续点两次，第二次自然读第一次后的余额，不需要每个领域维护 proposal revision。

换船/重铸/导入是少数整体操作：先建立新 Profile 或新装配数据并校验一次，再在逻辑边界替换；这不是每次命令的通用候选 Game 流程。UI 预览不是承诺，确认时按当前状态核算。耗时 MAX 报价使用只读输入；到达时若输入已变直接重算，不恢复旧事务游标。

## 4. 时间：一个可完成的逻辑步

保留 1/60 秒基础逻辑步；该值是执行精度，不是 Excel 平衡参数。Session 独占墙钟入口，UI 不能分别驱动科研、战斗、银河。三类时间明确区分：

- 真实在线秒：收入显示窗口、自动保存、性能显示。
- 游戏秒：真实经过秒乘当前粒子加速；用于战斗、研究工作、生产、探索和挂机。x1 战绩累计实际游戏秒，不直接使用屏幕墙钟。
- 表现秒：渲染插值/纯装饰，暂停时按现有体验冻结战场。GPU 曲线不能反馈游戏。

每步顺序：

```text
处理用户命令（步骤前）
→ 前进一步共享游戏时钟与到期经济/工作任务
→ 按明确顺序入账、自动操作和更新静态属性
→ 准备此步几何，native.advance(dt)
→ 消费 native 的领域事件（拾取物、通关/死亡、永久计数变化）
→ Journey 在步末执行一次阶段转移；新阶段从下一逻辑步开始
→ 提交页面 dirty 位、可保存边界
```

行程转移明确量化到逻辑步末（最多一个 1/60 秒步长），命中与恢复仍保留步内时刻；共享工作已消费整个 dt，不能因 native 在中途杀死最后敌人而再给新场景重复消费余量。terminal_at 用于 x1 成绩，不用步末时间虚增成绩。

共享任务同一时刻顺序为：已到期生产/奖励入账→星球/银河工作完成及经验→科技消耗/完成→船员自动升级（装备、强化、反应炉）→重编译属性。并列任务按表 `order` 和稳定 ID。研究会按资源耗尽或完成时刻细分本步，完成后的剩余时间可继续研究。自动升级在配置间隔到期时触发，不能每帧重试 MAX。

这是新实现明确的边界顺序；不声称复刻旧框架每个内部游标。所有事件执行完就结束这一步；不允许正常玩法将其挂在 `shared stage=4 item=7`。非法内容在编译时拒绝，native 构造失败则启动报错，不带着半个会话继续。

粒子支付随实际接受的真实时间片结算。余额只能支持半段加速时，将该帧分成加速段和 1x 段；不丢掉剩余时间。卡顿累积的工作分帧完成，保留尚未消费的时间段及倍率/已付标记，不能以渲染预算截断战斗事件或重复付费。退出保存时把这份短小的 time_credit 一并保存，读回只兑换未执行的游戏时间、不再次收粒子；暂停时保留它。这里只存未处理时间量，不存领域半提交游标。失焦恢复默认速度；暂停不花粒子。

墙钟离线只兑换配置规定的时间粒子（基线 offlineMax=12 小时上限），不在启动时模拟几万场战斗或追发科研/星球工作。手动异空间中断与普通续程见 S1；普通挂机 Job 保存工作量后继续，不将关机时间变成完成次数。

## 5. native API 与内部执行

沿用 `SpaceCombatKernel` 与现有运动/显示组件，改为整个会话常驻。最多一个实际前台战斗，普通主线与手动异空间共享此对象；挂机是计时收益，不能暗中创建第二个战斗实例。

| API | 输入/输出与调用时机 |
|---|---|
| `initialize(rules, persistent_counters, seed)` | 一次加载规则常量、初始计数与 RNG。内容 ABI 不匹配则启动失败 |
| `begin_encounter(encounter, loadout, geometry)` | 敌人属性/武器/编队/奖励引用；进入一个遭遇。角色实例保留 generation |
| `set_loadout(loadout, change_kind)` | 仅属性/装配变化调用；见下述变更规则，无 handoff/export_legacy |
| `advance(dt, geometry)` | 完整消费此逻辑步，按时间排序命中、恢复、延迟效果。记录 terminal_at 与结果；死亡/末遭遇完成后停止本场攻击，余下时间不进入下一场；返回边界事件 |
| `end_encounter(reason)` | 清除遭遇专属发射/效果，保留需越遭遇飞行的已有载体，按模式决定是否整体清场 |
| `take_domain_events()` | 只含死亡掉落规格、遭遇完成/玩家死亡等业务事件；不能丢失或受显示预算影响 |
| `presentation()` | 批量只读角色摘要、active membership、现有轨迹/保留特效与 GPU 数据；没有全世界字典序列化 |
| `persistent_data()` | 保存用计数/RNG；S1 被否决时另有 checkpoint API |

内部仍用当前 active 数组、generation 句柄、紧凑激光和定时小队列；不为每个弹体建 Godot Node。规则按武器类型/效果枚举直接调用 C++ 函数，不每次解析 Excel、字符串分派或跨语言回调。

常规步中事件按 `(到期时间, 稳定序号)` 执行。抵达命中时间前先推进目标的护盾恢复和相关防御计时到该时刻；同一时刻命中顺序由出生顺序稳定决定。攻击创建只记录攻击；载体相交/抵达中心后才调用命中。光束按其有效伤害间隔逐跳，蓄力期没有伤害。一次扣血跨过零的命中拥有死亡奖励，后续命中不能再次杀同一对象。

战斗属性和费用共享 `Stats`/native 数学，但不能把历史攻击次数带来的熟练增幅每次回写 GDScript 重编译。计数和随战斗变化的加成直接在内核计算；`set_loadout` 只更新静态来源。

## 6. 配置更新期间的战斗

- 升级、科技、银河/星球加成：新攻击使用新静态配置；在飞攻击保留出生伤害/暴击/连发上下文。不重置 CD，不补发攻击。CD 变化保留剩余比例，以新周期计算；光束持续使用其攻击快照直到重新锁定，当前外观可立即变色。
- 防御容量变化：每个稳定模块按当前损失比例映射新上限；零容量阶段保留比例，以免临时归零再恢复变成满血。当前记忆缓冲截到新容量，延迟伤害仍按其已承诺量结算。
- 换槽装备：旧载体继续；尚未出生的旧武器排队发射取消，记录在该武器实例的 generation 上；新装备从表定切换冷却结束后启动。并非因切 UI 页重置。
- 换舰：固定模块库保留等级；新舰活动槽由表决定，超出容量的无人机移回仓库，不销毁；未满足新防御配置时拒绝出航。具体载体处理与换槽一致。
- 一场内无人机重建：仅内核标记该机暂时失效和重建加成，不卸下库存装备；静态贡献已编译为每来源的小块，内核重聚合，不回调整份 Game。

上述“光束快照/CD 按比例”是本稿选定的新实现语义，须与整稿一起审阅，不能在实现时默认为已与旧每一处中间行为相同；它们保留升级有效、在飞攻击不篡改的产品意图，无需继承历史对象突变。

## 7. 统一数值，不靠越界移交

`Amount` 为非负增长量：常见值用内联 double 快路径，大值用规范化 `(mantissa, exponent:int64)`，mantissa 在 [1,10)，零有单独表示。C++ POD 值无每次数值堆分配；GDScript 在低频调用中使用数字或 `{m,e_string}` 的桥接表示。普通路径保持现有二进制浮点的有效精度，大数保留同量级精度；不是宣称无限精确整数。

统一实现 add、非负 subtract、multiply、divide、compare、pow、ceil、round、log10、ratio。只有尺寸、时间、概率和有限比率继续用 double。生命、伤害、资源、研究需求/工作量、能源和成本不得在大数路径强转 float。伤害条显示用 `min(current/max,1)` 的安全比值；不能用对数生命差代替扣血。存档写值，不写格式化的“1.2亿”。

材料、等级、运行 ID、攻击/受击历史计数需要精确整数。默认 uint64；JSON 存十进制字符串，内核不经 double 传递。合法配置和等级范围须保证指数 int64 可表达；达到存储上限明确拒绝继续升级，不触发旧结算或悄悄清零。这是技术极限，不新增普通游戏等级上限。

成本保留基线的逐级舍入：`B*(1+g)^(L-1)`，小于 100 时向下十位后加 5，其余按两位有效数舍入；进化费用在配置间隔处增加材料。属性用同一成长，再乘进化系数；护盾保持表定护盾/装甲基础比例。MAX 从本次各资源预算取共同最大可付次数，不能用“末级价格×次数”代替逐级总价。实现 native 的 CostSeries：按几何和先给严格上下界缩小区间，精确计算候选区间逐级舍入成本；缓存完成的前缀块，不在 UI 每帧算。极端长报价放只读工作任务，用户可取消，提交前重核余额；既不冻结游戏也不把未核实近似价拿来扣款。第一版可用正确的 native 顺序求和作为该工具的内部实现，再依据实际耗时优化，不新增日常玩法事务框架。

保留高效路径不等于无条件声称新的 Amount 更快。验收时同一场景比较新旧 native 普通数值路径；如果 Amount 导致回归，优化布局/分支，不能退回 GDScript 或减少命中次数。

## 8. 表现的保留与解耦

正式资源从 `dev/toon_ship` 等位置迁到正式 art 路径（可以先只改资源引用），保留模型、烘焙舰体、flat compositor、炮口、护盾、星球/银河资产、shader、音效。保留 `SpaceCombatPresentation`、`combat_retained_presentation.h`、`gpu_contact_mesh.gd`、retained enemy contacts/missile events/beam foreground、现有批量弹体 packet 等高效内容；逐个换输入，不整段退回主脚本画图。

`FleetGeometry` 根据表与静态舰型/炮口描述计算一套数值姿态，内核和渲染都使用它。实际命中/瞄准点保持固定船体中心；图片边缘只供显示。视口缩放只改世界到屏幕矩阵。炮塔转向、反冲、漂移的纯装饰可在显示中算；若炮口/射线需要同一姿态，直接取这一帧提交的数值结果，不能从 Node2D/骨骼反查后喂回结算。保留基线中心对齐的 ±0.5 表现单位准则。

渲染每帧取一次角色摘要和增量成员变化。紧凑激光不生成兼容 Projectile Dictionary；导弹轨迹用现有 native lease/批量缓冲，纯表现对象可用视觉 ID，不能持有可写 actor。命中事件含出生 serial、位置、方向、类型、暴击及伤害反馈快照，死亡后也足够播放。退场尾迹允许独立寿命，不要求保留死亡敌人的全部游戏字典。

血条/数字可合并展示，伤害结算不能合并省略；关闭战斗显示、隐藏银河页、关闭命中特效不会改变输入、时间、收益或 RNG。GPU 满载可裁减装饰粒子；领域死亡事件不进入装饰队列。没有渲染回调才能推进的 native 逻辑。

## 9. 明确取消的旧结构

| 基线文件/状态 | 目标处理与实际减少 |
|---|---|
| `game.gd` + `presented_battle_game.gd` 的双逻辑继承 | 入口换成 Session；业务迁领域、战斗迁 native、表现迁 View；删继承覆写和 player database 展示改数值 |
| `native_execution_compiler/session/handoff.gd`、`execution_contract.gd` scope | 用一份配置编译和固定 ABI；删低/富 scope、能力探测、准入重复验证、export/commit handoff、旧结算重放 |
| `step_progress.gd`、`blocked_context`、`before_presented`、各领域 stage/item/detail | 逻辑步一定完成；删除中断恢复状态、冻结重试、领域游标和重复扣时保护；只留尚未处理时间段 |
| `commit_effects.gd`、大量 prepare/proposal_current/finish | 主线程具体命令；删除各领域版本复核、重复 freeze/duplicate 和事件嵌套保护框架 |
| `attribute_projection` 输入数组、各贡献 revision、每帧签名比较 | 一份静态 Stats，显式 dirty；保留真正需低频缓存的汇总。战斗动态加成在 native |
| `Game.enemies/player/projectiles` 与 native view 绑定 | 删除 Game 战斗镜像、兼容弹体全量 materialize；表现直接取 typed/native 数据 |
| `battle_slice_runtime/battle_read_model/simulation_geometry_view` 的逐层包装 | FleetGeometry→native/BattleView；去掉逐步 turret duplicate、retained actor 字典查找与显示引用反推存活 |
| `progress_runtime` 整 Game 候选、`product_lifecycle/restart_host` | 新 Profile 单次替换；删除几十字段逐个拷贝、旧 Game 复活及替换通知链 |
| `configuration_snapshot` 热发布、总表拆分/增量发布并存 | 单编译器+单内容包；不做游戏内热改表。静态合法性只在编译入口检查完整规则 |
| `planet/crew/hyperspace` 重复占用状态 | 一个 Assignment；删除跨 owner 的保留/释放/恢复补丁 |
| `galaxy` 地图格与节点双业务进度 | 节点工作权威；地图揭示是可重建表现。保留探索动画与 chunk 缓存，不让格子影响数值 |
| `level_editor/fleet_* /balance_*` 游戏内工具 | 删除入口与实现及专属测试；详见交付文档，不为其新建 API |

删除指最终切换后的代码，不是本次操作。旧运行实现可在 Git 基线查询，不在正式项目保留“暂时备用”第二套。
