# 长期决策

这里只记录本次用户明确要求的知识管理决定；没有把历史代码选择包装成已获批准的游戏设计。

## D-001

Decision: 仓库文件为共享记忆；AGENTS 导航、STATUS 交接、模块拥有规则解释、TODO 集中保存冲突。

Reason: 本次用户要求低 Token、跨 AI/跨平台接手，禁止依赖聊天与隐式记忆。

Impact: 默认按任务最小读取；One fact → One source；数值表不转成大篇Markdown；完成工作更新对应文件。

## D-002

Decision: 保留当前 Godot 目录与实现，沿用 Excel → 现有 JSON → GDScript；此次不创建 src/assets 占位、不改玩法、不删除遗留文件。

Reason: 用户要求 Preserve → Reuse → Modify → Create → Rewrite，优先现有设计和真实架构。

Impact: 建议架构单列 PROPOSED；代码事实和原表事实分开；冲突必须通过 TODO 跟踪，不能自动选择一方。此决定不代表批准所有现有游戏规则。
