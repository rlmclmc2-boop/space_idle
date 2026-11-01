# 太空战舰设计文档：唯一入口

当前制作来源见[11](11-stage6-contract.md)。按任务选择下表对应内容；规划文档维护自身目标、必要接口和完成标准。

| 内容 | 唯一规范 |
|---|---|
| 流程、时间、经济、解锁通知 | [01](01-runtime.md) |
| 战斗、命中、死亡、派生 | [02](02-combat.md) |
| 装备、反应炉、科研、船员、星球、星系、重铸规则 | [03](03-progression.md)对应小节 |
| 超空间、无人机、仓库、改造、过滤 | [04](04-hyperspace.md) |
| 所有者与运行架构 | [05](05-architecture.md) |
| 配置、Amount、保存与恢复 | [06](06-data.md)；[资源整数](contracts/resources.md) |
| 规则验证场景、审核与交接 | [07](07-verification.md)；构建命令见[foundation](../../foundation/README.md) |
| 已定规则索引 | [08](08-decisions.md) |
| 参数与尺度参考 | [09配置目录](09-config-catalog.md)、[舰船尺寸](reference/ship-scale.md) |
| 桌面宽屏美术、布局、交互呈现 | [13](13-art-interaction.md)及一个相关M/V页 |
| 前后端状态、命令、结果与通知 | [14](14-ui-contracts.md)及对应模块分册 |
| 待定问题 | [规则问题](review/conflicts.md)、[美术选择](art/open-items.md) |

跨系统只读取实际用到的输入/输出接口及其唯一来源。玩法、参数和保存格式变更按用户授权范围进行；Excel 是运行参数权威。当前界面目标为桌面宽屏。
