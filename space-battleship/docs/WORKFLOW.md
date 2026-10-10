# WORKFLOW：操作与交接入口

协作、授权、验收及发布规则以 [PROJECT_CONSTRAINTS](PROJECT_CONSTRAINTS.md) 为唯一入口。

## 开始与接续

核对 HEAD、工作区及当前私有检查点中的已完成操作、下一步和阻塞。用真实工作区操作确认环境可用，再继续授权范围内未闭合事项，避免重复已完成操作。先定位目标，仅加载相关文档与技能；技能缺失时检查项目 `.agents/skills`。阶段交接更新同一份私有检查点，不把临时进度写成长期规则。

## 按任务加载

| 任务 | 入口 |
|---|---|
| 代码与数据定位 | [ARCHITECTURE](ARCHITECTURE.md) |
| 稳定玩法 | [PROJECT](PROJECT.md) |
| 未闭合问题与长期决策 | [STATUS](STATUS.md)、[DECISIONS](DECISIONS.md) |
| 战斗、武器、增益与宝石 | [BATTLE](BATTLE.md) |
| UI、渲染、输入与玩家文字 | [UI](UI.md)、[UI_TEXT](UI_TEXT.md) |
| 测试与命令 | [TEST](TEST.md)、[测试 README](../../test/README.md) |
| 平衡、模拟与性能 | [BALANCE_LAB](BALANCE_LAB.md)、[BALANCE_PERFORMANCE](BALANCE_PERFORMANCE.md) |
| 船员、美术与关卡编辑器 | [CREW](CREW.md)、[ART_GUIDELINES](ART_GUIDELINES.md)、[LEVEL_EDITOR](LEVEL_EDITOR.md) |
| 任务 token 预算 | [token-opt](../.agents/skills/token-opt/SKILL.md) |
| 长上下文与交接 | [ctx-compress](../.agents/skills/ctx-compress/SKILL.md) |
| 持久规则与文档编辑 | [doc-compact](../.agents/skills/doc-compact/SKILL.md) |

## 交接核对

交接列出当前提交、结论及证据限度、未闭合问题、下一步和阻塞。按用户评审节奏及正式交付前，从仓库根目录执行：

```sh
python tools/check_workflow.py <private-ledger.json>
```

父的实际独立意见评审另用同一命令加 `--review`，核对参与者、各自来源与覆盖、处置理由、修改后效果及旧低分跟进。校验器只检查材料完整性；不能用通过结果证明事实或替代实际评审。保留一份当前私有台账，不另建公开详细报告。
