# 强化等级、快照与分支

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 强化解锁与首级门槛 | `test_enhancement_unlock_gate.gd --headless` 验证锁定消费者、0/1/10/20主效果、原分支门槛、迁移/永久加成及缓存；`test_shared_enhancement_ranks.gd` 验证排序、实际攻击与详情；源表校验用 `test_enhance_config.py`。 |
| 攻击快照 / 连发继承 / 光束周期 | `test_main_attack_snapshot.gd --headless` 检查批次计数、冻结属性、派生继承与取消、批次共享连锁；配合 `test_enhancement_branch_attacks.gd`，`test_chain_projectiles.gd` 检查跳弹到达结算、失锁/清场及光束固定连线。旧 `test_attack_effect_reuse.gd` 的逐弹 RNG 等价断言不适用于批次快照规则。 |
| 全局装备强化 | `test_shared_enhancement_ranks.gd` 检查共享0/9/10/19/20与分支位置边界、重排停用/恢复、保存和六种显式详情（图形模式验证点击）；`test_enhancements.gd` 检查共享顺序/共享强化门槛/全局事件/费用/MAX/分支；`test_enhancement_branches.gd` 检查36选项、状态/组合/实际恢复/共同抗性；`test_enhancement_branch_attacks.gd` 检查四武器、规范攻击计数、单次连锁与有界连发；`test_deferred_enhancements.gd` 检查延迟队列、全局清除和时序；`test_neutral_memory_protection.gd` 检查无抗性临时保护、原始伤害溢出和延迟交互；`test_enhancement_save.gd` 检查旧档清理/余额/新档/重铸；`test_enhancement_furnace.gd` 检查碎片生产不递归；`test_percentage_expected_damage.gd` 检查整数/紧凑百分比、模块暴击期望、计时增益仅战斗生效且不触发面板刷新；`test_enhance_config.py` 校验唯一配置表和非法输入；`test_enhancement_cost.gd --headless` 检查指数单价、几何批量/MAX、赠送级免计费和超大余额。旧宝石背包/合成/镶嵌专项已被替代，不作新系统验收入口。 |
