# AI 科技树功能实现

- 基准：`52a87c0e8db7e0fd5a9e4c01882a60515411bdca`；独立分支 `feat/ai-tech-tree-20261017`。
- 规格：仅 `docs/ai-tech-tree-20261017` 的 `5e4fa8a5a9a7051799594d52eec85bece0bc1b4b` 所含 `docs/tasks/AI_TECH_TREE_20261017.md`。
- 范围：科技数据表、单项研发与资源投入、状态存储、铁/铀/碎片与装备收益、接线和最小受影响测试。
- 禁止：改关卡/其他系统平衡、碰个人存档或 D:/放置、与美术方同时编辑新页面、并入 main。
- 精确定位：`scripts/game.gd` 的 `fresh_profile/load_hightech/advance_hightech/equipment_stat/collect/settle_jewel_fragments`，`scripts/database.gd:_init`，`scripts/main.gd:build_hightech_tab/on_game_event`。
- 已知边界：收入平均值可能 `0<R<1`；公式原样保留。实际 GUI 验证需父线程分配串行窗口。
- 下一步：完成运行时规则、停用旧操作、接入美术页面，选测新规则与实际页面。
