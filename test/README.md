# 测试入口

选测与停止规则见 [TEST](../space-battleship/docs/TEST.md)。本页保留可复用命令入口。

## 选测

按变化从下表选相关专项；同一行是候选入口。
命令以仓库根目录为工作目录；裸脚本名位于 test/。只打开相关主题，不展开全部指南。

- [伤害、弹体与战斗坐标](guides/combat.md)
- [推进、解锁、时间与入门指引](guides/progression.md)
- [换装、成长与属性缓存](guides/equipment.md)
- [舰船预览与战场表现](guides/ship-art.md)
- [界面刷新、音乐与文案](guides/ui.md)
- [船员](guides/crew.md)
- [星系殖民](guides/galaxy.md)
- [星球探索、建筑与重铸](guides/planets.md)
- [AI 科技研发](guides/ai-tech.md)
- [熔炉、资源与反应炉](guides/resources-reactor.md)
- [护盾、恢复缓冲与延迟伤害](guides/defence.md)
- [强化等级、快照与分支](guides/enhancements.md)
- [存档导入导出与重启](guides/saves.md)
- [无人机与异空间反馈](guides/hyperspace.md)
- [配置导入与编辑器](guides/configuration.md)
- [敌我组合生成](guides/fleet-generation.md)
- [批量战斗与抽样](guides/fleet-batch.md)
- [结果分析、定向复测与设计卡片](guides/fleet-analysis.md)
- [Balance Lab 与独立模拟工具](guides/balance-tools.md)

需定位具体规则断言时再查 [TEST_MAP](TEST_MAP.md)，不要将其当作执行清单。未列出的脚本仅在有明确相关需求、核对当前断言后使用；`test_game.gd` 和 legacy 探针不是默认基线。旧科研窄条/旧返回入口的 UI 夹具不用于当前大厅验收，当前入口见上表。

## 运行

[隔离环境、命令、超时与产物处理](guides/running.md)。

## 性能与发布（按需）

- [性能测量](guides/performance.md)
- [构建与发布](guides/release.md)

现有缺口与故障统一见 [STATUS](../space-battleship/docs/STATUS.md)。内存夹具通过不代表正式数值平衡验收，故障观察通过不代表事务安全。
