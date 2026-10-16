# 按任务定位

只读取命中的表行和列出的章节或符号。路径相对 `space-battleship/`。先用 `tools/read_budget.py files` 定位文件，再对列出的文件使用 `grep`、`slice`、`json` 或 `xlsx`。链接只是线索，不自动展开。模块边界的总索引在 `ARCHITECTURE.md`，只在本表无法定位时读相关行。

| 任务种类 | 首读目标 | 必要时的规则或权威表 |
|---|---|---|
| 界面文案 | `docs/UI_TEXT.md`；`data/ui_text.json` 的目标 KEY；`data/ui_text_contract.json` 的同 KEY | `scripts/ui_text.gd: t`；检查命令见 `docs/UI_TEXT.md#CHECK`。若是特殊来源，先看 UI_TEXT 的 Exceptions 行 |
| 装备表字段或导入 | `config_excel/equipment.xlsx` 指定 sheet/行/列；`tools/import_workbook.py` 中目标字段符号 | `docs/DECISIONS.md: D003`；`docs/ARCHITECTURE.md: DATA`；仅在投影问题时查询 `data/game_data.json: equipment` 的目标记录 |
| 局部战斗修复 | `scripts/game.gd` 的目标 `func` 和直接调用者；`docs/BATTLE.md` 相关条目 | `docs/ARCHITECTURE.md: LOCATE`；涉及既有行为时按目标关键词定位 `docs/PROJECT.md` 章节；测试范围按 `docs/TEST.md` |
| 装备槽状态 | `scripts/game.gd: module_entry/equip_slot/unequip_slot/switch_ship/upgrade_slot` | `docs/DECISIONS.md: D004`；直接受影响的 specialty test |
| 保存或玩家档案 | `scripts/game.gd: load_progress/save_progress`；`scripts/progress_writer.gd` | `docs/ARCHITECTURE.md: OWNER`；`docs/STATUS.md: U-008`；`docs/TEST.md` |
| UI 绘制或输入 | 目标 `scripts/main.gd` 函数或具体 page 脚本 | `docs/UI.md` 命中段；文案同时按本表“界面文案”路线 |
| 数值或模拟 | 目标 `config_excel/*.xlsx` 行；`scripts/balance_runner.gd` 或具体模拟器函数 | `docs/BALANCE_LAB.md` 命中段；性能才读 `docs/BALANCE_PERFORMANCE.md` |
| 美术、船员、银河、关卡编辑 | 目标资产或脚本符号 | 对应 `docs/ART_GUIDELINES.md`、`CREW.md`、`GALAXY.md`、`LEVEL_EDITOR.md` 的命中段 |
| 长期决定或开放问题 | `docs/knowledge/INDEX.md` 的目标行 | 指向的 `docs/DECISIONS.md` 或 `STATUS.md` 单条；核对来源提交和适用范围 |
| 测试选择 | `docs/TEST.md` 的相关条目 | `../test/README.md` 中精确命令；不默认读整个测试目录 |
| 协作规范维护 | `docs/READ_PROTOCOL.md` 命中节；现有 `.agents/skills/token-opt/SKILL.md`、`ctx-compress/SKILL.md`、`doc-compact/SKILL.md` 中相关一项 | 做路由、链接、重复及入口字符增长检查；文档改动不跑游戏测试 |

未命中时只查文件名和符号目录。确需扩读，先记下缺少的事实、准确路径及行段；只扩该段。任何 `PROJECT_CONSTRAINTS` 均不在此路由内。
