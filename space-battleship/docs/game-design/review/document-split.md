# 文档拆分候选交付与阅读规模

[唯一入口](../README.md)。基线 `main@7a85481b75f323af75d53427312afd0ae0f45d70`；本轮仅文档候选，未合main。审核修正依据已有权威澄清05/06，不改数值或实现。字符为Unicode字符数（含Markdown），行数按换行统计，不估算模型token；统计脚本只静态读取文档，未运行游戏。

## 入口规模

| 文件 | 拆分前 | 拆分后 |
|---|---:|---:|
| README.md | 4,362 字符 / 73 行 | 2,443 字符 / 33 行 |
| 09-config-catalog.md | 52,372 字符 / 1253 行 | 2,117 字符 / 38 行 |
| 11-stage6-contract.md | 55,200 字符 / 314 行 | 1,172 字符 / 23 行 |
| 13-art-interaction.md | 25,399 字符 / 336 行 | 8,010 字符 / 121 行 |

原四入口文件合计 137,333 → 13,742 字符，减少 90.0%。这是入口体量，不是仓库总文档量；历史和参数迁出后仍可按需读取，不能把移动字数宣称为删除规则。 本轮完整Markdown总量约21.5万→24.0万字符（含新增审阅清单、接口契约和分片导语）；总量未缩小，收益是按任务减少默认载入，并显式删除重复/失效指导。

## 代表性任务的最小阅读

下表比较入口、组织和相应事实来源；若任务变更玩法/公开契约，README要求的对应正文小节须在前后都另加。只读S来源的指定标题，不默认把整份来源注册表读入。

| 任务 | 拆分前选读单位 | 拆分后最小选读单位 | 字符变化 |
|---|---|---|---:|
| 仅反应炉UI制作/视觉审查 | README.md＋13-art-interaction.md | README.md＋13-art-interaction.md＋art/modules/reactor.md＋S5来源节 | 29,761 → 17,864（减少 40.0%） |
| 仅查询crew字段/表值来源 | README.md＋09-config-catalog.md | README.md＋09-config-catalog.md＋reference/config/crew.md | 56,734 → 6,036（减少 89.4%） |
| 追溯背景/真实炮口专项 | README.md＋11-stage6-contract.md | README.md＋11-stage6-contract.md＋history/stage6-assets.md | 59,562 → 10,788（减少 81.9%） |

## 迁移清单

| 原位置 | 新位置/处理 | 保留内容与边界 |
|---|---|---|
| 13第1–2、5–6节 | 13保留 | 全局身份、整屏构图V0、美术/交互/对齐/信息层级、复用边界与双审证据；第3节变为按模块索引，补唯一现行导航原则 |
| 13第3节 M1–M10/V1–V10 | `art/modules/{battle,equipment,reactor,research,enhancement,crew,planet,galaxy,hyperspace,persistence}.md` | 逐模块设计与可见验收，不再为单模块加载其他9页；M1只引用全局导航 |
| 13第4、7、8节 | `art/sources.md`、`art/open-items.md`、`reference/ship-scale.md` | S1–S12来源、G/D待定、参数/计算全部保留；相对路径修复，原统计基线和未验收边界保留 |
| 09第2/3节 | `reference/config/<工作簿>.md` 26页 | 每个工作簿的字段与小表值归一页；原配置704行Markdown表格及46行字段列表校对，无缺失 |
| 09第1/4节 | `reference/config-inventory.md` | 覆盖/大表语义作为来源快照，不伪称本轮重新采样；09只提供选择索引 |
| 09第0节 | `history/config-migration-targets.md` | 旧目标迁移原文保留溯源，撤销其作为当前必做命令的入口地位；字段歧义列F2，未改目标值 |
| 09第5/6节 | `history/config-fingerprints.md` | 旧指纹、总表和发布副本核对仅供追溯，不恢复旧split工具或第二权威 |
| 11当前结论/资产增量 | 11摘要＋`history/stage6-assets.md` | 版本、平台、哈希、原复审证据保留；当前待验收范围只在11摘要维护 |
| 11其余记录 | `history/stage6-integration.md`、`stage6-performance.md`、`stage6-combat-audit.md` | 按问题取证；旧“当前/已关闭/待合入”仅属当时构建，未把未决身份差异或容量分歧关闭 |
| 10原文 | `history/stage5-handoff.md` | 第5阶段端口/限制不再是现行职责入口；10只指向历史与05现行契约 |
| 05第3/6节、06旧09引用 | 按已有权威校正文案 | 区分单槽/全体原子性、真实目标与最终fit；固定HUD/六页仅标基线实现事实；旧总表与迁移映射改为正确历史路径 |
| 08末段与README | 更新索引 | 不再要求从09目标映射执行迁移；README给任务最小范围、按影响追加契约与唯一权威位置 |

26个配置分片逐项为：`ai_tech_tree`、`battle_design`、`config`、`crew`、`crew_assignment`、`crew_config`、`enemy_weapon_base`、`enhance_config`、`equipment`、`galaxy`、`galaxy_build`、`galaxy_config`、`hightech`、`hyperspace_config`、`hyperspace_enemies`、`level`、`level_monGroup_generated`、`mon`、`monGroup`、`planet`、`planet_buff`、`planet_build`、`res`、`ship`、`unlock`、`weapon_motion`。原09只含这些完整字段节，未凭空补其他3表。

## 删除/废止清单

- 删除原README重复讲述的玩法概览、边界表、核心结构、操作示例和规则长摘要；其规则已有01–06/08权威位置，入口改为路径索引，不另留一份历史副本。原文仍可从基线Git回读。
- 删除原11“当时的阶段验收状态（已由当前台账取代）”整节：包括Maximum-load、Operator、Main review三行旧gate及重复总结。它们已有当前摘要/对应版本证据，不能继续表示待办或泛化通过。保留C10完整差异、MAX接受范围、容量双来源和其他独特证据。
- 废止旧09目标映射、旧指纹/总表比较及10阶段限制作为现行执行入口；原文移入历史，没有删除数值或据此启用/停用玩法。
- 删除13原任务“本次限定两份设计文件”等无后续用途的过程性表述，删除入口处重复的历史候选叙述；保留事实的原始版本范围。
- 按本轮明确新指示替换旧“离开—返回战斗”导航要求：只在13第2.2节定义持续战斗＋并列模块面板的紧凑导航；没有恢复旧像素布局，没有改代码。

## 矛盾与待定

[裁定清单](conflicts.md)仅将C1容量与C4身份/保存水位保留为待裁定项，列原文、双边来源、影响和裁定问题。原C2/C3/C5已有现行权威，05仅校正文案与适用范围，不改实现；06的旧09节号/目标入口引用已同步修复。F1–F4是覆盖/时效缺口，与玩法冲突分开；已存在的首槽换类型双零判定仍留未决。

反应炉新增父审已查看的Git来源 `b4d2adc8` / `test/evidence/seven-parent-20261017/17-reactor6.png`，在S5与M3/V3说明整体控制台/供能场景为恢复依据；旧设备造型未获认可，新增可替换资产接口，接口v1的字段类型、坐标、语义锚点、转换、示例及导入字段已明确，实际美术/安装数值待定，本轮不生成新图；不是只复用图标，也不冻结重复读数/教学/旧尺寸。此精简checkout没有该对象，短SHA fetch未取回；依据为父审确认，本轮未冒称重新查看图片。

补充来源：`72b0fa22:galaxy-city-ui.png`（已建成星系城市）和`573e9312:after/planet-1-start.png`（探索起始星球界面）已按父审查看结果加入S10/S9；历史参照不批准旧布局/数值，比较须匹配阶段。

## 核对范围

只核对文档迁移、表格行保留、引用/锚点、模块与V编号、阅读规模、Git差异和候选范围；无代码/Excel/存档/测试设施变更，不运行游戏测试。本候选须审核后才合main；整屏外框/全局UI仍未通过，新增2.0/V0整体审核，不由模块裁图或模块通过代替；UI制作、实机对齐/净空和品质验收均未因此完成。
