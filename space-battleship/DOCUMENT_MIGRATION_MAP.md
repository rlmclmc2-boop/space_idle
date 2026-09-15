# DOCUMENT_MIGRATION_MAP — Phase 11

这是本次迁移审计，不是第六份AI权威文档，也不是默认上下文。基线提交：`c6a07c4`。删除前已逐项映射；先写目标、检查独有信息与引用，再删除来源。旧原文从该提交按路径读取，避免留下重复副本。

分类：STABLE=领域事实，STRUCTURAL=结构，CURRENT=状态，DECISION=长期取舍，OPERATING_RULE=执行约束，HISTORY=开发过程。目标标签仅使用本表所列八种。相同事实只保留一个主归属，其他文件用链接。

## 全部26份现有文档与独有信息

下列路径相对项目，`../AGENTS.md`为工作区入口。每行覆盖一个有独立意义的信息组；明确标为历史/重复的原段不复制到目标。

| 来源 | 独有信息组 | 分类 | 处理 | 目标/删除依据 |
|---|---|---|---|---|
| ../AGENTS.md | 工作区指向唯一入口 | OPERATING_RULE | KEEP_AGENTS | 根文件只链接项目AGENTS；移除过时引擎位置与重复保护规则 |
| AGENTS.md | 项目一句话、L0/L1/L2、最小读取 | OPERATING_RULE | KEEP_AGENTS | AGENTS读取协议；以本轮授权替代默认PROJECT+STATUS |
| AGENTS.md | 来源/推导/冲突、限定任务范围、小步验证、不新增层 | OPERATING_RULE | KEEP_AGENTS | AGENTS执行约束 |
| AGENTS.md | 正式文件保护、隔离测试、按影响验证、简短交接 | OPERATING_RULE | KEEP_AGENTS | AGENTS保护与HANDOFF |
| AGENTS.md | 旧模块导航表 | STRUCTURAL | DELETE_DUPLICATE | ARCHITECTURE统一路由 |
| AGENTS.md | 页签规则、目录包、测试命令 | STABLE | DELETE_DUPLICATE | 分别归PROJECT、README、test/README |
| docs/PROJECT.md | 玩法目标、循环、术语、总览来源 | STABLE | KEEP_PROJECT | PROJECT定位/术语 |
| docs/PROJECT.md | 技术、视口、工具与平台 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE入口；平台未决归STATUS U-010 |
| docs/ARCHITECTURE.md | 入口、事件、QA、实体、存档、配置流 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE按任务路由与所有权 |
| docs/ARCHITECTURE.md | 未实施抽层建议与重复技术背景 | HISTORY | DELETE_HISTORY | 无当前授权，不携带旧建议为计划 |
| docs/STATUS.md | 当前能力、阶段、下一步 | CURRENT | KEEP_STATUS | STATUS四节；无逐Phase日志 |
| docs/STATUS.md | 长Done、旧Next启动提醒、历次文件清单 | HISTORY | DELETE_HISTORY | Git与保留的REFACTOR_PLAN承担历史 |
| docs/STATUS.md | Blocked中的有效风险 | CURRENT | KEEP_STATUS | 合并到各U-ID，不保留互相重复的无阻塞声明 |
| docs/DECISIONS.md | D-001共享入口/单一事实源 | DECISION | KEEP_DECISIONS | D001，五份分工取代旧modules/TODO结构 |
| docs/DECISIONS.md | D-002保持Godot和现有架构 | DECISION | KEEP_DECISIONS | D002，历史“不得删任何遗留文件”由本轮逐项批准替代 |
| docs/TODO.md | U-001 来源追溯与实验晋升 | CURRENT | KEEP_STATUS | U-001，config_workbooks入口 |
| docs/TODO.md | U-004 空unlock与startEquip冲突 | CURRENT | KEEP_STATUS | U-004，database.unlock_level |
| docs/TODO.md | U-005 实现补充未获完整策划确认 | CURRENT | KEEP_STATUS | U-005，defaults/保损等边界；不将代码当策划批准 |
| docs/TODO.md | U-006 零伤害/一级抗性/取整等适用范围 | CURRENT | KEEP_STATUS | U-006，hit_player/reduced_damage |
| docs/TODO.md | U-007 扩展/跨入口校验仍不完整 | CURRENT | KEEP_STATUS | U-007；删除已过时固定20级/size占格描述，不删除剩余风险 |
| docs/TODO.md | U-008 坏档、并发、重载保存失败 | CURRENT | KEEP_STATUS | U-008；Phase10已有open/rename观察，不写成完全未测或完全安全 |
| docs/TODO.md | U-009 未设计扩展系统 | CURRENT | KEEP_STATUS | U-009；舰船选择/独立槽位已实现，移出未设计名单 |
| docs/TODO.md | U-010 平台/打包/依赖可迁移 | CURRENT | KEEP_STATUS | U-010；“未发现Git仓库”已过时，删除该子句 |
| docs/TODO.md | U-011 枚举/接口/敌导弹遗留候选 | CURRENT | KEEP_STATUS | U-011；禁止由疑似无用推断可删除 |
| docs/TODO.md | U-012 原表插值示例歧义 | CURRENT | KEEP_STATUS | U-012保留原单元格定位与线性1.9/示例2冲突 |
| docs/TODO.md | U-013 机制夹具不证明平衡 | CURRENT | KEEP_STATUS | U-013；真实初始成长仍未验收 |
| docs/TODO.md | U-017 历史综合探针限制 | CURRENT | KEEP_STATUS | U-017；测试入口按TEST_MAP |
| docs/TODO.md | U-018 旧总表缺techPointGet | CURRENT | KEEP_STATUS | U-018；不可猜默认值或覆盖分表 |
| docs/TODO.md | U-019 回滚自身失败/备份损失 | CURRENT | KEEP_STATUS | U-019；故障观察不等于原子性保证 |
| docs/TODO.md | U-020 并发目标/manifest覆盖 | CURRENT | KEEP_STATUS | U-020；Store与incremental差异保留 |
| docs/TODO.md | U-021 全量UI重建热点 | CURRENT | KEEP_STATUS | U-021；测量入口，不复制性能过程 |
| docs/TODO.md | 已解决U-002/U-003/U-014/U-015/U-016、旧路线 | HISTORY | DELETE_HISTORY | Git保留；已确认规则分别迁PROJECT/ARCHITECTURE，不复活问题 |
| docs/GAME_DESIGN.md | 七系统导航、数据→实现→测试 | STRUCTURAL | KEEP_ARCHITECTURE | 新路由代替依赖test_game的旧导航 |
| docs/GAME_DESIGN.md | 其他重复背景及未建模块说明 | STRUCTURAL | DELETE_DUPLICATE | PROJECT及STATUS U-009已拥有 |
| docs/DATA.md | 事实来源分级、不能猜测冲突 | OPERATING_RULE | KEEP_AGENTS | AGENTS来源协议 |
| docs/DATA.md | 分表/总表/投影/默认值/缓存关系 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE数据流；决策理由归D003 |
| docs/DATA.md | 分表编辑、显式同步、计算缓存、重启操作 | OPERATING_RULE | KEEP_HUMAN_DOC | README配置操作；不复制规则数值 |
| docs/DATA.md | 表键→JSON段、name+level/id定位、para类别入口 | STRUCTURAL | KEEP_ARCHITECTURE | 紧凑分表定位表，不保留过时20级/旧行数坐标 |
| docs/DATA.md | source_files、manifest、源/目标hash、无变化不写 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE配置边界 |
| docs/DATA.md | charge/ship可选发现、各入口接受/错误差异 | STRUCTURAL | KEEP_ARCHITECTURE | 指向INPUT_MATRIX与各入口；D006禁止强制统一 |
| docs/DATA.md | 科学家/充能公式、mon数量、离线上限 | STABLE | DELETE_DUPLICATE | PROJECT各领域规则；具体参数归分表 |
| docs/DATA.md | 受限公式工具/只读inspect命令及范围定位 | OPERATING_RULE | KEEP_HUMAN_DOC | README只读核对；旧坐标改按键定位，不默认跑全表审计 |
| docs/DATA.md | 旧七表、旧缓存版本、旧比例、历次同步记录 | HISTORY | DELETE_HISTORY | Git；不能把历史输入范围当现行保证 |
| docs/INVENTORY.md | 目录/入口/状态目录 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE地图 |
| docs/INVENTORY.md | 相对交接布局、引擎/Python、UID/assets、用户目录 | OPERATING_RULE | KEEP_HUMAN_DOC | README迁移/启动 |
| docs/INVENTORY.md | SourceTree/首次推送/旧截图清理/旧无素材表述 | HISTORY | DELETE_HISTORY | Git与现行源码；不保留“舰船仍程序绘制”的过期事实 |
| docs/INVENTORY.md | 保留不同入口和遗留接口的原因 | DECISION | KEEP_DECISIONS | D002；入口用途在ARCHITECTURE，剩余候选U-011 |
| docs/VALIDATION.md | 按影响验证、隔离APPDATA和项目、只改文档不跑游戏 | OPERATING_RULE | KEEP_AGENTS | AGENTS验证协议 |
| docs/VALIDATION.md | runner/UTF8/依赖/图形验证/证据路径/故障局限 | OPERATING_RULE | KEEP_HUMAN_DOC | test/README操作说明 |
| docs/VALIDATION.md | 现行专项定位 | STRUCTURAL | DELETE_DUPLICATE | test/README与TEST_MAP已有专项路由 |
| docs/VALIDATION.md | 所有日期命名的计数、截图、日志、阶段过程 | HISTORY | DELETE_HISTORY | Git；有效未决风险已逐ID迁STATUS，不复制日志 |
| docs/modules/combat.md | 自动战斗、伤害ceil最小1、护盾原始溢出/一级抗性 | STABLE | KEEP_PROJECT | PROJECT战斗；实现补充仍标U-006 |
| docs/modules/combat.md | 受击恢复、死亡回退、残弹、资源保留 | STABLE | KEEP_PROJECT | PROJECT舰船/关卡；不重复武器段 |
| docs/modules/combat.md | delta截断/子步/暂停、函数/测试跳转 | STRUCTURAL | KEEP_ARCHITECTURE | 时间入口及测试路由；具体值留源码/专项 |
| docs/modules/economy.md | 分阶段取整、概率掉落、无额外通关奖、拾取种类 | STABLE | KEEP_PROJECT | PROJECT资源 |
| docs/modules/economy.md | 60秒窗口、离线精度/上限/不重复结算 | STABLE | KEEP_PROJECT | PROJECT资源/存档语义 |
| docs/modules/economy.md | 收入事件与余额、run_resources区别 | DECISION | KEEP_DECISIONS | D005解释独立状态语义；结构字段归ARCHITECTURE |
| docs/modules/economy.md | charge均分扣费与熔炼器特例 | STABLE | DELETE_DUPLICATE | PROJECT充能统一拥有 |
| docs/modules/map.md | 最后一场全灭、size只外观、十槽、插值 | STABLE | KEEP_PROJECT | PROJECT关卡/战斗；旧size决定BOSS和占格归历史 |
| docs/modules/map.md | 跨关回退/起点截断/落点后末敌重放 | STABLE | KEEP_PROJECT | PROJECT关卡 |
| docs/modules/map.md | 驻守间隔/死亡三模式/跃迁 | STABLE | KEEP_PROJECT | PROJECT关卡；速度用当前舰船语义，旧config字段定位归历史 |
| docs/modules/map.md | 运行索引和持久驻守位置、旧loop关闭边界 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE存档边界 |
| docs/modules/progression.md | 升到目标行成本/10连/MAX/保损/解锁弹窗 | STABLE | KEEP_PROJECT | PROJECT装备/关卡；固定旧等级上限删除 |
| docs/modules/progression.md | 科学家逐人round、多资源、分配顺序/衰减/研究点 | STABLE | KEEP_PROJECT | PROJECT科学家；旧计时研发归历史 |
| docs/modules/progression.md | 科技零级/双防御/武器幂次、不补血 | STABLE | KEEP_PROJECT | PROJECT科技 |
| docs/modules/progression.md | 大数研究批准近似及边界 | DECISION | KEEP_DECISIONS | D008保留近似触发/批量/事件/安全边界，不能误改回精确循环 |
| docs/modules/progression.md | 充能round次数/费用/跨级/零费率/短缺顺序/保存 | STABLE | KEEP_PROJECT | PROJECT充能；credit独立语义在D005 |
| docs/modules/progression.md | 炉峰值/排除自身/旧样本/点击与寿命 | STABLE | KEEP_PROJECT | PROJECT炼铁炉；状态理由D005 |
| docs/modules/progression.md | 旧科技版本/charge缺字段/字段和读取边界 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE兼容边界；D004读取纯度 |
| docs/modules/progression.md | 旧“卸下不再有UI入口”、过程日志/旧timeCost | HISTORY | DELETE_HISTORY | 被现行确认卸下/科学家规则替代，不能复制矛盾 |
| docs/modules/ships.md | 多槽/独立等级冷却/数量上限/换舰退款 | STABLE | KEEP_PROJECT | PROJECT舰船装备 |
| docs/modules/ships.md | 等级与冷却唯一来源、旧levels首槽优先 | STRUCTURAL | KEEP_ARCHITECTURE | 所有权/加载保存边界；D004记录理由 |
| docs/modules/ships.md | 源图size映射/缩放/炮口坐标、运行实体字段 | STRUCTURAL | KEEP_ARCHITECTURE | 指向ship_visuals及对应测试，不复制坐标表 |
| docs/modules/ships.md | 艺术规格和素材描述 | STABLE | DELETE_DUPLICATE | ART_GUIDELINES及资产README拥有 |
| docs/modules/weapons.md | 抗性优先排序、导弹数量/分配/失锁/残弹与末敌清弹 | STABLE | KEEP_PROJECT | PROJECT战斗 |
| docs/modules/weapons.md | 初始完整冷却/前进重置不推进/升级保留 | STABLE | KEEP_PROJECT | PROJECT装备 |
| docs/modules/weapons.md | 敌武器数量非等级/逐件冷却/基础行空值回退 | STABLE | KEEP_PROJECT | PROJECT战斗；具体补全字段由database及取整专项定位 |
| docs/modules/weapons.md | 固定偏移/旧BOSS清弹/旧测试导航 | HISTORY | DELETE_HISTORY | 新炮口与末敌专项已有权威；保留U-011敌导弹范围问题 |
| docs/modules/ui.md | 页签显示/重锁/全隐藏，草稿、确认卸下、过期弹窗 | STABLE | KEEP_PROJECT | PROJECT交互边界 |
| docs/modules/ui.md | 拖拽交换/空位/取消/不误点按钮/滚动/延后重建 | STABLE | KEEP_PROJECT | PROJECT交互边界；结构读main/hightech_slot |
| docs/modules/ui.md | 伤害独立文本、BOSS发现与多船卡片、名称/数值显示 | STABLE | KEEP_PROJECT | PROJECT交互；像素常量由代码/专项表达 |
| docs/modules/ui.md | 受限模板表达式、科技截断与充能round差异 | STABLE | KEEP_PROJECT | PROJECT交互；不创造DSL |
| docs/modules/ui.md | QA操作/快捷键/重启/删除存档/失败日志 | OPERATING_RULE | KEEP_HUMAN_DOC | README；AI正式档保护仍归AGENTS |
| docs/modules/ui.md | 同进程Window/直接控制/独立重启宿主 | STRUCTURAL | KEEP_ARCHITECTURE | ARCHITECTURE入口 |
| docs/modules/ui.md | 旧计时条、逐次布局/颜色/像素修改、重复规则 | HISTORY | DELETE_HISTORY | Git及现行源码/专项，不复制逐次UI设计日志 |
| README.md | 启动/引擎/Python/配置操作 | OPERATING_RULE | KEEP_HUMAN_DOC | README保留并接收DATA/INVENTORY/QA操作 |
| README.md | 装备等级规则/旧文档导航 | STABLE | DELETE_DUPLICATE | PROJECT装备与五份入口 |
| docs/LEVEL_EDITOR.md | 编辑/草稿/公式/备份恢复/引用错误操作 | OPERATING_RULE | KEEP_HUMAN_DOC | 原文件保留；来源与故障风险链接新权威 |
| docs/LEVEL_EDITOR.md | 重复最后一场/单格领域规则 | STABLE | DELETE_DUPLICATE | PROJECT关卡；操作文档仅链接 |
| docs/ART_GUIDELINES.md | 风格、画布、槽位、命名、透明度、资产规格表 | OPERATING_RULE | KEEP_HUMAN_DOC | 原文件；明确表为艺术规格，默认编队旧备注不作运行规则 |
| assets/ships/README.md | 素材来源、朝向、使用提示 | OPERATING_RULE | KEEP_HUMAN_DOC | 原文件；缩放改指ARCHITECTURE视觉入口 |
| assets/weapons/README.md | 素材用途、生成提示、消费端 | OPERATING_RULE | KEEP_HUMAN_DOC | 原文件；删除重复常量缩放值，指代码 |
| ../test/README.md | runner、隔离、最小专项路由、性能命令 | OPERATING_RULE | KEEP_HUMAN_DOC | 保留；接收VALIDATION有效操作，删历次阶段流水 |
| ../test/TEST_MAP.md | 逐条规则断言覆盖/迁移记录 | STRUCTURAL | KEEP_HUMAN_DOC | 保留测试检索产物；未决原因链接STATUS而不复制 |
| REFACTOR_PLAN.md | 本次方案/检查点/历史证据 | HISTORY | KEEP_HUMAN_DOC | 按用户要求保留到整个重构完成，不进入默认读取链 |

## 删除门槛与核查

已按映射写入目标并复核后删除12份：DATA、TODO、VALIDATION、INVENTORY、GAME_DESIGN及modules下7份说明。未删除人类说明、测试源码或重构历史。
16个有效未决ID必须全部在STATUS；已解决的5个ID只保留Git历史。过时子句剔除不等于剩余问题解决。
最易丢失的内容需人工复核：分阶段舍入、研究大数近似、首槽旧levels优先、charge.credit、炉峰值/旧样本、入口事务差异、QA重载失败限制、原表来源与后续用户修订。
旧文档中可由函数/测试精确表达的坐标、布局像素、字段枚举、数值行表只保留定位入口；这不是把未知设计默认为已确认。
基线bytes/lines位于 `../test/work/refactor-phase11/before-metrics.json`。本映射完成后才进入目标编写；最终验证与CHECKPOINT 7在REFACTOR_PLAN本轮记录中，不纳入L0。
