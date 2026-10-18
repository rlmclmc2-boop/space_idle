# 护盾、恢复缓冲与延迟伤害

| 修改范围 / 目的 | 按需入口 |
|---|---|
| 护盾先扣 / 延迟伤害分层 | `test_shield_first.gd --headless` 检查实际扣款先盾后生命、恢复/移除护盾、溢出与零生命死亡；队列与临时防护用 `test_deferred_enhancements.gd`、`test_neutral_memory_protection.gd`。 |
| 恢复缓冲成员校验 | `test_memory_buffer_membership.gd --headless` 对照原始路径，覆盖缓存开关、共享强化边界、记忆顺序、模块归属及容量裁剪。 |
