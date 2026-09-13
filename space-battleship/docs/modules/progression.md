# 升级与解锁

## CONFIRMED · 原表

- config!A4:C4：起始装备列表，默认 1 级。equipment!G2、总览!A28：通关对应关卡解锁装备；空白语义冲突见 U-004。
- equipment!H1:K3、总览!A29:C30：res_x/cost_x 一一对应，成本表示**升到该行等级**。具体成长数列仍在 Excel，JSON 保留已计算等级行。

## CONFIRMED · 当前代码

`fresh_profile()` 为五类玩家装备建立等级。`rebuild_unlocks()` 由 cleared 重建 highestLevel 与 unlocked；空 unlock 由 database.unlock_level 解释为 0，从而默认开放。通关列表不要求连续，读取限制见 U-008。
`upgrade_cost()` 读当前等级+1 的行并动态扫描 res_ 前缀，最终成本向上取整（来源：2026-09-13 用户资源取整指令，见 economy）；`can_upgrade()` 要求已解锁、未到 defaults.maxEquipmentLevel、每种资源足够；`upgrade()` 使用同一整数成本扣费、升级并保存。
升级立即影响后续出手；已发射弹体仍使用创建时伤害。武器升级不恢复生命也不重置冷却。装甲/护盾仅补新增容量；RETREAT 中不补，结束后统一恢复。该保损行为为实现事实，见 U-005。
首次通关收集新增装备进入 pending_unlocks，弹窗确认后清空；重复通关不会再次通知。没有独立装备管理界面，见 [ui](ui.md)。

追踪：equipment/config → JSON → game.fresh_profile/rebuild_unlocks/upgrade_cost/can_upgrade/upgrade/clear_level → test_game Insufficient resources、Level cap、upgrade、unlock popup。成长范围为装备等级，不等于舰船品质、科技或角色经验（U-009）。
