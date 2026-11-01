# 实际发布与按线程消费

## 生效状态

主线main已普通快进至dd8b1f6a72305a7a450e05938a231998e7c3fbc4；本清理线程分支已消费91c5946dd54b2702e5dc5958c3e6666569f80509，工作区clean。五个制作分支只发布独立文档候选，最终ls-remote尚未包含候选；反应堆原组前进至2ee27743、公共壳前进至bcb9ea38，其新增制作/观察已保全并纳入交接，未确认实际消费。新星球线程已有96de0d84保全WIP，候选基于c46c1b2e，只取文档差异并由新执行者与其现场合并。

| 线程 | 核过并整理的制作入口/规范/交接 | 具体修复与消费 |
|---|---|---|
| 装备 | docs/verification/equipment-hangar-godot/workbench-optical-revision/{README.md,inline-slot-workbench-concept/README.md}；M2；新增同目录HANDOFF.md | 入口只指M2，完成版本/窄修审核/作者覆盖移HANDOFF；免费即时切换、全局数量同步、真实槽身份保M2。原组候选e88d9338待消费。 |
| 反应堆 | docs/verification/reactor-centered-godot/README.md及evidence/b01-redesign/README.md；M3与资产契约；新增B01 HANDOFF.md | 解锁判定引用Owner；可见集合、1/2/3/4路显隐/工作表现保规范；运行源、热流/场壳当前一步、作者覆盖移交接。目标硬件性能未测作为覆盖事实保留。候选8796daa1待消费。 |
| 整体 | docs/ui-redesign-plan/README.md及shared-host-shell/runtime-clear-zone/README.md；13/V0；新增runtime-clear-zone/HANDOFF.md | 制作入口只导航13，运行组合/端口版本/2-3路最新作者图与下一步移交接，设备内部目标指M3。候选cd090653待消费。 |
| 后台 | 14与11模块分册、资源契约、05/06、后台树中的三组复制入口；新增docs/HANDOFF.md | 接纳/单位等共同接口留14，过滤/草稿/成交回执归各模块；移出旧双审叙事和重复视觉任务；强化MAX真实缺口保留。候选90e22ac9待消费。 |
| 新星球 | docs/verification/planet-single-side-godot/{README.md,visual-r17-curved-spine/README.md}；M7；新增同目录HANDOFF.md和../restore.md；只读96de0d84停机交接 | 入口仅导航M7；批准图、贯穿节点、四设施结构要求归M7。WIP与下一步进HANDOFF，恢复短列；Owner整数、Reactor接口缺口、configHash、调度/压缩历史从制作页移出。候选8aa58dbd待新执行者消费，不写其WIP。 |
| 本清理线程 | 唯一规范入口、11、07及本树复制入口；新增docs/maintenance/HANDOFF.md | 清理目标、当前一步和恢复单列交接；规范/入口/交接职责写入唯一07。已普通推送并消费91c5946d，clean。 |

各候选完整SHA、原始固定源、所有文档路径与实际生产HEAD见delivery.json。消费只针对paths清单中的文档差异；先与原执行者当前HEAD/WIP核对，按三方差异接入，保留新工作。不要整树覆盖。对正在制作的星球，96de0d84源码/模型WIP均不是本次改动。

## 规模与核查

以完整公共规范host来源计：13从166行/15709字符到90行/3916字符；M1–M10从11347字符到7147字符，关键约束保留。各分支差异规模见checks.json；main补齐12份已有分册/资产契约，因此行数增加，字符总量仍下降。

归档原文251条来源映射/101唯一blob已在8df9f414逐项回读Git blob与SHA256一致；并发前进的3份原文另在2fe8dbdb逐项回读SHA256。所有候选相对各自基线只改.md；源码、运行资产、Excel及全部非Markdown树对象逐项相等。变更页面相对文件/锚点无错误，当前GitHub固定/候选Git目标在对象树存在；git diff --check通过。

核查主体：本执行线程文档自核，非独立审核；未创建或续派子智能体、未运行游戏/性能/独立复测。

## 未决与后续

规则C4父攻击身份/保存水位与首槽换型双零保持未决；美术D3/D4/D5/D8保持待定，未替用户决定。五原组实际消费尚待确认；这不是权限拒绝或已失败的写入，而是按要求保护在写现场的交接阶段。应由父协调交原执行者/新星球执行者安全接入后回报真实SHA，再核入口和规范各自职责。

首次归档推送遇普通non-fast-forward，因为公共壳同时追加aeb00c5e图证；已读取其真实新增范围，保留后以普通后继提交成功推送，没有强推或覆盖。
