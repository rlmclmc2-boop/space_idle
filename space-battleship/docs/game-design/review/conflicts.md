# 当前规则问题

[唯一入口](../README.md)。以下保留未决的双方来源与影响。

## C1 无人机舰型容量（已裁定）

现行容量与字段归属见[03§1](../03-progression.md#1-舰体槽位与升级)。

## C4 parent身份与保存水位（待裁定）

- 当前规范[02§7](../02-combat.md#7-衍生攻击和传说连接)：“派生攻击带父AttackId与类型。”[06§5](../06-data.md#5-新存档格式与生命周期)保存`next_ids:{encounter,actor,attack,emitter,drop}`。
- 当前main及各活跃分支共享的native核：`Attack`没有独立AttackId/parent；`next_ids.attack`保存flight_serial；actor水位由Campaign等宿主所有者保存，并非该native字典。generation、来源身份、有限派生权限与反馈一次取走仍存在，但不等价于规范所写的身份模型。
- 直接父身份、完整祖先历史、触发许可和保存水位是四件不同的事。最小必要表示与持久化边界尚未裁定；不自动增加全父链，也不以旧记录称已豁免。影响派生追溯、ID语义及checkpoint观察口径。待用户明确：需要可查询/可保存的直接父攻击身份，还是接受现有来源身份与载体水位并修正文档？不由本次自行豁免。

## 首槽换型导致双零（待裁定）

[03§1](../03-progression.md#1-舰体槽位与升级)允许首防御槽在合法类型间更换、禁止卸空；有盾无甲仍可出击。**换型本身使当前盾甲同时为0时是否立即判死**尚未决定。当前代码`GameSession.publish_equipment_refit → Campaign.retreat_if_dead`已经在换型提交后双零时立即撤退，未走native受击后的重建入口。待用户选择此边界：换型双零立即撤退，还是沿受击死亡链先尝试重建。受击后双零/重建失败才终止死亡的既定规则不因此撤回；也可另定换型准入规则，本次不代选。

<a id="d9"></a>
## D9 配置与保存

直接读取配置及保存独立性见[05](../05-architecture.md)和[06§4–5](../06-data.md#4-运行配置直接读取)。

<a id="d10"></a>
## D10 反应炉交互

直接分配/均分与数量循环见[M3](../art/modules/reactor.md)，接纳和预览见[反应炉接口](../contracts/reactor.md)。

<a id="d11"></a>
## D11 星球设施

环带/设施整体及可按需要制作变体见[M7](../art/modules/planet.md)。
