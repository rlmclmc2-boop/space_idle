# 06 经济、反应炉、AI科研和船员

## ECO01 钱包、掉落与领取

Economy唯一持有铁/铀/碎片/粒子/异空间四材料/核心余额；Hyperspace持有物品但不复制材料钱包。金额统一大数，预览不扣款。`can_pay(cost)`、`pay(cost)`、`credit(receipt)`只接受合法ID/非负金额；上层完成全部业务条件后同步调用。支出从不进入收入统计。

击杀时每个掉落项按chance抽一次，创建唯一dropId；铁base=ceil(drop.amount×resRatio×smelting×敌方铁加成)，其他资源无smelting；铁/铀再乘已激活星球refinery后ceil得到显示掉落amount。记录production_base为精炼前金额。手动拾取比例1，自动比例1−autoCollectReduce，各自ceil，再乘科研iron_income/uranium_income后ceil，实际到账与显示收款一致。掉落发生在爆炸位置，显示位置不能反向改变金额。拾取路径只能在战场有效区域触发，暂停/弹窗遮挡按UI输入规则拒绝。

普通资源按明确autoCollectDelay到期自动收取；碎片当前2游戏秒；顶端autoGenRes解析为interval,resource,amount,speed，每周期出生base=ceil(amount×resRatio)，资源采集挂载再放大，下降到玩家位置自动收取。这些代码现存默认常量必须进入Excel时间/规则页，不能留测试内置默认。掉落重复领取、失效ID、非法资源拒绝；失败不删除待领取物。普通掉落不存普通战场现场；更换会话如何处理未收掉落用09明确矩阵，不以读档补发。

碎片击杀按config.jewelDrop概率及敌方有效rolls；只有共享强化解锁才产生。直接掉落额=amount×gem_refiner×船员gem_bonus×反应炉condensation×银河gem_fragment，再乘jewelRatio并按0.01量化，最后科研fragment_income。furnace来源（若D10保留）不再吃直接掉落倍率，仅其明定生产/科研贡献；费用仍按强化成本公式。不得恢复宝石对象或插槽。

## ECO02 收入窗口与生产

记录 `{resource,credited,productionBase,origin,wallTime,gameTime}`；仅保存当前窗口需要的记录，窗口边界为(now−60,now]。共用记录不是精确副账，窗口求和用同一大数并允许该精度范围外小量被舍弃。

| 查询 | 时钟/金额/来源 | 消费者 |
|---|---|---|
| HUD收入 | 60真实秒、实际到账、全部合法收入 | 资源条，不扣支出 |
| 科研自动投入 | 60游戏秒、实际到账、含合法收入 | 除60得平均，乘用户比例 |
| 联合一体化峰值 | 60真实秒、实际到账、origin=drop | 铁/铀/碎片各自历史最高/60 |
| 银河生产基数 | 60游戏秒、productionBase、origin=drop | 不含银河/熔炉自身，避免自反馈 |
| 旧熔炉峰值 | 资料为非自身收入历史峰值、游戏时间 | D10确认是否仍是有效玩法 |

ECO03熔炉：资料写铁/碎片熔炉按自己的非自身峰值生产、生成带计时环的橙铁/紫核心，10秒后自动领取有损耗，无战场名字计数；但当前正式共享推进没有找到生成熔炉的调用，仅收款分支/旧存档字段残留。不能把它当现行生产直接重建，也不能无说明删除。D10决定后，若保留，源Excel明确interval、产量公式/有效等级、寿命、自动损耗与存档字段；若废弃删业务参数、残留入口和状态，保留已需要的纯表现。此项验收在裁决前标为blocked，非通过。

## REA01 反应炉

Reactor持有level和按reactorModules的整数分配。总能量=reactorEnergyBase×reactorEnergyGrowth^(L−1)×船员×银河charge_max×无人机extra_storage；容量=floor(总能量)。所有分配非负整数且总和<=容量；免费充能不占分配。升级一级铀费用=ceil(reactorUpgradeBase×reactorUpgradeGrowth^(L−1))，资源ID取reactorUraniumId；批量计算复用单级取整口径，MAX不溢出。

模块有效分配=manual+capacity×free_ratio；效果倍率=1+assigned^reactorBoostExponent/reactorPercentScale。weapons/defence/smelting/condensation各用自己的分配；免费比率可>1，逻辑不裁到100%，UI显示圈最多满而数值说明真实值。分配减少/容量下降按固定模块顺序收敛，先计划最终合法分配再安装，不负分配。

接口upgrade/set_allocation/equalize；非法输入、资源不足、超容量拒绝。自动岗位每周期先尝试+1，再均分，即使买不起也可均分；完全无变化不发通知。保存等级/分配，重铸回初始级/初始分配，读档验证容量后再装配。滑杆、数值输入、预览、船员标识局部更新。A-REA。

## RES01 AI科技树与完整公式

八个现行科技：singularity、weapon_accuracy、equipment_reinforcement、resource_refining、fragment_condensation、equipment_finishing、uranium_extraction、unification；显示别名由UI映射，存档使用稳定ID。

当前L级升下一级的工作量W=base_seconds×growth^L。前置针对目标k=L+1，requirements固定值或10*k+1；factory/legacy_unlock/额外enhancement门槛均满足才可选择。只研究一个项目，可暂停/切换，保留各项目工作进度；没有科学家购买和techPoints。

AI数=1+singularity等级；基础速度=(AI数+9)/10×(1+distributed_algorithm挂载)×船员研究倍率。铁和铀投入各为每游戏秒金额I；I=0不付款且倍率1，I>0倍率=1+log10(I)/4，两种相乘。只有实际支付覆盖的时段享受该投入倍率；取最近资金耗尽/研究完成边界分段，耗尽后该资源倍率变1，不能先跑完整高倍率再扣失败。完成工作后该科技+1、清该次进度、置完成未读、停止当前研究；船员可按下条继续。

科技普通收益=按effect匹配的factor^level相乘。unification为0级时倍率1，否则level×Π资源max(1,1+log10(历史峰值)/5)，只对正峰值项计算；再与对应普通武器/耐久科技相乘。科研输入、支出、进度、峰值均大数；显示进度条只取有界比率。对数基数核实为GrowthNumber.logarithm的十进制语义，不得误用自然对数。

自动研究船员：只在完成后选择合格且remaining_work/current_speed最短项目，平分按Excel顺序；不抢占、不自动恢复手动暂停、不购买科学家。自动投入铁/铀各默认比例0.01、下限0.001，应迁入Excel；I=max(1,floor(过去60游戏秒到账/60×ratio))。派遣/比例变更即时重算，之后每60游戏秒刷新；召回停止自动覆盖。禁止UI输入绕过“船员正在接管投入”的限制。

保存levels/work/selected/input/ratios/refreshElapsed/peak/unread；重铸建议清科研及峰值（D09）；普通死亡不清。配置变更使当前研究不合法时停止并报告，不删除已付工作或自动转研究。UI保留工厂机器、全局AI、研究卡、进度、前置提示、投入框和完成徽标；纯艺术层复用，操作调用新Research。A-RES。

## CREW01 身份、成长、岗位

crewId唯一身份，姓名/描述/图标来自Excel。当前六名解锁由unlock.xlsx决定；第一名之前隐藏入口，只预告下一名轮廓/阈值，不提前显示收益。crew_level功能未开时无等级UI/XP/等级收益，初始0级；下一经验=max(1,round(base_exp×exp_multiplier^L))，扣需求留余数。星球探索XP按08，重铸保留等级/XP和lifetimeMax贡献；已解锁共享经验效果使所有已解锁且等级功能开启者各获完整XP一次，探索者不双领，锁定者不补发。

岗位效果：装备×(1+equip_bonus)^L；研究×(1+tech_speed×L)；直接碎片×(1+gem_bonus×L)；反应炉×(1+charge_bonus×L)。异空间效率=(K+L)/K，耗时best/efficiency不加下限；幸运=每级系数×L。未解锁/空闲/非法目标贡献中性。等级不修改岗位周期。

一人同一时刻只能一种岗位/探索/建筑职责；同岗位目标最多人数按表。Crew是占用权威，目标只引用crewId；探索者不能暗中兼职。派遣前按旧岗位结清已经接受的在线时间，再切换；召回与更换重置自动购买任务计时，修改1/10/MAX不重置周期。周期用游戏时间，暂停冻结、离线不追补，大步遗漏周期按既有岗位“至多一次尝试”规则，不积攒离线采购队列。

| 当前岗位业务 | 执行契约 | UI/失败 |
|---|---|---|
| equipment_upgrade | 武器再防御、只启用模块，按保存1/10/MAX模式调用同一升级；不足跳过该模块 | 显示模式；不自动解锁装备 |
| hightech_scientists / AUTO_RESEARCH | RES01完成后续研和自动投入 | 保留稳定身份但显示AI科研，不出现科学家 |
| jewel_auto / AUTO_COMBINE历史名 | 每配置周期调用共享强化+1 | 无旧合成/镶嵌界面 |
| reactor_upgrade | +1尝试后均分 | 无钱不假报升级成功 |
| 被动/星球/银河/异空间 | 显式注册目标与效果；目标独占/容量校验 | 占用目标禁选，召回入口正确 |

crewEquipment/equipmentSlotCount仅预留，不创建装备系统。保存动态身份/级XP/岗位/模式，不复制名字与基础参数；无效引用读档拒绝/报告，不静默安排其他岗位。UI左身份右XP/效果/派遣，空闲无冗余效果，切页保留草稿与滚动。A-CREW。
