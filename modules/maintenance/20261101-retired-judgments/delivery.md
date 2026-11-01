# 清理发布与实际消费状态

main与清理分支已普通推送并回读。五组原执行者均已实际消费并经远端回读，当前制作继续。确切提交和全文核查见[实际消费闭环](consumption/index.md)。星球/整体当前HANDOFF不在补丁中；反应堆新资产合同不在本组补丁中。

| 组 | 固定父版本 | 发布提交 | 分支 | 原分支已消费 |
|---|---|---|---|---|
| main | `7b3702af224deff65375861c9a60be3c19e0a659` | `7a20bec9cc6369afbabf597f78d65bd8b65ebca3` | `main` | 已发布回读 |
| cleanup | `d08fb1b237eee99e1b25ec17c7778888ebd7ee4a` | `54d0e8fca0a093bcf56d5f53a4e5cf499746f07b` | `docs/design-entry-cleanup-20261031` | 已发布回读 |
| equipment | `de7f796b9ee39c9a6a4cffbc21dc2dab346b1faf` | `f74f465de8cf08d0f479f703fb6856d3680887b3` | `docs/remove-retired-judgments-equipment-20261101` | 已消费并回读 |
| reactor | `c20e4c1a121652514de533fe09203114606d0818` | `e0c0c997de5eac799e552a1f9d933b5005c24db6` | `docs/remove-retired-judgments-reactor-20261101` | 已消费并回读 |
| planet | `c2ea8202e1693a514be3058195d993a54c1be2fb` | `f8fedf37980df5377e71cb7fd5874d37c3440c0f` | `docs/remove-retired-judgments-planet-20261101` | 已消费并回读 |
| host | `6b62f8db8d764f28a4441fdf579f27cf3e3cc381` | `1c452e1776f8b2f958ff0ff167860603c7e314fe` | `docs/remove-retired-judgments-host-20261101` | 已消费并回读 |
| backend | `d8097332495b8ef1c1cfcc19fa46637c3d63556d` | `fe9c3706c29c86282aefdeb9875a09da0e8fee54` | `docs/remove-retired-judgments-backend-20261101` | 已消费并回读 |

## 实际路径与规模

### main

13份文档，1099→966行，72273→63365字符。

- `space-battleship/docs/game-design/01-runtime.md`
- `space-battleship/docs/game-design/03-progression.md`
- `space-battleship/docs/game-design/04-hyperspace.md`
- `space-battleship/docs/game-design/05-architecture.md`
- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/08-decisions.md`
- `space-battleship/docs/game-design/art/modules/reactor-asset-contract.md`
- `space-battleship/docs/game-design/contracts/equipment.md`
- `space-battleship/docs/game-design/contracts/hyperspace.md`
- `space-battleship/docs/game-design/contracts/reactor.md`
- `space-battleship/docs/game-design/contracts/resources.md`
- `space-battleship/docs/game-design/reference/ship-scale.md`
- `space-battleship/docs/game-design/review/conflicts.md`

### cleanup

14份文档，995→976行，65462→63823字符。

- `space-battleship/docs/game-design/01-runtime.md`
- `space-battleship/docs/game-design/03-progression.md`
- `space-battleship/docs/game-design/04-hyperspace.md`
- `space-battleship/docs/game-design/05-architecture.md`
- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/08-decisions.md`
- `space-battleship/docs/game-design/art/modules/reactor-asset-contract.md`
- `space-battleship/docs/game-design/contracts/equipment.md`
- `space-battleship/docs/game-design/contracts/hyperspace.md`
- `space-battleship/docs/game-design/contracts/reactor.md`
- `space-battleship/docs/game-design/contracts/resources.md`
- `space-battleship/docs/game-design/reference/ship-scale.md`
- `space-battleship/docs/game-design/review/conflicts.md`
- `space-battleship/docs/maintenance/HANDOFF.md`

### equipment

13份文档，986→967行，65136→63587字符。

- `space-battleship/docs/game-design/01-runtime.md`
- `space-battleship/docs/game-design/03-progression.md`
- `space-battleship/docs/game-design/04-hyperspace.md`
- `space-battleship/docs/game-design/05-architecture.md`
- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/08-decisions.md`
- `space-battleship/docs/game-design/art/modules/reactor-asset-contract.md`
- `space-battleship/docs/game-design/contracts/equipment.md`
- `space-battleship/docs/game-design/contracts/hyperspace.md`
- `space-battleship/docs/game-design/contracts/reactor.md`
- `space-battleship/docs/game-design/contracts/resources.md`
- `space-battleship/docs/game-design/reference/ship-scale.md`
- `space-battleship/docs/game-design/review/conflicts.md`

### reactor

14份文档，945→922行，61830→59745字符。

- `space-battleship/docs/game-design/01-runtime.md`
- `space-battleship/docs/game-design/03-progression.md`
- `space-battleship/docs/game-design/04-hyperspace.md`
- `space-battleship/docs/game-design/05-architecture.md`
- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/08-decisions.md`
- `space-battleship/docs/game-design/contracts/equipment.md`
- `space-battleship/docs/game-design/contracts/hyperspace.md`
- `space-battleship/docs/game-design/contracts/reactor.md`
- `space-battleship/docs/game-design/contracts/resources.md`
- `space-battleship/docs/game-design/reference/ship-scale.md`
- `space-battleship/docs/game-design/review/conflicts.md`
- `space-battleship/docs/verification/reactor-centered-godot/README.md`
- `space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/HANDOFF.md`

### planet

13份文档，986→967行，65012→63587字符。

- `space-battleship/docs/game-design/01-runtime.md`
- `space-battleship/docs/game-design/03-progression.md`
- `space-battleship/docs/game-design/04-hyperspace.md`
- `space-battleship/docs/game-design/05-architecture.md`
- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/08-decisions.md`
- `space-battleship/docs/game-design/art/modules/reactor-asset-contract.md`
- `space-battleship/docs/game-design/contracts/equipment.md`
- `space-battleship/docs/game-design/contracts/hyperspace.md`
- `space-battleship/docs/game-design/contracts/reactor.md`
- `space-battleship/docs/game-design/contracts/resources.md`
- `space-battleship/docs/game-design/reference/ship-scale.md`
- `space-battleship/docs/game-design/review/conflicts.md`

### host

13份文档，1002→983行，65849→64424字符。

- `space-battleship/docs/game-design/01-runtime.md`
- `space-battleship/docs/game-design/03-progression.md`
- `space-battleship/docs/game-design/04-hyperspace.md`
- `space-battleship/docs/game-design/05-architecture.md`
- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/08-decisions.md`
- `space-battleship/docs/game-design/art/modules/reactor-asset-contract.md`
- `space-battleship/docs/game-design/contracts/equipment.md`
- `space-battleship/docs/game-design/contracts/hyperspace.md`
- `space-battleship/docs/game-design/contracts/reactor.md`
- `space-battleship/docs/game-design/contracts/resources.md`
- `space-battleship/docs/game-design/reference/ship-scale.md`
- `space-battleship/docs/game-design/review/conflicts.md`

### backend

13份文档，986→967行，65012→63587字符。

- `space-battleship/docs/game-design/01-runtime.md`
- `space-battleship/docs/game-design/03-progression.md`
- `space-battleship/docs/game-design/04-hyperspace.md`
- `space-battleship/docs/game-design/05-architecture.md`
- `space-battleship/docs/game-design/06-data.md`
- `space-battleship/docs/game-design/08-decisions.md`
- `space-battleship/docs/game-design/art/modules/reactor-asset-contract.md`
- `space-battleship/docs/game-design/contracts/equipment.md`
- `space-battleship/docs/game-design/contracts/hyperspace.md`
- `space-battleship/docs/game-design/contracts/reactor.md`
- `space-battleship/docs/game-design/contracts/resources.md`
- `space-battleship/docs/game-design/reference/ship-scale.md`
- `space-battleship/docs/game-design/review/conflicts.md`

## 保留项与交付限制

C4父身份/保存水位、首槽换型双零两项待定问题保留；D3/D4/D5/D8美术选择保留。战斗历史计数、收入峰值、存档兼容和传说历史合法区间是有效业务事实，未删除。main换装段按已有现行装备契约及六分支的免费立即换装规则统一，未修改游戏实现。

整体6b62f8db与星球c2ea8202原组已清交接，全文已核，本轮不覆盖；星球v19与原组WIP持续保留。反应堆c20e4c1a的新资产合同保留，本候选只精简其最新HANDOFF及上层旧状态入口；后续并发提交由原组对照合入。本轮没有判断游戏制作通过。

93条原文来源映射、23个唯一Git blob先独立归档并fetch回读，Git对象与SHA256一致。当前修改均为.md，逐组非Markdown树对象完全相同；相对文件/锚点检查无错误；远端发布提交逐项回读。没有运行游戏、构建、Excel转换、性能或独立复测。审核主体：本执行线程文档自核。

五组消费已闭环，无剩余消费阻塞。本线程本轮归档写入没有自动审批拒绝。无新增待用户裁定问题。
