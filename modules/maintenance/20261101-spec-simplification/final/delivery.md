# 最终文档交付

main与本清理分支已经普通快进发布并回读；五组各一个合并后的文档候选，供原执行者消费。前批docs/handoff-consumption-*候选不再单独消费，本轮已经包含其必要差异。星球使用以c1cb1af2为父的v2候选，旧0d3df5e1不再消费。原组若有新提交，按下列固定父版本与现行文件比较后消费，保留现场新增内容和WIP。

| 组 | 固定父版本 | 最终提交 | 分支 | 本轮是否已写原分支 |
|---|---|---|---|---|
| main | `622688863e10ba7e6bc7341b6dd776b8d5c1762f` | `7b3702af224deff65375861c9a60be3c19e0a659` | `main` | 已写并回读 |
| equipment | `f3f43f247260e7a1587e8c65eae91b6159cb5fc1` | `de7f796b9ee39c9a6a4cffbc21dc2dab346b1faf` | `docs/final-scoped-docs-equipment-20261101` | 候选已推送；原组待消费 |
| reactor | `966a9132569d52ce9a1e641c1845f69c091a8371` | `a4b1bfc3e9b44a50503bd921f6f3dd98c275376e` | `docs/final-scoped-docs-reactor-20261101` | 候选已推送；原组待消费 |
| host | `b569f0e9d0728e13dc8af798149026cc94f004cf` | `46b5120333ca9faf02a84a4ca8a7c0f60a96a978` | `docs/final-scoped-docs-host-20261101` | 候选已推送；原组待消费 |
| planet | `c1cb1af2f6c673401b20ba0e1d9755e61f9c025f` | `0704bcc78dc385855635e06c2134e08b58ac01e9` | `docs/final-scoped-docs-planet-20261101-v2` | 候选已推送；原组待消费 |
| backend | `90e22ac9f36a411e222eb286691a1cf2d39f2fb8` | `d8097332495b8ef1c1cfcc19fa46637c3d63556d` | `docs/final-scoped-docs-backend-20261101` | 候选已推送；原组待消费 |
| cleanup | `47536e1ec5ee7d5175de5065538b42e0aeb52dfd` | `08a918a6b0989acc6eb5c86409da2534db5259d7` | `docs/design-entry-cleanup-20261031` | 已写并回读 |

## 每组完整最小文件差异

共用规范四份：06-data.md、07-verification.md、13-art-interaction.md、art/modules/planet.md，均在space-battleship/docs/game-design/。每个组只应用自己这一份提交。

### main

- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/07-verification.md`
- `space-battleship/docs/game-design/13-art-interaction.md`
- `space-battleship/docs/game-design/art/modules/planet.md`

本轮完整差异 4 文件，377→368行，21499→20751字符。

### equipment

- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/07-verification.md`
- `space-battleship/docs/game-design/11-stage6-contract.md`
- `space-battleship/docs/game-design/13-art-interaction.md`
- `space-battleship/docs/game-design/art/modules/planet.md`

本轮完整差异 5 文件，386→375行，22350→21432字符。

### reactor

- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/07-verification.md`
- `space-battleship/docs/game-design/11-stage6-contract.md`
- `space-battleship/docs/game-design/13-art-interaction.md`
- `space-battleship/docs/game-design/art/modules/planet.md`
- `space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/HANDOFF.md`

本轮完整差异 6 文件，405→392行，23264→22088字符。

### host

- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/07-verification.md`
- `space-battleship/docs/game-design/11-stage6-contract.md`
- `space-battleship/docs/game-design/13-art-interaction.md`
- `space-battleship/docs/game-design/art/modules/planet.md`

本轮完整差异 5 文件，386→375行，22128→21432字符。

### planet

- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/07-verification.md`
- `space-battleship/docs/game-design/11-stage6-contract.md`
- `space-battleship/docs/game-design/13-art-interaction.md`
- `space-battleship/docs/game-design/art/modules/planet.md`
- `space-battleship/docs/verification/planet-single-side-godot/restore.md`
- `space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HANDOFF.md`

本轮完整差异 7 文件，403→397行，23255→22326字符。

### backend

- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/07-verification.md`
- `space-battleship/docs/game-design/11-stage6-contract.md`
- `space-battleship/docs/game-design/13-art-interaction.md`
- `space-battleship/docs/game-design/art/modules/planet.md`

本轮完整差异 5 文件，386→375行，22226→21432字符。

### cleanup

- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/07-verification.md`
- `space-battleship/docs/game-design/13-art-interaction.md`
- `space-battleship/docs/game-design/art/modules/planet.md`
- `space-battleship/docs/maintenance/HANDOFF.md`

本轮完整差异 5 文件，381→372行，21399→20659字符。

## 已核结果与限制

44条原文来源映射、14个唯一blob已推送独立归档并fresh fetch回读，Git blob及SHA256一致；再发布本轮规范。所有差异均为Markdown，非Markdown对象清单逐一相同。相对文件与锚点检查无错误。各远端最终提交已回读确认；observed-heads.json记录交付时原分支HEAD。未改运行代码、资产、Excel、个人存档或他人WIP，未运行游戏/性能/独立复测。

审核主体为本执行线程文档自核（Astra high），不是用户验收或其他系统测试。当前无新增需用户裁定的问题；各组尚未消费本轮候选是交付状态，不是权限拒绝。现行生产/测试输入清单与诊断semanticHash仍在当前导入工具中，不能概括为全部已废弃；本轮撤掉的是旧包机制与通用规范强制承担的工具检查。原文、准确来源与处理依据见index.md。
