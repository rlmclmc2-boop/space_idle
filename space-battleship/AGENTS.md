# AI 入口

Search → Minimum Read → Execute → Verify → Update State。
首次接手读 [PROJECT](docs/PROJECT.md) + [STATUS](docs/STATUS.md)，之后仅按任务加载。

| 任务 | 附加上下文（均在 docs/） |
|---|---|
| 舰船/防御 | modules/ships.md；伤害接口查 modules/combat.md |
| 战斗/武器 | modules/combat.md 或 modules/weapons.md；对应函数及直接依赖 |
| 资源/升级/解锁 | modules/economy.md 或 modules/progression.md |
| 关卡/敌群 | modules/map.md；敌机接口查 modules/ships.md |
| UI/QA | modules/ui.md；scripts/main.gd 或 config_panel.gd 的相关函数 |
| 数值/Excel | DATA.md 中的表范围；tools/inspect_knowledge.py 按范围读取 |
| Bug | 搜索错误/符号 → 命中区域 → 直接依赖 → 对应测试 |
| 规划/架构 | GAME_DESIGN.md 或 ARCHITECTURE.md + DECISIONS.md；路线见 TODO.md |

- 先 `rg` 文件名/符号/引用，再读片段；排除 `.godot/ .runtime/ .userdata/`。禁止默认读取全部模块、源码、Excel 或审计 JSON。
- 来源协议见 [DATA](docs/DATA.md)：CONFIRMED 必带来源，代码事实不等于策划批准；DERIVED 写推导；所有 UNKNOWN/冲突只在 [TODO](docs/TODO.md) 建 ID，其他文档引用 ID。
- One fact → One source：数值归源表，运行投影归 JSON，细则只在所属模块解释；不复制数值表，不静默解决冲突。
- Preserve → Reuse → Modify → Create → Rewrite。先找现有实现；不擅自新增玩法、换栈、重构、移动或删除资料。保持用户正在进行的修改。
- 所有游戏页签未解锁前不展示；新增或修改页签须复用统一解锁显示规则，具体判定与切页行为见 [UI规范](docs/modules/ui.md)。
- 验证命令与隔离要求见 [VALIDATION](docs/VALIDATION.md)。仅运行改动及直接影响范围的必要测试；无关测试默认不跑，只有相关测试失败或存在明确风险时才扩大验证，已通过的检查无新改动不重复跑。纯文档修改仅检查相关内容和链接，不跑游戏测试。Excel 核对用临时目标，不能因整理而覆盖运行 JSON/玩家存档。
- 测试源码统一维护在工作区 `test/`（相对项目 `../test/`）；所有测试副本、截图、日志、测试存档与审计产物只放 `test/work/`，不得再在主目录新建验证文件夹。按 [测试入口](../test/README.md) 运行所需测试。
- 完成任务更新 STATUS 的 Done/In Progress/Blocked/Next/Relevant Files；规则改所属模块，问题改 TODO，长期决策才改 DECISIONS。检查引用及事实来源是否仍有效。
- 交接只留 Goal / Completed / Changed / Issue / Next / Relevant Files，压缩到 STATUS 对应字段；不保存聊天、思考过程或平台私有记忆。
- 默认汇报 Done / Changed / Validation / Next。跨平台先显式读取本文件，适配文件只能链接此入口；交接文件清单见 [INVENTORY](docs/INVENTORY.md)。
