# Architecture

## CURRENT · 代码确认

`project.godot → main.tscn → main.gd` 创建 `ShipDatabase(RefCounted)`、`BattleGame(RefCounted)`。数据库仅加载一次 res://data/game_data.json；游戏逻辑持有 db、profile 和战斗字典数组，通过 event(kind,payload) 通知 UI。main.gd 负责输入、tick 驱动、按钮构建、绘制/声音和 QA 面板创建，不是完全独立的纯视图。

数据流：`总表 → tools/config_workbooks.py split → config_excel/*.xlsx → incremental import → data/game_data.json → ShipDatabase → BattleGame → main UI`。行转换/校验复用 import_workbook.py，后者保留显式全表 CLI。main.show_qa_tools 创建根级 QATools Window，config_panel 调用配置工具、直接控制 current_scene.game，并在同一进程重载游戏场景后创建新数据库。来源与缓存控制见 [DATA](DATA.md)，接口和字段定位见 [GAME_DESIGN](GAME_DESIGN.md)。

活动状态：TRAVEL → COMBAT → TRAVEL 或 LEVEL_CLEAR → TRAVEL；装甲耗尽 → RETREAT → TRAVEL；paused 与 pending_unlocks 是额外控制门。MAIN_MENU、LEVEL_SELECT、DEFEAT、UPGRADE 枚举仍存在，不表示当前有这些页面；见 U-011。

核心对象：profile（version/highestLevel/cleared/levels/resources/unlocked/loop）、player、enemies、projectiles、drops、cooldowns。对象字段和所有权见各模块；没有 ECS、Autoload 管理器、数据库服务或联网后端。

存档：game.load_progress/save_progress，`user://progress.json`，version=1；先写 .tmp 再 rename。校验部分字段、重建解锁；不保存距离、当前敌群、弹道、冷却，也不结算离线收益。窗口关闭/拾取/升级/通关等会保存。user:// 实际目录由启动脚本的 APPDATA/LOCALAPPDATA 决定，正式玩家目录 `.userdata`，测试必须隔离。QA 偏好同属 user://，控制接口见 [ui](modules/ui.md)。鲁棒性缺口见 U-008。

依赖/构建：GDScript 无第三方游戏包；Python 导入依赖 openpyxl；QA 优先 SPACE_BATTLESHIP_PYTHON，其次本机 bundled Python，再回退 python。Windows 启动脚本依赖父目录固定引擎名。未发现 export_presets.cfg、CI 或依赖锁定清单（U-010）。Godot 配置功能标签 4.3 不等于已验证最低兼容版本。

## PROPOSED · 尚未实施

只提出维护路线，不宣称已实现：先完成 TODO P1 的规则裁决与数据校验，再按实际瓶颈决定是否抽离逻辑。当前任务不引入新框架、新玩法、src/assets 迁移或新的存档结构。
