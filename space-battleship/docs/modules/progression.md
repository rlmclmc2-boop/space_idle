# 升级与解锁

## 2026-09-14 · 高科技

- **CONFIRMED · 来源**：`../太空战舰.xlsx` hightech!A1:H6（与 config_excel/hightech.xlsx 核对一致），config!A9:C10；用户补充：从0级研发、无上限；在线跟随暂停/倍速，离线按现实时间1倍推进，离线上限读取 offlineMax（小时）。
- `hightech[name]` 保留 des（效果规则）、description（界面描述）、timeCostBase、timeCostMutiple、unlock、para1/para2；通关 unlock 指定关卡后可以研发。**DERIVED**：按 hightech!E2 的线性示例，下一等级耗时为 round(timeCostBase × (1 + timeCostMutiple × 当前等级)) 秒，不复利；只消耗时间，表中没有资源成本列。
- **CONFIRMED · 2026-09-14最新用户要求**：研发完成自动开始下一级，持续到玩家切换；切换保留原项本级剩余时间，切回继续，暂停项不随在线/离线时间推进。profile.hightechResearch 的每项同时保存 duration、remaining、active；旧档已有研发记录缺 active 时按活动项加载。在线与离线都按完成边界逐级推进，剩余时间进入下一等级。
- 同时活动数仍读取 config.hightechLimit；当前单名额点击另一项直接切换。若未来配置允许多个名额，满额切换由界面选择暂停哪一项，其他活动项不变；重复点击活动项不重置进度。等级、活动/暂停进度、炼铁周期及尚存铁块复用现有存档；旧档缺字段从0级初始化。在线每5秒及现有保存时机记录进度，离线重开只恢复未过期铁块。
- 超时空炼铁炉：按 para1 周期生成铁块，数量为 ceil(近一分钟非炼铁炉铁入账量 × para2 × 等级)。**CONFIRMED · 2026-09-14用户修正**：60秒基数扣除炼铁炉自身收益，替代此前包含自身的口径；仍按现实时间窗口与实际入账（自动拾取损耗后）计算，不用UI两位小数值。collect 记录 origin=drop/furnace，生成与 description 的“不含自身”共用筛选；顶部收入及离线资源速率仍包含全部实际拾取。
- 来源标记随一分钟样本保存。**CURRENT · 旧档兼容**：旧样本没有来源，不猜测其类型；保留总收入显示，但不参与炼铁炉基数，最多60秒自然过期。新入账立即带来源正常计算。鼠标左键点击全额领取；不接受悬停、自动拾取及离开结算，10秒后消失。周期与铁块寿命在线跟随模拟时间，离线同研发上限。
- 正电子聚焦装置：玩家所有 dmgtype=1 的能量武器伤害为 ceil(装备原伤害 × (1 + para1 × 等级))，复用 stat 与现有发射流程，物理武器及敌方伤害不变。
- 简并态装甲：**CONFIRMED · 用户澄清**“最大值，不变当前容量”优先于 hightech!B6 的“当前值”措辞；装甲上限为 ceil(装备原容量 × (1 + para1 × 等级))，研发完成不增加剩余装甲，后续原有恢复流程使用新上限。
- 追踪：import_workbook.convert_sheet/validate_projection → game.hightech_*、research、advance_hightech、advance_furnace → main.build_hightech_tab；专项及图形证据见 [VALIDATION](../VALIDATION.md)。

## CONFIRMED · 原表

- config!A4:C4：起始装备列表，默认 1 级。equipment!G2、总览!A28：通关对应关卡解锁装备；空白语义冲突见 U-004。
- equipment!H1:K3、总览!A29:C30：res_x/cost_x 一一对应，成本表示**升到该行等级**。具体成长数列仍在 Excel，JSON 保留已计算等级行。

## CONFIRMED · 当前代码

`fresh_profile()` 为五类玩家装备建立等级。`rebuild_unlocks()` 由 cleared 重建 highestLevel 与 unlocked；空 unlock 由 database.unlock_level 解释为 0，从而默认开放。通关列表不要求连续，读取限制见 U-008。
`upgrade_cost()` 读当前等级+1 的行并动态扫描 res_ 前缀，最终成本向上取整（来源：2026-09-13 用户资源取整指令，见 economy）；`can_upgrade()` 要求已解锁、未到 defaults.maxEquipmentLevel、每种资源足够；`upgrade()` 使用同一整数成本扣费、升级并保存。
升级立即影响后续出手；已发射弹体仍使用创建时伤害。武器升级不恢复生命也不重置冷却。装甲/护盾仅补新增容量；RETREAT 中不补，结束后统一恢复。该保损行为为实现事实，见 U-005。
首次通关收集新增装备进入 pending_unlocks，弹窗确认后清空；重复通关不会再次通知。没有独立装备管理界面，见 [ui](ui.md)。

追踪：equipment/config → JSON → game.fresh_profile/rebuild_unlocks/upgrade_cost/can_upgrade/upgrade/clear_level → test_game Insufficient resources、Level cap、upgrade、unlock popup。装备等级与上节高科技等级独立；其他未设计成长系统见 U-009。
