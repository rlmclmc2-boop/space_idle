# 太空战舰

装备等级上限由 Excel 中各装备的等级行自动决定，不再固定为 20。当前表支持五种装备各 100 级；不同装备也可以配置不同上限，等级须从 1 连续递增、无重复。旧存档可继续升级，若后续缩短配置，则读档按对应装备的新上限处理。

Godot 原生 GDScript 横版自动战斗游戏。AI 接手从 [AGENTS.md](AGENTS.md) 开始；当前进度只看 [STATUS](docs/STATUS.md)。

## 启动与配置

Windows 双击 `../启动.cmd`；`打开编辑器.cmd` 打开项目。引擎位于项目 engine/ 目录，名称与启动脚本一致；迁移清单见 [INVENTORY](docs/INVENTORY.md)。游戏运行只需引擎与现有 JSON。

游戏内自动显示附属 QA 窗口，关闭面板仅隐藏，F1 可重显。QA 与游戏共用一个进程；暂停、倍速、读取配置和场景重载说明见 [UI / QA](docs/modules/ui.md)。

QA 新增“拆分／同步 Excel”：将所选总表中总览以外的工作表写入 `config_excel/`，没有则新建，有则更新同名文件。随后“读取配置”只解析有修改的分表，成功后“重启游戏”应用。首次读取会建立缓存；之后无变化不重写 JSON。直接编辑分表后不必再同步，总表同步会覆盖同名分表的差异。详细流程和边界见 [DATA](docs/DATA.md)。

Python/openpyxl/lxml 用于配置工具；可通过 `SPACE_BATTLESHIP_PYTHON` 指定环境。游戏运行不需要 Python。不要直接手改生成 JSON 的策划数值。

## 项目导航

- [项目概览](docs/PROJECT.md) 与 [游戏设计地图](docs/GAME_DESIGN.md)：按系统找规则和实现。
- [当前架构](docs/ARCHITECTURE.md)：数据流、状态、存档、QA关系。
- [TODO / UNKNOWN 与开发路线](docs/TODO.md)：冲突、缺失、决策和优先级。
- [验证方法与最新结果](docs/VALIDATION.md)：测试隔离、证据和覆盖边界。
- [长期决策](docs/DECISIONS.md)：仅保存长期选择及理由。

运行目录 `.userdata` 包含玩家存档；`.runtime` 和 `.godot` 为测试/引擎状态，默认不作为AI上下文。不要用玩家存档目录运行测试。数值与玩法细则只在对应来源维护，本README不复制。
