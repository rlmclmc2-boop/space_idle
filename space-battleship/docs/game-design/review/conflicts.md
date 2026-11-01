# 当前规则问题

[唯一入口](../README.md)。以下保留未决的双方来源与影响。

## C4 parent身份与保存水位（待裁定）

- 当前规范[02§7](../02-combat.md#7-衍生攻击和传说连接)：“派生攻击带父AttackId与类型。”[06§5](../06-data.md#5-新存档格式与生命周期)保存`next_ids:{encounter,actor,attack,emitter,drop}`。
- 当前main及各活跃分支共享的native核：`Attack`没有独立AttackId/parent；`next_ids.attack`保存flight_serial；actor水位由Campaign等宿主所有者保存，并非该native字典。generation、来源身份、有限派生权限与反馈一次取走仍存在，但不等价于规范所写的身份模型。
- 直接父身份、完整祖先历史、触发许可和保存水位是四件不同的事。最小必要表示与持久化边界尚未裁定。影响派生追溯、ID语义及checkpoint观察口径。待用户明确：需要可查询/可保存的直接父攻击身份，还是接受现有来源身份与载体水位并修正文档？

## 首槽换型导致双零（待裁定）

[03§1](../03-progression.md#1-舰体槽位与升级)允许首防御槽在合法类型间更换、禁止卸空；有盾无甲仍可出击。**换型本身使当前盾甲同时为0时是否立即判死**尚未决定。当前代码`GameSession.publish_equipment_refit → Campaign.retreat_if_dead`已经在换型提交后双零时立即撤退，未走native受击后的重建入口。待用户选择此边界：换型双零立即撤退，还是沿受击死亡链先尝试重建。受击死亡链仍按02执行；另一可选边界是由换型准入限制该操作。
