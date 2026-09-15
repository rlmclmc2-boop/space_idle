# 文件地图与交接包

范围：工作区 `G:/放置`，游戏根 `space-battleship/`。主目录可见文件仅为太空战舰.xlsx与启动.cmd；Git/协作入口文件隐藏，Excel使用中的锁文件保留。2026-09-14 已在工作区根建立 Git 仓库，SourceTree 本地条目为“放置”，origin 为 `https://github.com/rlmclmc2-boop/space_idle.git`；main 已推送并跟踪 origin/main。根 `.gitignore` 纳入入口、原始总表与游戏项目，排除引擎和验证副本；缓存与玩家存档沿用项目忽略规则。路径下文相对游戏根。

| 路径 | 类型/用途 | 默认读取 |
|---|---|---|
| `../太空战舰.xlsx` | 原始策划和数值公式；7 张表，范围见 DATA | 按表/范围 |
| `../~$太空战舰.xlsx` | Excel 锁定临时文件 | 否，保留 |
| `engine/Godot_v4.7.2-stable_win64.exe` | 外置 Windows 引擎 | 不读取二进制 |
| `project.godot`, `main.tscn` | 项目配置、游戏入口 | 架构/启动任务 |
| `scripts/database.gd`, `game.gd` | 数据层、模拟及进度 | 按符号 |
| `scripts/main.gd` | 游戏 UI、程序绘图、声音、QA 创建 | 按符号 |
| `scripts/number_format.gd` | 游戏内数量的 K/M/B/T 公共显示格式化 | UI 数值任务 |
| `scripts/config_panel.gd` | 附属 QA 窗口、导入/场景重载/控制 | 按符号 |
| `scripts/restart_host.gd` | QA大重启辅助进程：等待旧进程退出、资源导入与新进程启动 | 重启任务 |
| `level_editor.tscn`, `scripts/level_editor.gd`, `tools/level_editor_store.py`, `关卡编辑器.cmd` | 独立关卡编辑器及源表保存事务；交接携带 | 关卡编辑器任务 |
| `docs/LEVEL_EDITOR.md`, `../test/test_level_editor.py`, `../test/test_level_editor.gd` | 编辑器说明与隔离验证 | 关卡编辑器任务 |
| `data/game_data.json` | 现有运行数值投影；来源须核对 | 按键 |
| `tools/import_workbook.py` | 导入与校验 | 数据变更 |
| `tools/config_workbooks.py` | 独立 Excel 同步及增量投影；依赖 openpyxl/lxml | 配置流程 |
| `config_excel/*.xlsx`, `.split_manifest.json` | 可编辑分表与对应关系，交接必须携带；`ship.xlsx` 为 5 艘我方舰船配置 | 按对应表 |
| `data/.import_state.json` | 成功导入指纹缓存，可重建 | 导入问题 |
| `../test/test_config_workbooks.py` | 拆分保真、变更检测、失败回滚验证 | 配置流程 |
| `tools/inspect_knowledge.py` | 新增只读审计/按范围查表工具 | 数据核对 |
| `../test/test_import.py`, `test_game.gd`, `test_config_panel.gd` | 导入、模拟/按钮、同进程 QA 集成 | 对应任务 |
| `../启动.cmd`, `打开编辑器.cmd` | 便携启动脚本 | 运行/迁移 |
| `*.gd.uid`, `*.png.import` | Godot 资源标识/导入描述 | 资源任务，保留 |
| `../test/` | 测试源码、运行器；产物统一放 work/ | 对应测试 |
| `assets/weapons/` | 三种透明弹体PNG及生成来源/提示词；main.gd直接引用；`icons/` 为三种槽位武器模块图标 | 武器美术任务 |
| `assets/ships/` | 5 种我方与 6 种敌方透明舰船 PNG；我方舰船已由运行时按 ship 表接入；规范见 `docs/ART_GUIDELINES.md` | 舰船美术任务 |
| `docs/ART_GUIDELINES.md` | 舰船槽位与后续武器图标的统一美术规范 | 美术任务 |
| `.godot/`, `.runtime/` | 引擎缓存、测试/编辑器状态与日志 | 默认排除 |
| `.userdata/` | 玩家进度、QA 偏好、日志/缓存 | 非默认上下文 |
| `docs/`, `AGENTS.md`, `README.md` | 新建知识系统及人类入口 | 按路由 |

资源审计：场景引用脚本；画面由 main.gd 绘制，其中弹体加载 assets/weapons 的三张PNG，舰船/UI及音效仍程序生成。源码未发现 preview 图像的加载引用，旧截图已按用户要求清理；不能据此推断所有缓存均可删除。交接须携带 assets/weapons，不能只复制脚本。

遗留分类：MAIN_MENU/LEVEL_SELECT/UPGRADE/DEFEAT 枚举与 leave() 为遗留接口候选（测试仍引用部分），不是可直接删除的死代码。QA工具.cmd、测试配置.cmd、config_tool.tscn、config_host.gd 在整理期间被外部开发流程移除，当前不再作为入口。问题统一见 TODO U-011。

跨电脑：交接工作区根的启动.cmd、test 测试源码，以及整个游戏根的源文件、data、config_excel（含清单）、docs、tools、assets、场景、Godot UID 和启动说明，连同上一级总表保留相对布局。安装匹配引擎及 Python/openpyxl/lxml，或设置 `SPACE_BATTLESHIP_PYTHON`。不要求携带缓存；需续接玩家进度时另行保留 `.userdata`，它不是共享设计。其他系统手动运行 Godot 并配置隔离用户目录；`.cmd` 不可跨系统执行。平台 AI 不自动发现 AGENTS 时，在任务首句要求显式读取它。
