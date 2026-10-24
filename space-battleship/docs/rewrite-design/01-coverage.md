# 01 覆盖总账与阅读规则

本方案从产品用途、Excel内容、当前入口和实际代码四路核对。正文给新规格；清单给逐项身份与追踪。**旧实现/表内历史备注/旧测试不是自动批准的规则。** R是保留建议、P是结构建议，均交整体审阅；D是真实待决，阻止依赖行为实施。没有把缺规则写成“沿用旧系统”。

## 盘点结果与界限

- 30份工作簿、57张sheet、439个物理列位置、28,462条非空数据行；其中正式源25份/45张sheet，历史总表8张sheet，派生副本4张sheet。空结构列也列入账，不伪称439个有效业务字段。
- 42张小表附当前单元格内容；大表保留全部行号、身份摘要和行哈希。200条键值型参数单独映射业务章节；19份运行JSON全部有迁移归属；JSON独有内容逐叶15,242条，含大量文案，不用数量冒充业务复杂度。
- 55项功能契约，每项明确规则、owner、公式/配置来源、调用、时序、保存/重置、UI、错误、保留边界、验收；14另展开6项执行接口。16类游戏/工具/构建/测试入口；3,377个实现/资产/旧测试文件给保留边界政策。
- 工作簿读取只盘点源/缓存/公式文本，未重算Excel；源码阅读核对规则，未启动游戏、构建、测试或性能探针。文件分类是范围账，**不是逐函数等价证明**；混合文件不得按整个文件删除或直接继承。

## 逐项功能索引

十维紧凑契约见[feature-contracts.csv](inventory/feature-contracts.csv)；下表连到正文。共同契约S02的拒绝无副作用、SV02的文件失败、UI01的局部刷新适用于全部行；特殊行为必须以该行正文为准，不能省略业务差异。

| 功能ID | 单一owner | 正文 | 验收 | 状态 |
|---|---|---|---|---|
| C01 | ConfigCompiler | [02](02-configuration.md) | A-CFG | U/P |
| C02 | ConfigCompiler | [02](02-configuration.md) | A-CFG | R/P |
| C03 | 域配置 | [02](02-configuration.md) | A-CFG | U/D |
| C04 | ConfigCompiler | [02](02-configuration.md) | A-CFG | U/D |
| S01 | 各业务域 | [03](03-state-and-calls.md) | A-SAVE | P |
| S02 | 操作发起域 | [03](03-state-and-calls.md) | A-EQP | P |
| S03 | Combat native | [03](03-state-and-calls.md) | A-NATIVE | U/P |
| P01 | Progression | [05](05-progression-equipment.md) | A-PROG | R |
| P02 | Progression | [05](05-progression-equipment.md) | A-PROG | R |
| EQ01 | Equipment | [05](05-progression-equipment.md) | A-EQP | R/D |
| EQ02 | Equipment+Attributes | [05](05-progression-equipment.md) | A-EQP | R |
| EN01 | Enhancement | [05](05-progression-equipment.md) | A-ENH | U/R |
| EQ03 | Equipment | [05](05-progression-equipment.md) | A-EQP | D |
| B01 | Combat | [04](04-combat.md) | A-BTL | U |
| B02 | Combat | [04](04-combat.md) | A-BTL | R/D |
| B03 | Combat | [04](04-combat.md) | A-BTL | R/D |
| B04 | Combat+Enhancement | [04](04-combat.md) | A-BTL | R |
| B05 | Combat | [04](04-combat.md) | A-BTL | R |
| B06 | Combat | [04](04-combat.md) | A-BTL | R |
| B07 | Combat+Presentation | [04](04-combat.md) | A-NATIVE | U/P |
| B08 | Combat | [04](04-combat.md) | A-BTL | R/D |
| ECO01 | Economy | [06](06-economy-research-crew.md) | A-ECO | R |
| ECO02 | Economy | [06](06-economy-research-crew.md) | A-ECO | R |
| ECO03 | Economy | [06](06-economy-research-crew.md) | A-ECO | D |
| REA01 | Reactor | [06](06-economy-research-crew.md) | A-REA | R |
| RES01 | Research | [06](06-economy-research-crew.md) | A-RES | U/R |
| CREW01 | Crew | [06](06-economy-research-crew.md) | A-CREW | R |
| H01 | Hyperspace+Combat | [07](07-hyperspace-drones.md) | A-HYP | U/D |
| H02 | Hyperspace | [07](07-hyperspace-drones.md) | A-HYP | R |
| H03 | Hyperspace | [07](07-hyperspace-drones.md) | A-HYP | R |
| DRI01 | Hyperspace.Inventory | [07](07-hyperspace-drones.md) | A-DRONE | R |
| DRF01 | Hyperspace.Forge | [07](07-hyperspace-drones.md) | A-DRONE | R |
| DRF02 | Hyperspace | [07](07-hyperspace-drones.md) | A-DRONE | R/D |
| W01 | Planets | [08](08-world-reforge.md) | A-WORLD | R |
| W02 | Planets | [08](08-world-reforge.md) | A-WORLD | R |
| W03 | Galaxy | [08](08-world-reforge.md) | A-WORLD | R |
| W04 | Galaxy | [08](08-world-reforge.md) | A-WORLD | R |
| W05 | Planets+Session | [08](08-world-reforge.md) | A-RESET | R/D |
| W06 | 各域 | [08](08-world-reforge.md) | A-RESET | D |
| N01 | 共享native BigNumber | [09](09-runtime-save.md) | A-NUM | U/P/D |
| TM01 | Session | [09](09-runtime-save.md) | A-TIME | R/P |
| SV01 | 各域+SaveIO | [09](09-runtime-save.md) | A-SAVE | U/P |
| SV02 | SaveIO | [09](09-runtime-save.md) | A-SAVE | R/P |
| LC01 | Session | [09](09-runtime-save.md) | A-RESET | P |
| UI01 | UI | [10](10-ui-presentation.md) | A-UI | U/P |
| UI02 | 各页面 | [10](10-ui-presentation.md) | A-UI | U/R |
| UI03 | Presentation | [10](10-ui-presentation.md) | A-UI | U |
| T01 | 工具宿主 | [11](11-tools-release.md) | A-TOOLS | U/P |
| T02 | F8 | [11](11-tools-release.md) | A-TOOLS | U/P |
| T03 | F9 | [11](11-tools-release.md) | A-TOOLS | R/P |
| T04 | 分析器 | [11](11-tools-release.md) | A-TOOLS | R/P |
| T05 | 周期生成器 | [11](11-tools-release.md) | A-TOOLS | R |
| T06 | 编辑器/QA | [11](11-tools-release.md) | A-TOOLS | U/R |
| T07 | 构建/发布 | [11](11-tools-release.md) | A-REL | R/P |
| A00 | 新测试运行器 | [12](12-acceptance-rollout.md) | A-CFG | U |

## 清单索引与核对方式

| 清单 | 每项包含什么 | 用于什么，不用于什么 |
|---|---|---|
| [workbooks.csv](inventory/workbooks.csv) | 文件/sheet/源角色/字节SHA/物理范围/行数/规则章节 | 判断正式源集合；published与总表不补缺 |
| [fields.csv](inventory/fields.csv) | 所有列位置、名字、原说明/类型、数据/公式计数、缺缓存、规则归属与删除边界 | 逐字段检查遗漏；原说明中的旧锁定/有限double不是新规格 |
| [rows.csv](inventory/rows.csv) | 全部非空行的坐标、前三项身份摘要、行SHA | 确认内容未因重写漏行；不把每行当一种新机制 |
| [small-config-content.json](inventory/small-config-content.json) | 小表表头、说明、全部实际值 | 方便审阅数值内容；禁止运行/测试加载这个副本 |
| [parameter-contracts.csv](inventory/parameter-contracts.csv) | 键值参数的具体键、值、章节、待决/删除状态 | 揪出科学家旧键/未消费票耗；不是新的参数源 |
| [runtime-data.json](inventory/runtime-data.json)、[json-migration.csv](inventory/json-migration.csv) | 运行JSON身份及新Excel/生成结构归属 | 每个文件的唯一权威迁移，无双向同步 |
| [json-only-fields.csv](inventory/json-only-fields.csv) | JSON独有内容逐叶当前值、新归属与契约 | 文案/分析/外观内容不漏；表结构实现按02重建 |
| [entrypoints.csv](inventory/entrypoints.csv) | 实际根文件、用户入口、新调用链、输入输出/写范围、验收 | F1/F8/F9/编辑/发布用途不能因删旧工具漏掉 |
| [code-boundaries.csv](inventory/code-boundaries.csv) | 实际文件SHA、保留/拆分/重写/旧测试删除政策 | 资产目录不是安全复制/删除单位；不授权本轮修改 |
| [source-coverage.csv](inventory/source-coverage.csv) | 功能资料→新契约→冲突/适配 | 资料仅证据定位；正文已重述规则，无须追旧链接才能实施 |

## 明确排除与未决

确认排除：发射预结算/预测击杀/双份权威HP；独立exact/fast战斗模型；旧科学家/科技点/旧宝石对象合成镶嵌；旧crew_level与charge；缓存/内置值补缺测试源；未经效率证明回退GDS热路径；全量快照/通用管理包装；旧存档兼容迁移承诺。

未决完整见[13](13-decisions-evidence.md)：原战场清空后的返回、免费/费用配置冲突、旧成长精确删除、进化、数值范围、rail现行例外、工具统计口径、非Excel内容迁移边界、重铸矩阵、熔炉、首轮导弹CD、盾最小伤害、选敌中心、遗留干扰来源。未决不等于漏做设计，也不等于默认沿旧行为；受影响验收为blocked，其余设计可独立审阅。

## 完成判据

本轮交付是可审阅的完整设计包，不是实施授权或等价性证明。实施前按功能行逐项确认R/P与D裁决；实现后按A验收独立Excel验证，缺源即无效。新增或删除一项功能须同一提交更新其正文、覆盖行、配置归属与验收，不能只改代码让账失真。此规则是文档维护约定，不增加运行期管理机制。
