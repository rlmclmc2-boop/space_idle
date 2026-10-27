# 后端/契约接替交接

- 原工作区：`C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate`；项目cwd为其`space-battleship/`。后继复用原目录与分支，不克隆、不新建工作区。
- 分支：`feat/amount-safe-previews`；本次交接更新前HEAD为`7a3ba156f975d07014f6b59a548060729a982128`，已普通推送并回读一致。本交接提交仅更新本文，不变更运行实现或规范。
- 保留179项已跟踪生成文件修改、262项未跟踪.uid/.import；不清理、不纳入提交。
- main审批暂停，不重试合入或另路发布。以下通过均仅限已列定向证据，不等于完整游戏/UI/性能验收。
- 本线程已实际压缩，当前自然项结束；未开始M9实现或其他新制作。

## 当前入口与待复查项

从[game-design唯一入口](../game-design/README.md)按需读取：[14共同边界与模块索引](../game-design/14-ui-contracts.md)，再到`docs/game-design/contracts/`对应分册。纯结构迁移固定`7a3ba156f975d07014f6b59a548060729a982128`，待复查；覆盖清单与链接检查见[迁移记录](ui-contract-split.md)，原规范语义/版本状态未升级。

M9最小只读提案固定`cad1ee17b1efbf39ee06d725b33182eefbb78699`，待复查、未实现：[提案](m9-readonly-contract-proposal.md)。兑换准备已补目标旧余额+received的Amount.add及原顺序/错误；can_pay=true不等于完整可兑换许可。保存宿主摘要仍为独立剩余项，不混入M9。后继先等复查结论与实施授权。

## 已通过的实现范围

- Amount预览纯度及入口浅拷贝尾项：`6f6f9fd2a6f9fb5b2ce829a86f02937552b5328c`，定向双审通过；[实现与证据](amount-preview-implementation.md)。
- 超空间路线最佳/单次与自动预览、过滤导入预览、Planet自动状态：证据字节修订至`4c1de5074377278a474befb9bd618c0f19d27d65`，三项定向双审通过；[实现与证据](readonly-preview-implementation.md)。
- M2/M5读取、实际成交回执及已接纳装甲读取边界：`ab6e887349cd4db1e0162471130686d2c2f30ca0`，定向双审通过；[实现与证据](equipment-enhancement-readonly-implementation.md)。保留原命令准备对pending装甲的候选语义；新查询仅读actual。不得称完整UI验收。

共享几何仍仅[来源与最小提案](shared-geometry-source-proposal.md)，固定`0ec9572715a9555774e4ee56b891fff71c2725ff`。M1已定首领居中3×2不重开；逐舰占位来源冲突、成熟整体方案真实参数/运动边界待裁定，不实施真实几何、布点、Excel或新规则。
