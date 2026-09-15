# 升级与解锁

## 2026-09-15 · 装备更换与换舰配置

- **CONFIRMED · 用户本次指令**：常规装备页不能更换已装装备，只能给空槽新增；换舰时在“战舰”页签为目标舰选择装备，确认后才提交。换舰返还当前槽位全部升级资源，目标装备从1级开始。
- `equip_slot` 仅接受空槽，`valid_loadout` 校验目标舰槽位、解锁状态及同种装备上限；`switch_ship` 接收已确认的目标配置后才重置关卡。旧存档中的卸下接口保留兼容，不再由常规装备页提供入口。

## 2026-09-15 · 充能

- **CONFIRMED · 来源**：`config_excel/charge.xlsx` 的 charge!A1:K6，功能按 B4:B6（func），显示按 C4:C6（des）；用户确认三项可同时启动、离线继续消耗资源、同种资源不足平均分配并保留当前进度，熔炼器只提升击杀掉落的铁。
- 通关 unlock 指定关卡后可启动，初始0级。para_1 为资源ID、para_2 为基础每秒消耗、para_3 为加成、para_4 为单次充能秒数、para_5/para_6 为升级所需次数基数/成长。**CONFIRMED · 2026-09-15用户补充**：升级要求次数为 `round(para_5 × para_6^当前等级)`，完整公式计算后四舍五入为整数，不对参数提前取整。每完成该次数升一级，本级次数重新累计，超出时间进入后续充能；可手动暂停/继续。结算、离线跨级边界及UI进度共用charge_required。
- **CONFIRMED · 2026-09-15用户补充及charge!K3:K6**：para_7 为升级消耗增长参数，当前每秒消耗为 `round(para_2 × (1+para_7)^当前等级)`，完整公式计算后四舍五入（1.05→1、1.5→2），替代先前向上取整。运行扣费与卡片显示共用charge_resource_rate；在线长帧/离线跨级按升级边界分段，升级后的剩余时间立即使用新等级费率。已扣credit仍是资源量，按新费率换算可推进时间。旧配置缺para_7时兼容为0，显式值须为有限非负数；des支持para7。若费率舍入为0则不扣费，升级到正费率后正常检查余额。
- 攻击充能将所有玩家武器伤害乘 `(1+para_3)^等级`，防御充能将生命/护盾上限乘该倍率，复用现有 stat/equipment_stat 并在既有高科技效果后向上取整；敌舰及已发射弹体不变。防御升级沿用高科技容量行为，不补当前生命/护盾。
- 熔炼器充能仅在敌舰死亡产生资源ID1掉落时乘倍率，与关卡倍率一起计算后向上取整；不影响自动生成资源、超时空炼铁炉或拾取后的二次收入统计。自动拾取损耗仍独立计算。
- 在线使用模拟时间，跟随暂停/倍速；离线复用 offlineMax（小时）上限，按现实1倍时间推进。先按既有流程入账离线资源，再计算可供充能的余额。同种资源不足时按活动项均分整数，某项所需不足其份额时余量继续分给其他项。**CONFIRMED · 用户补充**：资源余额不保留小数，除不尽的余数按启动先后分配，最后1个资源给最早启动项。无资源时不清空进度、不关闭活动项，后续来资源自动继续；手动重新启动重新进入顺序。
- `profile.charge[name]` 保存 level/count/elapsed/active/started/credit，充能资源余额每次扣除后立即存档，其他进度复用5秒周期及现有存档时机；旧档缺字段从0级未启动状态开始。**DERIVED · 整数扣费与连续时间的衔接**：按需扣整数资源，已扣但尚未随时间用完的不足1单位充能量记为 credit，后续帧先消耗它，避免每帧取整重复扣费；它不是资源余额。单次进度、本级次数、启动顺序、暂停状态和已扣充能余量在重启后保留。
- 追踪：import_workbook/config_workbooks → game.charge_*、advance_charge、equipment_stat、hit_enemy → main.build_charge_tab；专项见 VALIDATION“充能页签”。

## 2026-09-15 · 科学家与高科技

- **DERIVED · 大数性能（2026-09-15用户授权降低精度）**：任一活动研究的本次可用点数达到 `1e20` 时，本次所有活动研究改用线性费用等差求和及二次方程批量结算，忽略逐级round误差，每项只发一次升级事件；炼铁炉用结算末等级估算该时间段产出。低于阈值保留原逐级结算。等级在 `9e18` 保留整数安全余量，超额研究点保留；无穷点预算按 `1e308` 处理。公共显示对 `1e20` 以上用三位有效数字科学计数法，非有限值直接显示，避免格式化循环及整数转换溢出。

- 2026-09-15 用户追加批量操作：生成×10按后续十人的逐项四舍五入费用累加，必须完整负担十人，一次扣费；MAX逐人生成至资源不足。分配+10最多投入十名空闲科学家，MAX投入全部空闲；平均分配将全部科学家重新均分到已解锁卡片，余数按当前卡槽顺序分配，研究点不变。

- **CONFIRMED · 来源**：本次用户重做指令、`config_excel/config.xlsx!A11:C13`、`config_excel/hightech.xlsx!A1:H6`。科学家生成费用按 scientistCost 的“倍率,资源ID|基础费用,...”解析，支持任意多资源；第n人每项费用为 round(基础费用×倍率^(n−1))，整套资源足够才一次扣除并生成。首个高科技解锁后开放生成。
- 可将空闲科学家逐个分配/撤回任意已解锁高科技，同时研究不限项目数。单人每模拟秒生成 techPointGet 点；多人每秒生成 round((techPointGet×人数)^hightechLimit) 点；0人不产点。hightechLimit 不再代表并发名额。按已经舍入的每秒速率累计小数秒，不逐帧舍入。
- 下一等级需要 round(tpCostBase×(1+tpCostMutiple×当前等级)) 研究点，timeCost 相关列废弃。达到要求自动升级，超出点数投入下一级；撤回保留累计点数。在线跟随暂停/倍速，离线沿用 offlineMax 小时上限、现实1倍推进；按升级边界分段，炼铁炉只在首次升到1级后开始生成。
- 所有高科技初始0级，无效果。**用户确认迁移**：旧高科技直接废弃；加载缺 hightechVersion=2 的旧档时不恢复旧等级、研发计时、科学家/点数及炼铁炉周期/铁块，其他进度保留。新版保存 scientists、scientistAssignments、techPoints、hightechLevels 与 hightechVersion=2，后续读档正常恢复；旧 hightechResearch 不再写入。来源明确的历史资源样本和收入峰值继续供收入统计使用。
- 研究提高上限时不补当前生命/护盾，其他效果沿用以下规则。
- 超时空炼铁炉：按 para1 周期生成铁块，数量为 ceil(近一分钟非炼铁炉铁入账量的历史峰值 × para2 × 等级)。**CONFIRMED · 2026-09-14用户修正**：60秒基数扣除炼铁炉自身收益，替代此前包含自身的口径；仍按现实时间窗口与实际入账（自动拾取损耗后）计算，不用UI两位小数值。collect 记录 origin=drop/furnace，生成与 description 的“不含自身”共用筛选及峰值；顶部收入及离线资源速率仍包含全部实际拾取。
- **CONFIRMED · 2026-09-14用户修正**：炼铁炉使用历史最大值，不随实时收入回落。`profile.furnaceIncomePeak` 保存一分钟非自身铁收入峰值，每次拾取立即更新，即使页签未打开也能记录；描述与生成共用峰值，等级继续参与乘算。旧档缺峰值时从所存窗口内可信来源样本建立初值，无法恢复更早未记录的历史；新档从0开始。
- 来源标记随一分钟样本保存。**CURRENT · 旧档兼容**：旧样本没有来源，不猜测其类型；保留总收入显示，但不参与炼铁炉基数，最多60秒自然过期。新入账立即带来源正常计算。鼠标左键点击全额领取；不接受悬停、自动拾取及离开结算，10秒后消失。周期与铁块寿命在线跟随模拟时间，离线同研发上限。
- **CONFIRMED · 2026-09-14新设计，来源 config_excel/hightech.xlsx!B5:C5**：正电子聚焦装置将所有玩家武器伤害改为 ceil(装备原伤害 × (1 + para1)^等级)，包括能量与物理武器；复用 equipment_stat/stat 与现有发射流程，敌方伤害不变。替代旧线性、仅能量规则。
- **CONFIRMED · 2026-09-14新设计，来源 config_excel/hightech.xlsx!B6:C6**：简并态装甲同时将生命和护盾上限改为 ceil(装备原容量 × (1 + para1)^等级)；研发完成不补当前生命/护盾，现有恢复流程使用新上限。替代旧线性、仅生命规则。总表仍为旧设计，不回写或用总表覆盖本次分表；来源边界见 U-001。
- 追踪：import_workbook.convert_sheet/validate_projection → game.hightech_*、generate_scientist、assign_scientist、advance_hightech、advance_furnace → main.build_hightech_tab；专项及图形证据见 [VALIDATION](../VALIDATION.md)。

## CONFIRMED · 原表

- config!A4:C4：起始装备列表，默认 1 级。equipment!G2、总览!A28：通关对应关卡解锁装备；空白语义冲突见 U-004。
- equipment!H1:K3、总览!A29:C30：res_x/cost_x 一一对应，成本表示**升到该行等级**。具体成长数列仍在 Excel，JSON 保留已计算等级行。

## CONFIRMED · 当前代码

`fresh_profile()` 为当前舰船槽位创建装备实例，并保留 `levels` 作为旧存档/测试兼容别名。`rebuild_unlocks()` 由 cleared 重建 highestLevel 与 unlocked；舰船按 ship.unlock 独立解锁。空 unlock 由 database.unlock_level 解释为 0，从而默认开放。通关列表不要求连续，读取限制见 U-008。
`upgrade_cost()` 读当前等级+1 的行并动态扫描 res_ 前缀，最终成本向上取整（来源：2026-09-13 用户资源取整指令，见 economy）；`can_upgrade()` 要求已解锁、未到 defaults.maxEquipmentLevel、每种资源足够；`upgrade()` 使用同一整数成本扣费、升级并保存。
- **CONFIRMED · 2026-09-14用户要求**：所有 equipment 额外提供10连升级和MAX升级。10连必须能连续升10级，按目标各等级成本求和后一次扣费并一次变更等级；MAX按当前资源逐级判断，升到可负担的最高等级或配置上限。所有批量升级沿用单次升级的容量/生命保损规则。
升级立即影响后续出手；已发射弹体仍使用创建时伤害。武器升级不恢复生命也不重置冷却。装甲/护盾仅补新增容量；RETREAT 中不补，结束后统一恢复。该保损行为为实现事实，见 U-005。
首次通关收集新增装备进入 pending_unlocks，弹窗确认后清空；重复通关不会再次通知。舰船选择和槽位装备在主界面完成；每个槽位单独升级，见 [ui](ui.md)。

追踪：equipment/config → JSON → game.fresh_profile/rebuild_unlocks/upgrade_cost/can_upgrade/upgrade/clear_level → test_game Insufficient resources、Level cap、upgrade、unlock popup。装备等级与上节高科技等级独立；其他未设计成长系统见 U-009。
