# AI 唯一入口

太空战舰是 Godot/GDScript 横版放置自动战斗游戏：推进、战斗、收集资源并成长。

## 读取协议

- L0：本文件 → [STATUS](docs/STATUS.md)。默认只读这两份。
- L1：规则含义选 [PROJECT](docs/PROJECT.md)；代码/数据/测试定位选 [ARCHITECTURE](docs/ARCHITECTURE.md)；改变既有结构前选 [DECISIONS](docs/DECISIONS.md)。按任务选择，不默认全读。
- L2：搜索目标符号，只读最少源码、直接依赖与对应专项测试。
- 标准流程：Search → Minimum Read → Change → Verify → Handoff。
- 禁止默认全仓扫描、读取全部文档、整份game_data.json或旧综合测试来理解单个规则。排除缓存、引擎二进制、玩家目录及test/work；专项审计只读明确范围。

## 执行约束

- 先明确GOAL / SCOPE / DO_NOT_TOUCH / DONE_WHEN；用户已明确时不重复询问。保护已有修改，不顺手改无关区域。
- 正确性优先；小步修改→对应测试→检查diff→确认行为不变。验证失败先定位或回退，不带失败叠加修改；不改正确断言迁就实现。
- 禁止擅自改变游戏数值、规则、未决规则或恢复废弃机制。代码事实不等于策划批准；未决项只在STATUS保留ID。
- 来源标注区分原表/用户确认、当前实现、推导（写明前提）；冲突先记录，不静默选择一方。一个事实一个权威来源。
- 禁止擅自修改正式Excel/JSON；已编辑分表不能被旧总表覆盖。经授权的配置任务仍须先核对来源与影响范围，操作查项目README。
- 禁止操作正式玩家存档，不用玩家目录复现问题；测试必须复制项目和用户目录，仅改隔离副本。
- 不为重构新增Manager / Service / Framework、ECS或通用策略层；没有明确净收益则保持原实现，不机械拆长文件。
- 不凭无引用搜索就删除代码/资源/入口；先证明实际用途及消费者。性能修改遵循DECISIONS的测量门槛。

## 验证与交接

- [测试入口](../test/README.md)提供隔离runner与专项路由；产物只放`../test/work/`，不在工作区根生成验证目录。
- 只跑修改及直接影响范围的必要检查；仅文档改动检查事实、链接、未决ID和diff，不运行游戏测试。UI改动另核对实际交互/画面。
- 完成后覆盖STATUS当前状态，不追加Done流水账；稳定规则改PROJECT，定位改ARCHITECTURE，长期取舍才改DECISIONS。
- HANDOFF：DONE / CHANGED / VERIFY / NEXT；存在阻塞才加BLOCKERS，新长期决策才加DECISION。用户指定检查点格式时按其格式，不复述项目背景。
- 跨AI/IDE协作以仓库文档为准，不依赖聊天或私有记忆；其他入口仅链接本文件。
